# Hybrid KEM — ver1_1（官方向量指令实现的 ML-KEM-768）

**定位**：把官方上游的 `sw/otbn/crypto/mlkem1024`（lowRISC/Google 实现，使用官方 OTBN
向量指令 + MOD WSR 硬件 Montgomery + 官方 xof.s KMAC 驱动 + 种子双 share 掩码）
**逐字移植到 ML-KEM-768**，但**文件与函数布局沿用 ver0_2**（`otbn/mlkem768/` 的
11 个文件名，不用官方的 `keygen/encaps/decaps` 子目录结构）。

## 与三代实现的关系

| | 数学/约简 | lane 宽度 | 哈希驱动 | 掩码 | 文件布局 |
|---|---|---|---|---|---|
| ver0_1（纯软） | Plantard | 无向量 | 软件 | 无 | 同 ver0_2 |
| ver0_2（官方资源基线） | Plantard（`bn.mulqacc` 标量） | 16-bit 打包 | 官方 xof.s | 无 | — |
| **ver1_1（本版）** | **Montgomery（`bn.mulvml.8s` + MOD WSR）** | **32-bit** | **官方 xof.s** | **有（种子双 share）** | **同 ver0_2** |
| 论文 N/P 工作（仅参考） | 16-bit 自研指令 `.16H` | 16-bit | 自写 `keccak_send_message` | 无 | poly.c 风格 |

注：论文（Niederhagen/Pham，ePrint 2025/2028）用的 16-bit lane 指令（`.16H`）
**官方未合入**——官方最终采用 32-bit 的 `.8s` 路线。因此"用官方现有资源实现"的
向量版本就是本版（32-bit），这也正是它作为基线的意义。

## 目录

```
otbn/mlkem768/          # 库（函数布局同 ver0_2）
├── ntt.s / intt.s      # 官方 ntt/intt 逐字 + twiddle 表（q 相同，768/1024 通用）
├── basemul.s           # 官方 poly_mul / poly_mul_add -> basemul / basemul_acc
├── cbd.s               # 官方 sample_cbd_poly -> cbd2（eta = 2）
├── poly_gen_matrix.s   # 官方 expand_a + sample_ntt_poly
├── poly.s              # poly_add/sub/frommsg/tomsg/getnoise_eta_1/2（+ compress_1/encode_1）
├── pack_keys.s         # 官方 encode_12/decode_12 -> poly_tobytes/frombytes + pack/unpack 包装
├── pack_ciphertext.s   # du=10/dv=4 压缩（新写）+ pack/unpack 包装
├── mlkem_keypair.s     # crypto_kem_keypair / indcpa_keypair
├── mlkem_encap.s       # crypto_kem_enc / indcpa_enc / _encrypt_core
└── mlkem_decap.s       # crypto_kem_dec / indcpa_dec / _decrypt_core

otbn/test/              # 测试/芯片仿真入口 + 内存布局（惯例同 ver0_2）
├── mlkem_base_{keypair,encap,decap}_test.s
└── kp.dexp / enc.dexp / dec.dexp   # 期望向量，直接复用 ver0_2（按符号比对）
```

## 移植时改了什么（k = 4 -> 3）

- 维度：矩阵 3×3；噪声 nonce：y[j] 用 0..2，e1[i] 用 3..5，e2 用 6
- 尺寸：pk 1568→1184 B，sk 3168→2400 B，ct 1568→1088 B（ct_u 1408→960，ct_v 160→128）
- **G 的域分隔字节：4 → 3**（FIPS 203 Alg. 16：`(rho, sigma) = G(d || k)`；
  与 ver0_2 的 `0x03` 一致，官方 1024 用的是 `0x04`）
- **新写的压缩函数**：官方只有 du=11/dv=5；768 需要 du=10/dv=4，故新写
  `encode_10/compress_10/decode_10/decompress_10` 与 `encode_4/compress_4/decode_4/decompress_4`
  （循环结构、MOD WSR 定点除法（M=1290168, mu=0）、取值范围与官方 11/5 版完全同构，
  仅改位移量与掩码位宽）

## 移植时的技术决策（与 ver0_2 的差异，论文口径需说明）

1. **栈指针 = x31**（向上增长）。ver0_2 用 x2（向下增长）。
   - OTBN **没有 ABI**：官方风格指南明确写 "There's no ABI, so OTBN registers
     cannot be referred to by ABI names"，文档中出现的 "stack" 均指硬件调用栈/循环栈
     （`otbn_stack.sv`，由 `jal`/`loop` 隐式使用），**官方从未规定数据栈指针寄存器**。
   - 官方新一批 ML-KEM/ML-DSA 代码（`mlkem1024/`、`mldsa87/`、`mai_gadgets.s`）
     统一用 **x31** 作数据栈指针，其注释称其为 "stack pointer"
     （见 `mldsa87/tests/mldsa87_intt_test.s:10`：`/* Setup stack pointer ... */ la x31, _stack`）；
     官方更早的代码则用 x2（见 `tests/sha3_shake_test.s:11`：`/* Load stack pointer */ la x2, stack_end`）。
   - 技术上：官方把 x28–x30 保留给 KMAC/xof 驱动，x2–x27 全留给参数/指针/计算，
     栈指针因此落在唯一剩余的 x31。
   - 本版内核逐字取自官方 mlkem1024，其中 x2 是活跃的通用寄存器，改回 x2 须重排内核
     寄存器分配（等于修改官方代码），故沿用 x31。**两套约定在官方代码中均有先例**，
     此为上游代码血统差异，非实现差异，不影响协议输出与测量口径。
2. **数据布局 = 32-bit 系数**（1024 B/多项式，8 个/WDR），寄存器约定内核层沿用官方；
   ver0_2 的 16-bit 打包约定（512 B/多项式）因布局变化不再适用。
3. **掩码保留**：`seed_d/z` 双 share 存储 + `xof_absorb` 传 `x22 = share1` 走 KMAC
   掩码吸收通路；`crypto_kem_keypair` 保持 ver0_2 的 `coins(64B)` 接口，内部拆成
   `share0 = coins / share1 = 0`——**掩码代码路径被完整执行，同时测试向量与 ver0_2 一致**。
4. **新写的包装函数**：`pack_pk`/`pack_sk`/`unpack_pk`/`unpack_sk`/`pack_ciphertext`/
   `unpack_ciphertext`/`polyvec_compress`/`polyvec_decompress`——官方把这些打包步骤
   内联在各 app 里，本版按 ver0_2 的接口抽成了函数。
5. **未移植**：`poly_reduce`（官方每步 `addvm` 已约简，无对应）、`cbd3`（768 的
   eta1 = eta2 = 2，用不到）。
6. 标准 `dk` 输出为 (s || pk_t || rho || H(pk) || z)，其中 z = z0 ^ z1 由 `pack_sk`
   合并（官方 cryptolib 则把 sk 保持为 blinded key 形式，不在 OTBN 内解掩码）。

## Linux 上运行

```bash
cd ~/new_pqc/opentitan

# ISS KAT（期望向量与 ver0_2 相同，可直接对比两版输出是否逐字节一致）
bazel test //test_hybrid_kem_otbn_prompt_ver1_1/otbn/test:all --cache_test_results=no
```

若出现 scratchpad 相关的 DMEM 完整性报错，说明测试文件的 main 里那段
scratchpad 清零循环没生效（`.scratchpad` 是 NOLOAD，ISS 上需先写后读）。
