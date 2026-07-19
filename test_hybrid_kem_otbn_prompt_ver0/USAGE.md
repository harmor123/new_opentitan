# 使用文档

## 一、构建

### OTBN 二进制 (ELF)

```bash
cd ~/pqc/opentitan

bazel build //test_hybrid_kem_otbn_prompt_ver0/otbn/hkdf:sha3_test
bazel build //test_hybrid_kem_otbn_prompt_ver0/otbn/hkdf:kmac_kdf
bazel build //test_hybrid_kem_otbn_prompt_ver0/otbn/p256:p256_ecdh_shared_key
bazel build //test_hybrid_kem_otbn_prompt_ver0/otbn/mlkem768:mlkem768_keypair
bazel build //test_hybrid_kem_otbn_prompt_ver0/otbn/mlkem768:mlkem768_encap
bazel build //test_hybrid_kem_otbn_prompt_ver0/otbn/mlkem768:mlkem768_decap
```

### ISS 测试

```bash
# 全部 6 个测试
bazel test //test_hybrid_kem_otbn_prompt_ver0/otbn/test:all --cache_test_results=no

# 或单独跑
bazel test //test_hybrid_kem_otbn_prompt_ver0/otbn/test:sha3_test
bazel test //test_hybrid_kem_otbn_prompt_ver0/otbn/test:kdf_test
bazel test //test_hybrid_kem_otbn_prompt_ver0/otbn/test:p256_ecdh_test
bazel test //test_hybrid_kem_otbn_prompt_ver0/otbn/test:mlkem768_keypair_test
bazel test //test_hybrid_kem_otbn_prompt_ver0/otbn/test:mlkem768_encap_test
bazel test //test_hybrid_kem_otbn_prompt_ver0/otbn/test:mlkem768_decap_test
```

### OTBN co-sim (RTL vs ISS)

```bash
cd ~/pqc/opentitan
chmod +x test_hybrid_kem_otbn_prompt_ver0/otbn/co_sim/*.sh

# 全部 6 个
bash test_hybrid_kem_otbn_prompt_ver0/otbn/co_sim/run_sha3_co_sim.sh
bash test_hybrid_kem_otbn_prompt_ver0/otbn/co_sim/run_kdf_co_sim.sh
bash test_hybrid_kem_otbn_prompt_ver0/otbn/co_sim/run_p256_co_sim.sh
bash test_hybrid_kem_otbn_prompt_ver0/otbn/co_sim/run_mlkem_keypair_co_sim.sh
bash test_hybrid_kem_otbn_prompt_ver0/otbn/co_sim/run_mlkem_encap_co_sim.sh
bash test_hybrid_kem_otbn_prompt_ver0/otbn/co_sim/run_mlkem_decap_co_sim.sh
```

### Chip Sim

```bash
CHIP="--test_timeout=2000 --cache_test_results=no --sandbox_writable_path=/run/user/1000/ccache-tmp --test_output=streamed"

# 单模块
bazel test //test_hybrid_kem_otbn_prompt_ver0:test_p256_only_sim_verilator $CHIP
bazel test //test_hybrid_kem_otbn_prompt_ver0:test_mlkem_keypair_only_sim_verilator $CHIP
bazel test //test_hybrid_kem_otbn_prompt_ver0:test_mlkem_encap_only_sim_verilator $CHIP
bazel test //test_hybrid_kem_otbn_prompt_ver0:test_mlkem_decap_only_sim_verilator $CHIP
bazel test //test_hybrid_kem_otbn_prompt_ver0:test_kdf_only_sim_verilator $CHIP

# Phase 1: 密钥生成 (P-256 + ML-KEM)
bazel test //test_hybrid_kem_otbn_prompt_ver0:phase1_keygen_test_sim_verilator $CHIP

# Phase 2 Alice: 封装 (ECDH + Encap + KMAC-KDF)
bazel test //test_hybrid_kem_otbn_prompt_ver0:phase2_alice_encap_test_sim_verilator $CHIP

# Phase 2 Bob: 解封装 (Decap + ECDH + KMAC-KDF)
bazel test //test_hybrid_kem_otbn_prompt_ver0:phase2_bob_decap_test_sim_verilator $CHIP
```

