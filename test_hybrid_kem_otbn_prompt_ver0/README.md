# Hybrid KEM — 纯软件实现 (ver0 Base)

ML-KEM-768 + P-256 ECDH + KMAC-KDF (SHAKE256)。全部使用纯 OTBN 汇编，无 KMAC 硬件加速，无 BNMULV_VER2。

SHA3/SHAKE/KDF 均基于软件 Keccak-f 置换 (`sha3_shake.s`) 实现。P-256 与 HW 版相同。

## 快速命令

```bash
cd ~/pqc/opentitan

# ISS (软件模拟) — 全部 7 个测试
bazel test //test_hybrid_kem_otbn_prompt_ver0/otbn/test:all

# 或单独跑
bazel test //test_hybrid_kem_otbn_prompt_ver0/otbn/test:sha3_shake_test
bazel test //test_hybrid_kem_otbn_prompt_ver0/otbn/test:hmac_test
bazel test //test_hybrid_kem_otbn_prompt_ver0/otbn/test:hkdf_test
bazel test //test_hybrid_kem_otbn_prompt_ver0/otbn/test:mlkem768_keypair_test
bazel test //test_hybrid_kem_otbn_prompt_ver0/otbn/test:mlkem768_encap_test
bazel test //test_hybrid_kem_otbn_prompt_ver0/otbn/test:mlkem768_decap_test
bazel test //test_hybrid_kem_otbn_prompt_ver0/otbn/test:p256_ecdh_test

# Chip Sim (Verilator 硬件仿真)
CHIP="--test_timeout=2000 --cache_test_results=no --sandbox_writable_path=/run/user/1000/ccache-tmp"

bazel test //test_hybrid_kem_otbn_prompt_ver0:test_p256_only_sim_verilator $CHIP
bazel test //test_hybrid_kem_otbn_prompt_ver0:test_mlkem_keypair_only_sim_verilator $CHIP
bazel test //test_hybrid_kem_otbn_prompt_ver0:test_mlkem_encap_only_sim_verilator $CHIP
bazel test //test_hybrid_kem_otbn_prompt_ver0:test_mlkem_decap_only_sim_verilator $CHIP
bazel test //test_hybrid_kem_otbn_prompt_ver0:test_hkdf_only_sim_verilator $CHIP

# Phase 1 + 2
bazel test //test_hybrid_kem_otbn_prompt_ver0:phase1_keygen_test_sim_verilator $CHIP
bazel test //test_hybrid_kem_otbn_prompt_ver0:phase2_alice_encap_test_sim_verilator $CHIP
bazel test //test_hybrid_kem_otbn_prompt_ver0:phase2_bob_decap_test_sim_verilator $CHIP

# 过滤关键日志: 2>&1 | grep -E "(I000|CHECK|PASS|FAIL|ERROR)"
```

## 与 HW 版 (test_hybrid_kem_otbn_prompt_ver2) 的区别

| | HW (prompt) | SW (prompt_base) |
|------|------|------|
## 三版本对比

| | ver0 (纯软件) | ver1 (KMAC混合) | ver2 (硬件加速) |
|------|------|------|------|
| ML-KEM 指令集 | 基线 | 基线 | BNMULV_VER2 |
| ML-KEM 哈希 | 软件 Keccak-f | KMAC 硬件 | KMAC 硬件 |
| SHA3/HMAC | 软件 Keccak-f | KMAC 硬件 | KMAC 硬件 |
| KDF  | 软件 SHAKE | KMAC 硬件 | KMAC 硬件 |
| P-256 | 软件 | 软件 | 软件 |

## 目录

```
├── BUILD               # Bazel chip sim 测试目标 (8 个 opentitan_test)
├── README.md
├── IMPLEMENTATION.md
├── DETAIL.md
├── USAGE.md
├── REVISION.md
├── ibex/               # Ibex C 测试代码
│   ├── test_*.c
│   ├── phase1_keygen/
│   └── phase2_encap_decap/
├── otbn/
│   ├── p256/           # P-256 (同 HW)
│   ├── mlkem768/       # ML-KEM ver0 纯软件 (来自 test/kyber_ver0_base)
│   ├── hkdf/           # HKDF 纯软件 (sha3_shake.s + hmac.s + kmac_kdf.s)
│   └── test/           # ISS 测试 wrapper + .dexp
└── ref/                # Python KAT 生成器
```
