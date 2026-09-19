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
| encap | H(pk) + G(m‖H) + 6×PRF + 9×矩阵 | ✅ 已换官方 xof.s，KAT 通过 |
| decap | G + SHAKE256(z‖c) + 3×PRF + 9×矩阵 | ✅ 已换官方 xof.s，KAT 通过 |
| P-256 | 官方 cryptolib API（固定标量 + 公开 checksum 函数构造 keyblob） | ✅ phase2 Alice/Bob 已重写 |
| HKDF | ver1 hkdf 结构移植为**官方 xof.s 接口**（OTBN 直连 KMAC），KAT 经 Python hashlib 独立按 RFC 2104/5869 验证 | ✅ otbn/hkdf/（hkdf_sha3_256.s + hmac_sha3.s） |

注：`ibex/hkdf_sha3_256.{c,h}`（Ibex C 版 HKDF）保留在树中作为交叉参考实现，
不参与 ver0_2 基线路径（基线全部哈希统一走 OTBN↔KMAC 直连 + 官方 xof.s）。

## Linux 上运行

```bash
cd ~/new_pqc/opentitan

# 1. 官方 xof.s 驱动自检（ISS）
bazel test //test_hybrid_kem_otbn_prompt_ver0_2/otbn/kmac_official:all --cache_test_results=no

# 2. ML-KEM-768 三个 KAT + hkdf KAT（官方 xof.s 版）
bazel test //test_hybrid_kem_otbn_prompt_ver0_2/otbn/test:all --cache_test_results=no

# 3.0 测试（内存扩展是否没问题）
mkdir -p /tmp/ccache-tmp
export CCACHE_TEMPDIR=/tmp/ccache-tmp

bazel build //hw:verilator_real \
      --spawn_strategy=local \
      --action_env=CCACHE_TEMPDIR

# 3. chip sim（verilator）：单模块 + phase1/phase2 端到端
# 重启后需要
# mkdir -p /run/user/1000/ccache-tmp

# mkdir -p /tmp/ccache-tmp
# export CCACHE_TEMPDIR=/tmp/ccache-tmp

# bazel test //test_hybrid_kem_otbn_prompt_ver0_2:test_mlkem_keypair_only_sim_verilator \
#       --cache_test_results=no \
#       --spawn_strategy=local \
#       --action_env=CCACHE_TEMPDIR

CHIP="--test_timeout=2000 --cache_test_results=no --sandbox_writable_path=/run/user/1000/ccache-tmp"
bazel test //test_hybrid_kem_otbn_prompt_ver0_2:test_mlkem_keypair_only_sim_verilator $CHIP
bazel test //test_hybrid_kem_otbn_prompt_ver0_2:test_mlkem_encap_only_sim_verilator $CHIP
bazel test //test_hybrid_kem_otbn_prompt_ver0_2:test_mlkem_decap_only_sim_verilator $CHIP
bazel test //test_hybrid_kem_otbn_prompt_ver0_2:test_p256_only_sim_verilator $CHIP
bazel test //test_hybrid_kem_otbn_prompt_ver0_2:test_hkdf_only_sim_verilator $CHIP
bazel test //test_hybrid_kem_otbn_prompt_ver0_2:phase1_keygen_test_sim_verilator $CHIP
bazel test //test_hybrid_kem_otbn_prompt_ver0_2:phase2_alice_encap_test_sim_verilator $CHIP
bazel test //test_hybrid_kem_otbn_prompt_ver0_2:phase2_bob_decap_test_sim_verilator $CHIP
```

## KMAC RTL-ISS co-sim 的取舍（为何没有 co-sim）

曾尝试做 OTBN↔KMAC 的 RTL-ISS co-sim（`otbn/co_sim/` 脚本 + fork 自建
`otbn_mock_kmac_app.sv` + 模型 C++/SV 加 KMAC 端口），**已放弃并全部恢复官方原样**
（提交 `cfa2368a26`），原因：

1. **官方未实现**：上游对 OTBN↔KMAC 的 RTL co-sim 只有计划（lowRISC issue
   #30730），verilator tb 中 `kmac_app_req` 悬空、`kmac_app_rsp` 接 0，ISS 模型
   （C++/SV）无 KMAC 端口。官方已实现的只是 **ISS 侧（otbnsim）KMAC 模拟**
   （上游提交 c469fe6369 / 16e4d28422，`hw/ip/otbn/dv/otbnsim/sim/kmac.py`）。
2. **fork 自建 mock 是"假数据"**：mock 不计算真实 SHA3/KMAC，只回放固定 beat，
   co-sim 至多验证 OTBN↔KMAC 握手/背压时序，不验证密码学正确性。
3. **根基不稳**：上游每次合并都会动 dv/ 模型文件，一次合并即把模型侧 KMAC
   端口冲掉，co-sim 构建失效——维护成本高于收益。

**KMAC 正确性的证据链（替代 co-sim）**：
- 官方 xof.s 驱动 ISS 自检（`otbn/kmac_official/` 四个测试，跑在官方 kmac.py
  模拟上，ISS 全部通过）；
- ML-KEM-768 keypair/encap/decap 与 HKDF 的 KAT：chip sim（真 RTL KMAC 硬件）
  通过，且期望向量经 Python hashlib 按 FIPS 202 / RFC 2104 / RFC 5869 独立复算；
- chip sim 8/8（单模块 ×5 + phase1 + phase2 ×2）。

**保留的 fork 侧 RTL 差异**（论文"与官方 RTL 差异"口径中需说明）：
`hw/ip/otbn/rtl/otbn_kmac_if.sv` 一处修复——digest 响应时 WSR 高字清零为
SECDED 编码零值（避免 SW 读 256 位 WSR 时 X 值触发完整性错误），非 co-sim
内容，保留。

## 测量口径

- **周期数**：Ibex mcycle（profile.h 的 profile_start/end），单模块测试与
  phase1/phase2 的 HKEM_PROF_* 日志分步输出
- **OTBN 指令数**：dif_otbn_get_insn_cnt（ML-KEM 各 app）与
  otbn_instruction_count_get()（官方 cryptolib P-256 路径）
- 注：本配置 Ibex 无 minstret CSR，Ibex 侧指令数不可直接测量（论文口径：
  "周期数 + OTBN 指令数"）

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
