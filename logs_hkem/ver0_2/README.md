# ver0_2 chip-sim 测试日志（最新一轮）

> 采集：OpenTitan Earlgrey **chip sim**（Verilator）；周期 = Ibex `mcycle`（`profile.h`）+ OTBN `INSN_CNT`
> 布局：IMEM 32 KB 扩展（DMEM@0x4000 / IMEM@0x8000，commit `a4125dc960` + `otbn.sv` 窗口索引修复）

## 复现命令

```bash
cd ~/new_pqc/opentitan
CHIP="--test_timeout=2000 --cache_test_results=no --sandbox_writable_path=/run/user/1000/ccache-tmp"
V=ver0_2; P=test_hybrid_kem_otbn_prompt_ver0_2
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
ottf_main.c:175] Running test_hybrid_kem_otbn_prompt_ver0_2/ibex/test_mlkem_keypair_only.c
test_mlkem_keypair_only.c:50] mlkem768_keypair cycles: 176463, OTBN insn_cnt: 157624
ottf_main.c:114] Finished test_hybrid_kem_otbn_prompt_ver0_2/ibex/test_mlkem_keypair_only.c
status.c:37] PASS!
```

### test_mlkem_encap_only

```
ottf_main.c:175] Running test_hybrid_kem_otbn_prompt_ver0_2/ibex/test_mlkem_encap_only.c
test_mlkem_encap_only.c:125] mlkem768_encap cycles: 216248, OTBN insn_cnt: 196446
ottf_main.c:114] Finished test_hybrid_kem_otbn_prompt_ver0_2/ibex/test_mlkem_encap_only.c
status.c:37] PASS!
```

### test_mlkem_decap_only

```
ottf_main.c:175] Running test_hybrid_kem_otbn_prompt_ver0_2/ibex/test_mlkem_decap_only.c
test_mlkem_decap_only.c:267] mlkem768_decap cycles: 277294, OTBN insn_cnt: 255383
ottf_main.c:114] Finished test_hybrid_kem_otbn_prompt_ver0_2/ibex/test_mlkem_decap_only.c
status.c:37] PASS!
```

### test_p256_only

```
ottf_main.c:175] Running test_hybrid_kem_otbn_prompt_ver0_2/ibex/test_p256_only.c
test_p256_only.c:110] Keygen A OTBN instruction count: 0x0008c1e2, cycles: 767441
test_p256_only.c:117] Keygen B OTBN instruction count: 0x0008c1e2, cycles: 766924
test_p256_only.c:150] ECDH A OTBN instruction count: 0x0008dfe7, cycles: 796331
test_p256_only.c:158] ECDH B OTBN instruction count: 0x0008dfe7, cycles: 795957
test_p256_only.c:219] Upstream P-256 ECDH test passed.
ottf_main.c:114] Finished test_hybrid_kem_otbn_prompt_ver0_2/ibex/test_p256_only.c
status.c:37] PASS!
```

### test_hkdf_only

```
ottf_main.c:175] Running test_hybrid_kem_otbn_prompt_ver0_2/ibex/test_hkdf_only.c
test_hkdf_only.c:227] Loading HKDF-HMAC-SHA3-256 OTBN app...
test_hkdf_only.c:417] HKDF cycles = 5254, total OTBN instructions = 3374
test_hkdf_only.c:504] HKDF-HMAC-SHA3-256 standalone correctness PASS.
```

### phase1_keygen_test

```
ottf_main.c:175] Running test_hybrid_kem_otbn_prompt_ver0_2/ibex/phase1_keygen/phase1_keygen_test.c
phase1_keygen_test.c:76] HKEM_PROF,phase1_keygen,p256_keygen_total,719358
phase1_keygen_test.c:76] HKEM_PROF,phase1_keygen,mlkem_keypair_load,309989
phase1_keygen_test.c:76] HKEM_PROF,phase1_keygen,mlkem_keypair_write_inputs,1632
phase1_keygen_test.c:76] HKEM_PROF,phase1_keygen,mlkem_keypair_execute_wait,176494
phase1_keygen_test.c:76] HKEM_PROF,phase1_keygen,mlkem_keypair_read_outputs,55641
phase1_keygen_test.c:73] HKEM_PROF_TEST,phase1_keygen,check_mlkem_keypair,15451
phase1_keygen_test.c:76] HKEM_PROF,phase1_keygen,wipe_after_mlkem_keypair,1268
phase1_keygen_test.c:80] HKEM_PROF,phase1_keygen,protocol_total,1264382
phase1_keygen_test.c:81] HKEM_PROF_TEST,phase1_keygen,test_total,15451
phase1_keygen_test.c:83] HKEM_PROF_SCOPE,phase1_keygen,scope_total,1637972
phase1_keygen_test.c:85] HKEM_PROF_SCOPE,phase1_keygen,accounted_total,1279833
phase1_keygen_test.c:87] HKEM_PROF_SCOPE,phase1_keygen,unaccounted_total,358139
ottf_main.c:114] Finished test_hybrid_kem_otbn_prompt_ver0_2/ibex/phase1_keygen/phase1_keygen_test.c
status.c:37] PASS!
```

