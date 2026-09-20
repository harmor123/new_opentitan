# ver0_1 chip-sim 测试日志（最新一轮）

> 采集：OpenTitan Earlgrey **chip sim**（Verilator）；周期 = Ibex `mcycle`（`profile.h`）+ OTBN `INSN_CNT`
> 布局：IMEM 32 KB 扩展（DMEM@0x4000 / IMEM@0x8000，commit `a4125dc960` + `otbn.sv` 窗口索引修复）

## 复现命令

```bash
cd ~/new_pqc/opentitan
CHIP="--test_timeout=2000 --cache_test_results=no --sandbox_writable_path=/run/user/1000/ccache-tmp"
V=ver0_1; P=test_hybrid_kem_otbn_prompt_ver0_1
TESTS="test_mlkem_keypair_only test_mlkem_encap_only test_mlkem_decap_only \n       test_p256_only test_hkdf_only phase1_keygen_test \n       phase2_alice_encap_test phase2_bob_decap_test"

bazel build $(for t in $TESTS; do echo //${P}:${t}_sim_verilator; done) $CHIP
mkdir -p logs_hkem/${V}
for t in $TESTS; do
  rf="bazel-bin/${P}/${t}_sim_verilator.bash.runfiles/_main"
  ( cd "$rf" && ./${P}/${t}_sim_verilator.bash ) > logs_hkem/${V}/${t}.sim.log 2>&1
  cp "$rf/uart0.log" logs_hkem/${V}/${t}.uart0.log
  echo "===== ${t} ====="
  grep -aE "cycles|insn_cnt|instruction|OTBN|HKEM|PASS|FAIL" logs_hkem/${V}/${t}.uart0.log | tail -60
done
```

## 结果（8/8 PASS）

### test_mlkem_keypair_only

```
ottf_main.c:175] Running test_hybrid_kem_otbn_prompt_ver0_1/ibex/test_mlkem_keypair_only.c
test_mlkem_keypair_only.c:50] mlkem768_keypair cycles: 559771, OTBN insn_cnt: 511152
ottf_main.c:114] Finished test_hybrid_kem_otbn_prompt_ver0_1/ibex/test_mlkem_keypair_only.c
status.c:37] PASS!
```

### test_mlkem_encap_only

```
ottf_main.c:175] Running test_hybrid_kem_otbn_prompt_ver0_1/ibex/test_mlkem_encap_only.c
test_mlkem_encap_only.c:125] mlkem768_encap cycles: 608845, OTBN insn_cnt: 558624
ottf_main.c:114] Finished test_hybrid_kem_otbn_prompt_ver0_1/ibex/test_mlkem_encap_only.c
status.c:37] PASS!
```

### test_mlkem_decap_only

```
ottf_main.c:175] Running test_hybrid_kem_otbn_prompt_ver0_1/ibex/test_mlkem_decap_only.c
test_mlkem_decap_only.c:267] mlkem768_decap cycles: 669376, OTBN insn_cnt: 617113
ottf_main.c:114] Finished test_hybrid_kem_otbn_prompt_ver0_1/ibex/test_mlkem_decap_only.c
status.c:37] PASS!
```

### test_p256_only

```
ottf_main.c:175] Running test_hybrid_kem_otbn_prompt_ver0_1/ibex/test_p256_only.c
test_p256_only.c:110] Keygen A OTBN instruction count: 0x0008c1e2, cycles: 767992
test_p256_only.c:117] Keygen B OTBN instruction count: 0x0008c1e2, cycles: 766456
test_p256_only.c:150] ECDH A OTBN instruction count: 0x0008dfe7, cycles: 796568
test_p256_only.c:158] ECDH B OTBN instruction count: 0x0008dfe7, cycles: 796179
test_p256_only.c:219] Upstream P-256 ECDH test passed.
ottf_main.c:114] Finished test_hybrid_kem_otbn_prompt_ver0_1/ibex/test_p256_only.c
status.c:37] PASS!
```

### test_hkdf_only

```
ottf_main.c:175] Running test_hybrid_kem_otbn_prompt_ver0_1/ibex/test_hkdf_only.c
test_hkdf_only.c:227] Loading HKDF-HMAC-SHA3-256 OTBN app...
test_hkdf_only.c:417] HKDF cycles = 55538, total OTBN instructions = 51145
test_hkdf_only.c:504] HKDF-HMAC-SHA3-256 standalone correctness PASS.
```

### phase1_keygen_test

```
ottf_main.c:175] Running test_hybrid_kem_otbn_prompt_ver0_1/ibex/phase1_keygen/phase1_keygen_test.c
phase1_keygen_test.c:76] HKEM_PROF,phase1_keygen,p256_keygen_total,719454
phase1_keygen_test.c:76] HKEM_PROF,phase1_keygen,mlkem_keypair_load,445027
phase1_keygen_test.c:76] HKEM_PROF,phase1_keygen,mlkem_keypair_write_inputs,1750
phase1_keygen_test.c:76] HKEM_PROF,phase1_keygen,mlkem_keypair_execute_wait,559817
phase1_keygen_test.c:76] HKEM_PROF,phase1_keygen,mlkem_keypair_read_outputs,55528
phase1_keygen_test.c:73] HKEM_PROF_TEST,phase1_keygen,check_mlkem_keypair,15439
phase1_keygen_test.c:76] HKEM_PROF,phase1_keygen,wipe_after_mlkem_keypair,1288
phase1_keygen_test.c:80] HKEM_PROF,phase1_keygen,protocol_total,1782864
phase1_keygen_test.c:81] HKEM_PROF_TEST,phase1_keygen,test_total,15439
phase1_keygen_test.c:83] HKEM_PROF_SCOPE,phase1_keygen,scope_total,2156430
phase1_keygen_test.c:85] HKEM_PROF_SCOPE,phase1_keygen,accounted_total,1798303
phase1_keygen_test.c:87] HKEM_PROF_SCOPE,phase1_keygen,unaccounted_total,358127
ottf_main.c:114] Finished test_hybrid_kem_otbn_prompt_ver0_1/ibex/phase1_keygen/phase1_keygen_test.c
status.c:37] PASS!
```

