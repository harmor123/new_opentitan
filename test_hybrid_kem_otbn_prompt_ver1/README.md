# Hybrid KEM — ver1 (KMAC Hash + 基线 ML-KEM)

ML-KEM-768 (基线指令) + P-256 ECDH — 全部哈希（SHA3/HMAC/HKDF + ML-KEM 内部 SHAKE）使用 KMAC 硬件加速。

与 ver0 的区别：所有 SHA3/SHAKE 调用走 KMAC 硬件。与 ver2 的区别：ML-KEM 无 BNMULV_VER2 向量指令。

## 快速命令

```bash
cd ~/pqc/opentitan

# === ISS (软件模拟) ===
bazel test //test_hybrid_kem_otbn_prompt_ver1/otbn/test:all --cache_test_results=no

# 单独跑
bazel test //test_hybrid_kem_otbn_prompt_ver1/otbn/test:sha3_test
bazel test //test_hybrid_kem_otbn_prompt_ver1/otbn/test:hmac_test
bazel test //test_hybrid_kem_otbn_prompt_ver1/otbn/test:hkdf_test
bazel test //test_hybrid_kem_otbn_prompt_ver1/otbn/test:mlkem768_keypair_test
bazel test //test_hybrid_kem_otbn_prompt_ver1/otbn/test:mlkem768_encap_test
bazel test //test_hybrid_kem_otbn_prompt_ver1/otbn/test:mlkem768_decap_test
bazel test //test_hybrid_kem_otbn_prompt_ver1/otbn/test:p256_ecdh_test

# === OTBN 二进制 ===
bazel build //test_hybrid_kem_otbn_prompt_ver1/otbn/hkdf:sha3_test_bin
bazel build //test_hybrid_kem_otbn_prompt_ver1/otbn/hkdf:hmac_sha3_256
bazel build //test_hybrid_kem_otbn_prompt_ver1/otbn/hkdf:hkdf_sha3_256
bazel build //test_hybrid_kem_otbn_prompt_ver1/otbn/p256:p256_ecdh_shared_key
bazel build //test_hybrid_kem_otbn_prompt_ver1/otbn/mlkem768:mlkem768_keypair
bazel build //test_hybrid_kem_otbn_prompt_ver1/otbn/mlkem768:mlkem768_encap
bazel build //test_hybrid_kem_otbn_prompt_ver1/otbn/mlkem768:mlkem768_decap

# === OTBN co-sim (RTL vs ISS) ===
chmod +x test_hybrid_kem_otbn_prompt_ver1/otbn/co_sim/*.sh
bash test_hybrid_kem_otbn_prompt_ver1/otbn/co_sim/run_sha3_co_sim.sh
bash test_hybrid_kem_otbn_prompt_ver1/otbn/co_sim/run_hmac_co_sim.sh
bash test_hybrid_kem_otbn_prompt_ver1/otbn/co_sim/run_hkdf_co_sim.sh
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
bazel test //test_hybrid_kem_otbn_prompt_ver1:test_hkdf_only_sim_verilator $CHIP
bazel test //test_hybrid_kem_otbn_prompt_ver1:phase1_keygen_test_sim_verilator $CHIP
bazel test //test_hybrid_kem_otbn_prompt_ver1:phase2_alice_encap_test_sim_verilator $CHIP
bazel test //test_hybrid_kem_otbn_prompt_ver1:phase2_bob_decap_test_sim_verilator $CHIP
```

### 掩码模式
```bash
OTBN_EN_MASKING=1 hw/ip/otbn/dv/smoke/run_kmac_shake128_run.sh 
```
## 三版本对比

| | ver0 (纯软件) | ver1 (KMAC混合) | ver2 (硬件加速) |
|------|------|------|------|
| ML-KEM 指令集 | 基线 | 基线 | BNMULV_VER2 |
| ML-KEM 哈希 | 软件 Keccak-f | **KMAC 硬件** | KMAC 硬件 |
| SHA3/HMAC | 软件 Keccak-f | KMAC 硬件 | KMAC 硬件 |
| HKDF | 软件 HMAC | KMAC 硬件 | KMAC 硬件 |
| P-256 | 软件 | 软件 | 软件 |
| co_sim | 需要 | 需要 | 需要 |

## 目录

```
├── BUILD               # chip sim 测试目标
├── README.md
├── ibex/               # Ibex C 测试代码
├── otbn/
│   ├── p256/           # P-256 (同 ver0)
│   ├── mlkem768/       # ML-KEM 基线 + KMAC SHA3
│   ├── hkdf/           # KMAC-based SHA3/HMAC/HKDF (同 ver2)
│   ├── test/           # ISS 测试 + dexp
│   └── co_sim/         # RTL+ISS co-sim 脚本
└── ref/                # Python KAT 生成器
```

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