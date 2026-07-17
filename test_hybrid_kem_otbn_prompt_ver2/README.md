# Hybrid KEM Test

ML-KEM-768 + P-256 ECDH + KMAC-KDF (SHAKE256) 混合密钥协商系统。
全部密码运算在 OTBN 内部完成，Ibex 负责调度和数据搬移。

## 快速链接

| 文档 | 内容 |
|------|------|
| [IMPLEMENTATION.md](IMPLEMENTATION.md) | 架构设计、API 接口、KAT 表 |
| [USAGE.md](USAGE.md) | 构建命令、测试步骤、Phase 1/2 详解 |
| [REVISION.md](REVISION.md) | 版本历史 |

## 目录

```
test_hybrid_kem_otbn_prompt_ver2/
├── README.md / IMPLEMENTATION.md / USAGE.md / REVISION.md
├── BUILD                              # Bazel 测试目标
├── ibex/
│   ├── test_p256_only.c / test_p256_official.c
│   ├── test_mlkem_{keypair,encap,decap}_only.c
│   ├── test_kmac_kdf_only.c
│   ├── phase1_keygen/phase1_keygen_test.c
│   └── phase2_encap_decap/
│       ├── phase2_alice_encap.c
│       └── phase2_bob_decap.c
├── otbn/
│   ├── p256/      # P-256 ECDH 汇编
│   ├── mlkem768/  # ML-KEM-768 汇编
│   ├── kmac_kdf/      # KMAC-KDF (SHAKE256) 汇编 + KMAC 驱动
│   ├── test/      # ISS 测试 wrapper + .dexp
│   └── co_sim/    # OTBN RTL+ISS co-sim 脚本 (7 个)
└── ref/           # Python KAT 生成器
    ├── hybrid_kem_ref.c / .h
    ├── kmac_kdf_kat.py / kmac_kdf_dexp.py
    ├── phase1/    # p256_kat.py, gen_kat.py
    └── phase2/    # kmac_kdf_kat_alice.py, kmac_kdf_kat_bob.py
```

## 三版本对比

| | ver0 (纯软件) | ver1 (KMAC混合) | ver2 (硬件加速) |
|------|------|------|------|
| ML-KEM 指令集 | 基线 | 基线 | BNMULV_VER2 |
| ML-KEM 哈希 | 软件 Keccak-f | KMAC 硬件 | KMAC 硬件 |
| SHA3/KMAC | 软件 Keccak-f | KMAC 硬件 | KMAC 硬件 |
| KMAC-KDF | 软件 KMAC | KMAC 硬件 | KMAC 硬件 |
| P-256 | 软件 | 软件 | 软件 |

## 测试状态 (2026-06-05)

| Component | ISS | Chip Sim | Verify |
|------|------|------|------|
| P-256 ECDH | ✅ | ✅ | x0 ^ x1 == ss_e |
| P-256 KeyGen (official) | ✅ | ✅ | pk_x, pk_y |
| ML-KEM keypair | ✅ | ✅ | pk_m[1184], sk_m[2400] |
| ML-KEM encap | ✅ | ✅ | ct_m[1088], ss_m[32] |
| ML-KEM decap | ✅ | ✅ | ss_m[32] |
| KMAC-KDF (standalone) | ✅ | ✅ | OKM[32] |
| Phase 1 KeyGen | — | ✅ | P-256 + ML-KEM |
| Phase 2 Alice | — | ✅ | ECDH + Encap + KMAC-KDF |
| Phase 2 Bob | — | ✅ | Decap + ECDH + KMAC-KDF |

## 快速命令

```bash
# Chip Sim (完整参数)
CHIP="--test_timeout=2000 --cache_test_results=no --sandbox_writable_path=/run/user/1000/ccache-tmp --test_output=streamed"

# 单模块
bazel test //test_hybrid_kem_otbn_prompt_ver2:test_kmac_kdf_only_sim_verilator $CHIP
bazel test //test_hybrid_kem_otbn_prompt_ver2:test_p256_only_sim_verilator $CHIP

# Phase 1 + 2
bazel test //test_hybrid_kem_otbn_prompt_ver2:phase1_keygen_test_sim_verilator $CHIP
bazel test //test_hybrid_kem_otbn_prompt_ver2:phase2_alice_encap_test_sim_verilator $CHIP
bazel test //test_hybrid_kem_otbn_prompt_ver2:phase2_bob_decap_test_sim_verilator $CHIP

# ISS
bazel test //test_hybrid_kem_otbn_prompt_ver2/otbn/test:kmac_kdf_test --test_output=errors
bazel test //test_hybrid_kem_otbn_prompt_ver2/otbn/test:p256_ecdh_test --test_output=errors

# KAT 生成
python3 ref/phase2/kmac_kdf_kat_alice.py 32
python3 ref/phase1/p256_kat.py
```