### phase2_alice_encap_test

```
ottf_main.c:175] Running test_hybrid_kem_otbn_prompt_ver0_2/ibex/phase2_encap_decap/phase2_alice_encap.c
phase2_alice_encap.c:417] p256_ecdh OTBN instruction count: 0x0008dfe7
phase2_alice_encap.c:451] mlkem768_encap OTBN instruction count = 196446
phase2_alice_encap.c:523] hkdf_sha3_256 OTBN instruction count = 3374
phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,p256_ecdh_official_api,741118
phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,p256_unmask,437
phase2_alice_encap.c:78] HKEM_PROF_TEST,phase2_alice_encap,check_p256_ss,395
phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,mlkem_encap_load,361071
phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,mlkem_encap_write_inputs,22694
phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,mlkem_encap_execute_wait,216355
phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,mlkem_encap_read_outputs,17965
phase2_alice_encap.c:78] HKEM_PROF_TEST,phase2_alice_encap,check_mlkem_encap,5059
phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,wipe_after_mlkem_encap,1314
phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,hkdf_load,86709
phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,hkdf_write_params,1465
phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,hkdf_write_info_len,271
phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,hkdf_assemble_ikm,766
phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,hkdf_write_ikm,2738
phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,hkdf_execute_wait,5389
phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,hkdf_read_output,856
phase2_alice_encap.c:78] HKEM_PROF_TEST,phase2_alice_encap,check_hkdf_okm,386
phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,wipe_after_hkdf,1319
phase2_alice_encap.c:85] HKEM_PROF,phase2_alice_encap,protocol_total,1460467
phase2_alice_encap.c:86] HKEM_PROF_TEST,phase2_alice_encap,test_total,5840
phase2_alice_encap.c:88] HKEM_PROF_SCOPE,phase2_alice_encap,scope_total,1666356
phase2_alice_encap.c:90] HKEM_PROF_SCOPE,phase2_alice_encap,accounted_total,1466307
phase2_alice_encap.c:92] HKEM_PROF_SCOPE,phase2_alice_encap,unaccounted_total,200049
ottf_main.c:114] Finished test_hybrid_kem_otbn_prompt_ver0_2/ibex/phase2_encap_decap/phase2_alice_encap.c
```

### phase2_bob_decap_test

```
ottf_main.c:175] Running test_hybrid_kem_otbn_prompt_ver0_2/ibex/phase2_encap_decap/phase2_bob_decap.c
phase2_bob_decap.c:463] mlkem768_decap OTBN instruction count = 255383
phase2_bob_decap.c:524] p256_ecdh OTBN instruction count: 0x0008dfe7
phase2_bob_decap.c:586] hkdf_sha3_256 OTBN instruction count = 3374
phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,mlkem_decap_load,395027
phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,mlkem_decap_write_inputs,64344
phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,mlkem_decap_execute_wait,277372
phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,mlkem_decap_read_outputs,932
phase2_bob_decap.c:76] HKEM_PROF_TEST,phase2_bob_decap,check_mlkem_decap,418
phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,wipe_after_mlkem_decap,1310
phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,p256_ecdh_official_api,742977
phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,p256_unmask,441
phase2_bob_decap.c:76] HKEM_PROF_TEST,phase2_bob_decap,check_p256_ss,403
phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,hkdf_load,87132
phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,hkdf_write_params,1482
phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,hkdf_write_info_len,283
phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,hkdf_assemble_ikm,798
phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,hkdf_write_ikm,2706
phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,hkdf_execute_wait,5327
phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,hkdf_read_output,836
phase2_bob_decap.c:76] HKEM_PROF_TEST,phase2_bob_decap,check_hkdf_okm,395
phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,wipe_after_hkdf,1281
phase2_bob_decap.c:83] HKEM_PROF,phase2_bob_decap,protocol_total,1582248
phase2_bob_decap.c:84] HKEM_PROF_TEST,phase2_bob_decap,test_total,1216
phase2_bob_decap.c:86] HKEM_PROF_SCOPE,phase2_bob_decap,scope_total,1778927
phase2_bob_decap.c:88] HKEM_PROF_SCOPE,phase2_bob_decap,accounted_total,1583464
phase2_bob_decap.c:90] HKEM_PROF_SCOPE,phase2_bob_decap,unaccounted_total,195463
ottf_main.c:114] Finished test_hybrid_kem_otbn_prompt_ver0_2/ibex/phase2_encap_decap/phase2_bob_decap.c
status.c:37] PASS!
```