过滤关键日志：`2>&1 | grep -E "(I000|CHECK|PASS|FAIL|ERROR)"`

## 二、Chip Sim 测试详解

### Phase 1: 密钥生成

源码: `ibex/phase1_keygen/phase1_keygen_test.c`

```
Step 1: P-256 ECDH
  load p256_ecdh_shared_key
  write d0[64], d1[64], G.x[32], G.y[32]
  execute → read x0[32], x1[32] → ss_e = x0 ^ x1
  CHECK: ss_e == kExpectedSsE

Step 2: ML-KEM KeyGen
  load mlkem768_keypair
  write coins[64]
  execute → read pk_m[1184], sk_m[2400]
  CHECK: pk_m == kExpectedPkM, sk_m == kExpectedSkM
```

### Phase 2 Alice: 封装

源码: `ibex/phase2_encap_decap/phase2_alice_encap.c`

```
Step 1: P-256 ECDH (临时密钥)
  load p256_ecdh_shared_key
  write d_alice[64], Q_bob.x[32], Q_bob.y[32]
  execute → ss_e = x0 ^ x1
  CHECK: ss_e == kExpectedSsE

Step 2: ML-KEM Encap
  load mlkem768_encap
  write coins[32], pk_m[1184]
  execute → ct_m[1088], ss_m[32]
  CHECK: ct_m == kExpectedCtM, ss_m == kExpectedSsM

Step 3: KMAC-KDF
  load kmac_kdf
  write KDK[96] = salt[32] || ss_e[32] || ss_m[32]
  write FixedInfo[53] = Counter(4B) || Label("HybridKEM-v1",12B) || 0x00 || Context[32] || L_bits(4B)
  execute → OKM[32]
  CHECK: OKM == kExpectedOkm
```

### Phase 2 Bob: 解封装

源码: `ibex/phase2_encap_decap/phase2_bob_decap.c`

```
Step 1: ML-KEM Decap
  load mlkem768_decap
  write ct_m[1088], sk_m[2400]
  execute → ss_m[32]
  CHECK: ss_m == kExpectedSsM

Step 2: P-256 ECDH (长期密钥)
  load p256_ecdh_shared_key
  write d_bob[64], Q_alice.x[32], Q_alice.y[32]
  execute → ss_e = x0 ^ x1
  CHECK: ss_e == kExpectedSsE (== Alice ss_e)

Step 3: KMAC-KDF
  同 Alice, OKM 相同
  CHECK: OKM == kExpectedOkm
```

## 三、KAT 生成

```bash
# Phase 1
python3 ref/phase1/p256_kat.py        # P-256: d → Q.x/Q.y + ss_e
python3 ref/phase1/gen_kat.py         # ML-KEM keypair: .dexp → C 数组

# Phase 2
python3 ref/phase2/kmac_kdf_kat_alice.py 32  # Alice KMAC-KDF
python3 ref/phase2/kmac_kdf_kat_bob.py 32    # Bob KMAC-KDF (== Alice)

# 通用工具
python3 ref/kmac_kdf_dexp.py 32        # KMAC-KDF: .dexp + .s 数据段
```

## 四、关键约定

| 规则 | 原因 |
|------|------|
| `LOG_INFO` 不用 "PASS" | chip sim `--exit-success` 正则误杀 |
| KDK = salt || ss_e || ss_m | KMAC-KDF 直接输入，无需 IKM 拼接 |
| FixedInfo 预编码 | Counter + Label + Context + L_bits 由 C 侧构造 |
| KAT 数组 LE 字节序 | 匹配 DMEM 输出, 直接 CHECK_ARRAYS_EQ |
| `.dexp` 用 BE 字节序 | ISS DMEM 比对格式 |

## 五、已知问题

| 问题 | 状态 |
|------|------|
| P-256 示例点 P 触发 RTL `scalar_mult_int` z=0 bug | 已定位, 使用基点 G |
| KDF chip sim Alert 48 (DMEM ECC) | 待修复，ISS 和 co_sim 均通过 |
| SHA3 co_sim RTL/ISS mismatch | sha3_final jal 覆盖 ra 导致死循环，ISS 容错但锁步对比发散 |
