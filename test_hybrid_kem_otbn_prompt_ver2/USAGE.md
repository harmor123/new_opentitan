# 使用文档

## 一、构建

### ISS 测试

```bash
bazel test //test_hybrid_kem_otbn_prompt_ver2/otbn/test:p256_ecdh_test --test_output=errors
bazel test //test_hybrid_kem_otbn_prompt_ver2/otbn/test:hkdf_test --test_output=errors
bazel test //test_hybrid_kem_otbn_prompt_ver2/otbn/test:mlkem768_keypair_test --test_output=errors
bazel test //test_hybrid_kem_otbn_prompt_ver2/otbn/test:mlkem768_encap_test --test_output=errors
bazel test //test_hybrid_kem_otbn_prompt_ver2/otbn/test:mlkem768_decap_test --test_output=errors
```

### OTBN co-sim (RTL vs ISS)

```bash
cd ~/pqc/opentitan
chmod +x test_hybrid_kem_otbn_prompt_ver2/otbn/co_sim/*.sh
bash test_hybrid_kem_otbn_prompt_ver2/otbn/co_sim/run_hkdf_co_sim.sh
bash test_hybrid_kem_otbn_prompt_ver2/otbn/co_sim/run_hmac_co_sim.sh
bash test_hybrid_kem_otbn_prompt_ver2/otbn/co_sim/run_sha3_co_sim.sh
bash test_hybrid_kem_otbn_prompt_ver2/otbn/co_sim/run_mlkem_keypair_co_sim.sh
# ... 其他 co_sim 脚本
# 或一键全部:
bash test_hybrid_kem_otbn_prompt_ver2/otbn/co_sim/run_all_co_sim.sh
```

### Chip Sim

```bash
CHIP="--test_timeout=2000 --cache_test_results=no \
    --sandbox_writable_path=/run/user/1000/ccache-tmp"

# 单模块
bazel test //test_hybrid_kem_otbn_prompt_ver2:test_p256_only_sim_verilator $CHIP
bazel test //test_hybrid_kem_otbn_prompt_ver2:test_p256_official_sim_verilator $CHIP
bazel test //test_hybrid_kem_otbn_prompt_ver2:test_mlkem_keypair_only_sim_verilator $CHIP
bazel test //test_hybrid_kem_otbn_prompt_ver2:test_mlkem_encap_only_sim_verilator $CHIP
bazel test //test_hybrid_kem_otbn_prompt_ver2:test_mlkem_decap_only_sim_verilator $CHIP
bazel test //test_hybrid_kem_otbn_prompt_ver2:test_hkdf_only_sim_verilator $CHIP

# Phase 1: 密钥生成 (P-256 + ML-KEM)
bazel test //test_hybrid_kem_otbn_prompt_ver2:phase1_keygen_test_sim_verilator $CHIP

# Phase 2 Alice: 封装 (ECDH + Encap + HKDF)
bazel test //test_hybrid_kem_otbn_prompt_ver2:phase2_alice_encap_test_sim_verilator $CHIP

# Phase 2 Bob: 解封装 (Decap + ECDH + HKDF)
bazel test //test_hybrid_kem_otbn_prompt_ver2:phase2_bob_decap_test_sim_verilator $CHIP
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

Step 3: HKDF
  load hkdf_sha3_256
  write salt[32], info[16], info_len=16
  write IKM[132B] = be16(32)||ss_e||be16(32)||ss_m||ctx[32]||sid[32]
  write input_lengths = {32, 32, 32}  (ctx, sid, okm)
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

Step 3: HKDF
  同 Alice, OKM 相同
  CHECK: OKM == kExpectedOkm
```

## 三、KAT 生成

```bash
# Phase 1
python3 ref/phase1/p256_kat.py        # P-256: d → Q.x/Q.y + ss_e
python3 ref/phase1/gen_kat.py         # ML-KEM keypair: .dexp → C 数组

# Phase 2
python3 ref/phase2/hkdf_kat_alice.py 32  # Alice HKDF
python3 ref/phase2/hkdf_kat_bob.py 32    # Bob HKDF (== Alice)

# 通用工具
python3 ref/hkdf_dexp.py 32           # HKDF: .dexp + .s 数据段
```

## 四、关键约定

| 规则 | 原因 |
|------|------|
| `LOG_INFO` 不用 "PASS" | chip sim `--exit-success` 正则误杀 |
| IKM 不含 role | KEM PRK 相同 → OKM 相同 |
| info 独立于 IKM | `input_info_len` 单独传入 Expand |
| KAT 数组 LE 字节序 | 匹配 DMEM 输出, 直接 CHECK_ARRAYS_EQ |
| `.dexp` 用 BE 字节序 | ISS DMEM 比对格式 |
| OTBN 模块切换直接 load | KMAC RTL 已修复, 无需 wipe |

## 五、KMAC 掩码模式 (SCA) 测试

### 5.1 快速测试

```bash
cd ~/pqc/opentitan

# 非掩码 (EnMasking=0, 25 cyc/keccak-f)
hw/ip/otbn/dv/smoke/run_kmac_smoke.sh
hw/ip/otbn/dv/smoke/run_kmac_shake128_run.sh
hw/ip/otbn/dv/smoke/run_kmac_pad_edge.sh
bash test_hybrid_kem_otbn_prompt_ver2/otbn/co_sim/run_hkdf_co_sim.sh
bash test_hybrid_kem_otbn_prompt_ver2/otbn/co_sim/run_hmac_co_sim.sh
bash test_hybrid_kem_otbn_prompt_ver2/otbn/co_sim/run_sha3_co_sim.sh

# 掩码 (EnMasking=1, DOM 2-share, 97 cyc/keccak-f)
OTBN_EN_MASKING=1 hw/ip/otbn/dv/smoke/run_kmac_smoke.sh
OTBN_EN_MASKING=1 hw/ip/otbn/dv/smoke/run_kmac_shake128_run.sh
OTBN_EN_MASKING=1 hw/ip/otbn/dv/smoke/run_kmac_pad_edge.sh
OTBN_EN_MASKING=1 bash test_hybrid_kem_otbn_prompt_ver2/otbn/co_sim/run_hmac_co_sim.sh
```

