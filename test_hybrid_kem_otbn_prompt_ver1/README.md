# Hybrid KEM — ver1 (KMAC Hash + KMAC-KDF + 基线 ML-KEM)

ML-KEM-768 (基线指令) + P-256 ECDH — 全部哈希 (SHA3/SHAKE) 和密钥派生 (KMAC-KDF) 使用 KMAC 硬件加速。

与 ver0 的区别：所有 SHA3/SHAKE 调用走 KMAC 硬件；KDF 从 HKDF-SHA3-256 升级为 KMAC-KDF (NIST SP 800-108r1)。

## 快速命令

```bash
cd ~/pqc/opentitan

# === ISS (软件模拟) ===
bazel test //test_hybrid_kem_otbn_prompt_ver1/otbn/test:all --cache_test_results=no

# 单独跑
bazel test //test_hybrid_kem_otbn_prompt_ver1/otbn/test:sha3_test
bazel test //test_hybrid_kem_otbn_prompt_ver1/otbn/test:kdf_test
bazel test //test_hybrid_kem_otbn_prompt_ver1/otbn/test:mlkem768_keypair_test
bazel test //test_hybrid_kem_otbn_prompt_ver1/otbn/test:mlkem768_encap_test
bazel test //test_hybrid_kem_otbn_prompt_ver1/otbn/test:mlkem768_decap_test
bazel test //test_hybrid_kem_otbn_prompt_ver1/otbn/test:p256_ecdh_test

# === OTBN 二进制 ===
bazel build //test_hybrid_kem_otbn_prompt_ver1/otbn/kmac:sha3_test_bin
bazel build //test_hybrid_kem_otbn_prompt_ver1/otbn/kmac:kmac_kdf
bazel build //test_hybrid_kem_otbn_prompt_ver1/otbn/p256:p256_ecdh_shared_key
bazel build //test_hybrid_kem_otbn_prompt_ver1/otbn/mlkem768:mlkem768_keypair
bazel build //test_hybrid_kem_otbn_prompt_ver1/otbn/mlkem768:mlkem768_encap
bazel build //test_hybrid_kem_otbn_prompt_ver1/otbn/mlkem768:mlkem768_decap

# === OTBN co-sim (RTL vs ISS) ===
chmod +x test_hybrid_kem_otbn_prompt_ver1/otbn/co_sim/*.sh
bash test_hybrid_kem_otbn_prompt_ver1/otbn/co_sim/run_sha3_co_sim.sh
bash test_hybrid_kem_otbn_prompt_ver1/otbn/co_sim/run_kdf_co_sim.sh
bash test_hybrid_kem_otbn_prompt_ver1/otbn/co_sim/run_p256_co_sim.sh
bash test_hybrid_kem_otbn_prompt_ver1/otbn/co_sim/run_mlkem_keypair_co_sim.sh
bash test_hybrid_kem_otbn_prompt_ver1/otbn/co_sim/run_mlkem_encap_co_sim.sh
bash test_hybrid_kem_otbn_prompt_ver1/otbn/co_sim/run_mlkem_decap_co_sim.sh

# === Chip Sim ===
CHIP="--test_timeout=2000 --cache_test_results=no --sandbox_writable_path=/run/user/1000/ccache-tmp"

bazel test //test_hybrid_kem_otbn_prompt_ver1:test_p256_only_sim_verilator $CHIP
bazel test //test_hybrid_kem_otbn_prompt_ver1:test_mlkem_keypair_only_sim_verilator $CHIP
bazel test //test_hybrid_kem_otbn_prompt_ver1:test_mlkem_encap_only_sim_verilator $CHIP
bazel test //test_hybrid_kem_otbn_prompt_ver1:test_mlkem_decap_only_sim_verilator $CHIP
bazel test //test_hybrid_kem_otbn_prompt_ver1:phase1_keygen_test_sim_verilator $CHIP
bazel test //test_hybrid_kem_otbn_prompt_ver1:phase2_alice_encap_test_sim_verilator $CHIP
bazel test //test_hybrid_kem_otbn_prompt_ver1:phase2_bob_decap_test_sim_verilator $CHIP
```

## KDF 方案对比

| | ver0 (旧) | ver1 (新) |
|------|------|------|
| KDF 标准 | HKDF (RFC 5869) | **KMAC-KDF (NIST SP 800-108r1)** |
| 底层构造 | HMAC-SHA3-256 (双层嵌套) | SHAKE128 (单层海绵) |
| Extract | PRK = HMAC(salt, IKM) | 不需要 (KDK 直接吸收) |
| Expand | T(i) = HMAC(PRK, T(i-1)\|\|info\|\|i) | 不需要 (SHAKE XOF 直接挤压) |
| 调用次数 | 1 + N 次 HMAC (N = ceil(L/32)) | **1 次 SHAKE128 调用** |
| 硬件利用率 | 每次 HMAC = 2×SHA3 | 1×KMAC init + absorb×2 + process + squeeze |

## 三版本对比

| | ver0 (纯软件) | ver1 (KMAC+KDF) | ver2 (硬件加速) |
|------|------|------|------|
| ML-KEM 指令集 | 基线 | 基线 | BNMULV_VER2 |
| ML-KEM 哈希 | 软件 Keccak-f | **KMAC 硬件** | KMAC 硬件 |
| SHA3/SHAKE | 软件 Keccak-f | KMAC 硬件 | KMAC 硬件 |
| 密钥派生 (KDF) | HKDF-SHA3-256 (软件) | **KMAC-KDF (硬件)** | KMAC 硬件 |
| P-256 | 软件 | 软件 | 软件 |

## 目录

```
├── BUILD               # chip sim 测试目标
├── README.md
├── ibex/               # Ibex C 测试代码
├── otbn/
│   ├── p256/           # P-256 ECDH
│   ├── mlkem768/       # ML-KEM 基线 + KMAC SHA3
│   ├── hkdf/           # KMAC 驱动 (kmac_xof.s) + KMAC-KDF (kmac_kdf.s)
│   ├── test/           # ISS 测试 + dexp
│   └── co_sim/         # RTL+ISS co-sim 脚本
└── ref/                # Python KAT 生成器
```
