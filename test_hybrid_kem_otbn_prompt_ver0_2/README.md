# Hybrid KEM — ver0_2（官方资源基线）

RFC 10024 SecP256r1MLKEM768 混合 KEX 的**官方资源基线**：ML-KEM 数学沿用 ver1 的
Plantard 实现（NTT/INTT/BaseMul/CBD/pack/unpack 未改），**全部哈希走官方 OTBN KMAC
驱动**（`sw/otbn/crypto/xof.s` 逐字版，见 `otbn/kmac_official/`），不新增任何 RTL。

与 ver1 的区别：ver1 的 `kmac_sha3_template.s` 是自写驱动（裸 CSR 地址、自家编码）；
ver0_2 换成官方 xof.s 的调用形式（`xof_shake128_init / xof_absorb / xof_process /
xof_squeeze32 / xof_finish`，符号 CSR、超时保护、rate 跟踪），论证"基线全部由
OpenTitan 官方已有资源构成"。

## 目录

```
├── q.md                 # 需求（注意：其中"不增加KMAC→OTBN直连"已过时——
│                        #   直连是官方上游功能 hw/ip/otbn/rtl/otbn_kmac_if.sv）
├── otbn/
│   ├── kmac_official/   # 官方 xof.s + 官方 ISS 测试（逐字取自 master）
│   ├── mlkem768/        # Plantard 数学 + 官方 xof.s 调用
│   └── test/            # ISS 测试（keypair 已就绪；encap/decap 待移植）
└── （待建）ibex/        # 官方 P-256 cryptolib API + 官方 HKDF
```

## 移植状态

| 模块 | 哈希调用点 | 状态 |
|---|---|---|
| keypair | G(SHA3-512) + 3×PRF-η1(SHAKE256) + 9×矩阵(SHAKE128) + H(SHA3-256) | ✅ 已换官方 xof.s，KAT 通过 |
| encap | H(pk) + G(m‖H) + 6×PRF + 9×矩阵 | ✅ 已换官方 xof.s |
| decap | G + SHAKE256(z‖c) + 3×PRF + 9×矩阵 | ✅ 已换官方 xof.s |
| P-256 | 待从 ver0_1 搬官方 cryptolib API 版本 | ⏳ |
| HKDF | 待换官方 otcrypto_hkdf | ⏳ |

## Linux 上运行

```bash
cd ~/new_pqc/opentitan

# 1. 官方 xof.s 驱动自检（ISS）
bazel test //test_hybrid_kem_otbn_prompt_ver0_2/otbn/kmac_official:all --cache_test_results=no

# 2. ML-KEM-768 三个 KAT（官方 xof.s 版）
bazel test //test_hybrid_kem_otbn_prompt_ver0_2/otbn/test:all --cache_test_results=no
```

## 移植时采用的技术决策

- **官方 xof.s 逐字不动**（保留 x28-x30 保留寄存器约定）。
- **关键教训（已修复的 bug）**：xof 会话会改写 x28-x30（rate 跟踪/超时），
  其中 `xof_shake128_init` 把 x29 设为 rate 大小（21）。keypair 矩阵循环把
  x29（下一个 sk 多项式指针）跨 `poly_gen_matrix` 调用保持存活——ver1 的自写
  模板不碰 x29 所以没暴露；换官方驱动后 basemul_acc 读到 x29=21 → BAD_DATA_ADDR。
  修复：`poly_gen_matrix` 在 XOF 会话前后保存/恢复 x28-x30（帧槽 -48/-52/-56）。
  **encap/decap 移植时必须在每个哈希调用点检查 x28-x30（及 x20-x25/x27/w26-w31）
  的跨会话存活值。**
- 官方 `xof_absorb` 入参 x20=长度、x21=消息地址、x22=第二 share 地址（0=非掩码），
  调用后指针前移——多次 absorb 需重新赋值。
- `xof_squeeze32` 输出到 w29/w30（双 share），非掩码会话 w30=0，调用方做
  `bn.xor wX, w29, w30` 合并。
- w31 保持全零（xof_absorb 的非掩码路径以 w31 写 KMAC_DATA_S1），每个哈希会话
  前防御性 `bn.xor w31, w31, w31`。
- 矩阵采样沿用 ver1 的"边 squeeze 边拒绝"结构（12-bit 候选与 FIPS 203 Alg 7 的
  3 字节解析等价），仅把 squeeze 换成 xof_squeeze32；官方 expand_a 的
  "672B 整块缓冲"结构留作备选。
- 官方 `xof_squeeze24` 在 master 上无调用者，未采用。