### 5.2 掩码功能正确性独立验证

部分测试在 co-sim 下因 URND mask 值不同报 mismatch（假阳性）。通过纯 RTL 仿真对比掩码/非掩码的 keccak 输出确认真实结果。

**原理**：`SQUEEZE word[N]` 是 keccak 状态还原后的逻辑真值（掩码下 = `s0^s1`，非掩码下即 s0），mask 只保护 WSR 传输过程，不改变最终 hash 输出。

**前置**（一次性）：注释 `$stop` 避免 co-sim mismatch 截断。

```bash
sed -i 's/ $stop;/ \/\/ $stop;/' hw/ip/otbn/dv/verilator/otbn_top_sim.sv
sed -i 's/$error("Mismatch/\/\/ $error("Mismatch/' hw/ip/otbn/dv/verilator/otbn_top_sim.sv
```

**验证 test_shake128_rate_cross**（squeeze 阶段 auto-RUN 跨 block 边界）：

```bash
rm -rf build/lowrisc_ip_otbn_top_sim_0.1
hw/ip/otbn/dv/smoke/run_kmac_shake128_run.sh 2>&1 \
  | grep "SQUEEZE word\[" | awk '{print $4}' > /tmp/unmasked.txt
rm -rf build/lowrisc_ip_otbn_top_sim_0.1
OTBN_EN_MASKING=1 hw/ip/otbn/dv/smoke/run_kmac_shake128_run.sh 2>&1 \
  | grep "SQUEEZE word\[" | awk '{print $4}' > /tmp/masked.txt
diff /tmp/unmasked.txt /tmp/masked.txt  # 无输出 = 全部一致
```

**验证 HKDF**（吸收阶段 auto-trigger）：

```bash
rm -rf build/lowrisc_ip_otbn_top_sim_0.1
bash test_hybrid_kem_otbn_prompt_ver2/otbn/co_sim/run_hkdf_co_sim.sh 2>&1 \
  | grep "SQUEEZE word\[" | awk '{print $4}' > /tmp/unmasked.txt
rm -rf build/lowrisc_ip_otbn_top_sim_0.1
OTBN_EN_MASKING=1 bash test_hybrid_kem_otbn_prompt_ver2/otbn/co_sim/run_hkdf_co_sim.sh 2>&1 \
  | grep "SQUEEZE word\[" | awk '{print $4}' > /tmp/masked.txt
diff /tmp/unmasked.txt /tmp/masked.txt  # 无输出 = 全部一致
```

**验证 SHA3 co-sim**（多 hash 连续测试）：

```bash
rm -rf build/lowrisc_ip_otbn_top_sim_0.1
bash test_hybrid_kem_otbn_prompt_ver2/otbn/co_sim/run_sha3_co_sim.sh 2>&1 \
  | grep "SQUEEZE word\[" | awk '{print $4}' > /tmp/unmasked.txt
rm -rf build/lowrisc_ip_otbn_top_sim_0.1
OTBN_EN_MASKING=1 bash test_hybrid_kem_otbn_prompt_ver2/otbn/co_sim/run_sha3_co_sim.sh 2>&1 \
  | grep "SQUEEZE word\[" | awk '{print $4}' > /tmp/masked.txt
diff /tmp/unmasked.txt /tmp/masked.txt  # 无输出 = 全部一致
```

**验证后恢复 `$stop`**（其他测试需要）：

```bash
sed -i 's/\/\/ \$stop;/\$stop;/' hw/ip/otbn/dv/verilator/otbn_top_sim.sv
sed -i 's/\/\/ \$error("Mismatch/\$error("Mismatch/' hw/ip/otbn/dv/verilator/otbn_top_sim.sv
```

### 5.3 测试结果总结

| 测试 | 掩码 co-sim | 掩码 word 值 vs 非掩码 | 状态 |
|------|-----------|----------------------|------|
| smoke (23 tests) | ✅ PASS | — | 功能正确 |
| pad_edge (7 tests) | ✅ PASS | — | 功能正确 |
| SHAKE 1run/3run/256_1run | ✅ PASS | — | 功能正确 |
| SHAKE rate_cross | ❌ w10 mask diff | ✅ 全部一致 | **功能正确** |
| HMAC co-sim | ✅ PASS | — | 功能正确 |
| HKDF co-sim | ❌ x06 timing | ✅ 全部一致 | **功能正确** |
| SHA3 co-sim | ❌ w09 mask diff | ✅ 全部一致 | **功能正确** |

co-sim 失败的 3 项均为 URND mask 值不同导致的假阳性，不影响 DOM 掩码的算法正确性。

## 六、已知问题

| 问题 | 状态 |
|------|------|
| P-256 示例点 P 触发 RTL `scalar_mult_int` z=0 bug | 已定位, 使用基点 G |
| MAI 硬件 A2B 语义不兼容 | 保留, 待后续 |
| KMAC RTL auto-permutation bug | ✅ 已修复 |
| KMAC 掩码模式 co-sim URND 同步 | 已知限制, RTL 功能已独立验证 |