### phase2_alice_encap_test

```
ottf_main.c:175] Running test_hybrid_kem_otbn_prompt_ver0_1/ibex/phase2_encap_decap/phase2_alice_encap.c
phase2_alice_encap.c:417] p256_ecdh OTBN instruction count: 0x0008dfe7
phase2_alice_encap.c:451] mlkem768_encap OTBN instruction count = 558624
phase2_alice_encap.c:523] hkdf_sha3_256 OTBN instruction count = 51145
phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,p256_ecdh_official_api,741118
phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,p256_unmask,437
phase2_alice_encap.c:78] HKEM_PROF_TEST,phase2_alice_encap,check_p256_ss,395
phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,mlkem_encap_load,422637
phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,mlkem_encap_write_inputs,22646
phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,mlkem_encap_execute_wait,608890
phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,mlkem_encap_read_outputs,18047
phase2_alice_encap.c:78] HKEM_PROF_TEST,phase2_alice_encap,check_mlkem_encap,5024
phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,wipe_after_mlkem_encap,1278
phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,hkdf_load,130108
phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,hkdf_write_params,1559
phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,hkdf_write_info_len,285
phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,hkdf_assemble_ikm,803
phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,hkdf_write_ikm,2769
phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,hkdf_execute_wait,55561
phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,hkdf_read_output,838
phase2_alice_encap.c:78] HKEM_PROF_TEST,phase2_alice_encap,check_hkdf_okm,362
phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,wipe_after_hkdf,1329
phase2_alice_encap.c:85] HKEM_PROF,phase2_alice_encap,protocol_total,2008305
phase2_alice_encap.c:86] HKEM_PROF_TEST,phase2_alice_encap,test_total,5781
phase2_alice_encap.c:88] HKEM_PROF_SCOPE,phase2_alice_encap,scope_total,2214518
phase2_alice_encap.c:90] HKEM_PROF_SCOPE,phase2_alice_encap,accounted_total,2014086
phase2_alice_encap.c:92] HKEM_PROF_SCOPE,phase2_alice_encap,unaccounted_total,200432
ottf_main.c:114] Finished test_hybrid_kem_otbn_prompt_ver0_1/ibex/phase2_encap_decap/phase2_alice_encap.c
status.c:37] PASS!
```

### phase2_bob_decap_test

```
ottf_main.c:175] Running test_hybrid_kem_otbn_prompt_ver0_1/ibex/phase2_encap_decap/phase2_bob_decap.c
phase2_bob_decap.c:463] mlkem768_decap OTBN instruction count = 617113
phase2_bob_decap.c:524] p256_ecdh OTBN instruction count: 0x0008dfe7
phase2_bob_decap.c:586] hkdf_sha3_256 OTBN instruction count = 51145
phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,mlkem_decap_load,455815
phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,mlkem_decap_write_inputs,64224
phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,mlkem_decap_execute_wait,669463
phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,mlkem_decap_read_outputs,944
phase2_bob_decap.c:76] HKEM_PROF_TEST,phase2_bob_decap,check_mlkem_decap,414
phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,wipe_after_mlkem_decap,1269
phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,p256_ecdh_official_api,743093
phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,p256_unmask,462
phase2_bob_decap.c:76] HKEM_PROF_TEST,phase2_bob_decap,check_p256_ss,410
phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,hkdf_load,130426
phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,hkdf_write_params,1548
phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,hkdf_write_info_len,310
phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,hkdf_assemble_ikm,794
phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,hkdf_write_ikm,2672
phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,hkdf_execute_wait,55593
phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,hkdf_read_output,942
phase2_bob_decap.c:76] HKEM_PROF_TEST,phase2_bob_decap,check_hkdf_okm,371
phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,wipe_after_hkdf,1308
phase2_bob_decap.c:83] HKEM_PROF,phase2_bob_decap,protocol_total,2128863
phase2_bob_decap.c:84] HKEM_PROF_TEST,phase2_bob_decap,test_total,1195
phase2_bob_decap.c:86] HKEM_PROF_SCOPE,phase2_bob_decap,scope_total,2326704
phase2_bob_decap.c:88] HKEM_PROF_SCOPE,phase2_bob_decap,accounted_total,2130058
phase2_bob_decap.c:90] HKEM_PROF_SCOPE,phase2_bob_decap,unaccounted_total,196646
ottf_main.c:114] Finished test_hybrid_kem_otbn_prompt_ver0_1/ibex/phase2_encap_decap/phase2_bob_decap.c
status.c:37] PASS!
```
