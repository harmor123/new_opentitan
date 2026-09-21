# ver1_1 chip-sim 测试日志（最新一轮）

> 采集：OpenTitan Earlgrey **chip sim**（Verilator）；周期 = Ibex `mcycle`（`profile.h`）+ OTBN `INSN_CNT`
> 布局：IMEM 32 KB 扩展（DMEM@0x4000 / IMEM@0x8000，commit `a4125dc960` + `otbn.sv` 窗口索引修复）

## 复现命令

```bash
cd ~/new_pqc/opentitan
V=ver1_1; P=test_hybrid_kem_otbn_prompt_ver1_1
mkdir -p logs_hkem/$V                                      # ② 新增
for t in test_mlkem_keypair_only test_mlkem_encap_only test_mlkem_decap_only \
         test_p256_only test_hkdf_only phase1_keygen_test \
         phase2_alice_encap_test phase2_bob_decap_test; do
  echo "===== 运行 $t ====="
  rf="bazel-bin/${P}/${t}_sim_verilator.bash.runfiles/_main"
  ( cd "$rf" && ./${P}/${t}_sim_verilator.bash ) > logs_hkem/$V/${t}.sim.log 2>&1    # ③ 加 $V/
  cp "$rf/uart0.log" logs_hkem/$V/${t}.uart0.log                                     # ③ 加 $V/
  echo "----- $t 关键行 -----"
  grep -aE "cycles|insn_cnt|instruction|OTBN|HKEM|PASS|FAIL" logs_hkem/$V/${t}.uart0.log | tail -60
done
```

## 结果（8/8 PASS）

### test_mlkem_keypair_only

```
ottf_main.c:175] Running test_hybrid_kem_otbn_prompt_ver1_1/ibex/test_mlkem_keypair_only.c
test_mlkem_keypair_only.c:50] mlkem768_keypair cycles: 139563, OTBN insn_cnt: 97301
ottf_main.c:114] Finished test_hybrid_kem_otbn_prompt_ver1_1/ibex/test_mlkem_keypair_only.c
status.c:37] PASS!
```

### test_mlkem_encap_only

```
ottf_main.c:175] Running test_hybrid_kem_otbn_prompt_ver1_1/ibex/test_mlkem_encap_only.c
test_mlkem_encap_only.c:125] mlkem768_encap cycles: 171654, OTBN insn_cnt: 118987
ottf_main.c:114] Finished test_hybrid_kem_otbn_prompt_ver1_1/ibex/test_mlkem_encap_only.c
```

### test_mlkem_decap_only

```
ottf_main.c:175] Running test_hybrid_kem_otbn_prompt_ver1_1/ibex/test_mlkem_decap_only.c
test_mlkem_decap_only.c:267] mlkem768_decap cycles: 217171, OTBN insn_cnt: 145331
ottf_main.c:114] Finished test_hybrid_kem_otbn_prompt_ver1_1/ibex/test_mlkem_decap_only.c
status.c:37] PASS!
```

### test_p256_only

```
ottf_main.c:175] Running test_hybrid_kem_otbn_prompt_ver1_1/ibex/test_p256_only.c
test_p256_only.c:110] Keygen A OTBN instruction count: 0x0008c1e2, cycles: 767972
test_p256_only.c:117] Keygen B OTBN instruction count: 0x0008c1e2, cycles: 766738
test_p256_only.c:150] ECDH A OTBN instruction count: 0x0008dfe7, cycles: 796312
test_p256_only.c:158] ECDH B OTBN instruction count: 0x0008dfe7, cycles: 795942
test_p256_only.c:219] Upstream P-256 ECDH test passed.
ottf_main.c:114] Finished test_hybrid_kem_otbn_prompt_ver1_1/ibex/test_p256_only.c
status.c:37] PASS!
```

### test_hkdf_only

```
ottf_main.c:175] Running test_hybrid_kem_otbn_prompt_ver1_1/ibex/test_hkdf_only.c
test_hkdf_only.c:227] Loading HKDF-HMAC-SHA3-256 OTBN app...
test_hkdf_only.c:417] HKDF cycles = 5311, total OTBN instructions = 3374
test_hkdf_only.c:504] HKDF-HMAC-SHA3-256 standalone correctness PASS.
```

### phase1_keygen_test

```
ottf_main.c:175] Running test_hybrid_kem_otbn_prompt_ver1_1/ibex/phase1_keygen/phase1_keygen_test.c
phase1_keygen_test.c:76] HKEM_PROF,phase1_keygen,p256_keygen_total,719303
phase1_keygen_test.c:76] HKEM_PROF,phase1_keygen,mlkem_keypair_load,259362
phase1_keygen_test.c:76] HKEM_PROF,phase1_keygen,mlkem_keypair_write_inputs,1683
phase1_keygen_test.c:76] HKEM_PROF,phase1_keygen,mlkem_keypair_execute_wait,139551
phase1_keygen_test.c:76] HKEM_PROF,phase1_keygen,mlkem_keypair_read_outputs,55688
phase1_keygen_test.c:73] HKEM_PROF_TEST,phase1_keygen,check_mlkem_keypair,15491
phase1_keygen_test.c:76] HKEM_PROF,phase1_keygen,wipe_after_mlkem_keypair,1265
phase1_keygen_test.c:80] HKEM_PROF,phase1_keygen,protocol_total,1176852
phase1_keygen_test.c:81] HKEM_PROF_TEST,phase1_keygen,test_total,15491
phase1_keygen_test.c:83] HKEM_PROF_SCOPE,phase1_keygen,scope_total,1550133
phase1_keygen_test.c:85] HKEM_PROF_SCOPE,phase1_keygen,accounted_total,1192343
phase1_keygen_test.c:87] HKEM_PROF_SCOPE,phase1_keygen,unaccounted_total,357790
ottf_main.c:114] Finished test_hybrid_kem_otbn_prompt_ver1_1/ibex/phase1_keygen/phase1_keygen_test.c
status.c:37] PASS!
```

### phase2_alice_encap_test

```
ottf_main.c:175] Running test_hybrid_kem_otbn_prompt_ver1_1/ibex/phase2_encap_decap/phase2_alice_encap.c
phase2_alice_encap.c:417] p256_ecdh OTBN instruction count: 0x0008dfe7
phase2_alice_encap.c:451] mlkem768_encap OTBN instruction count = 118987
phase2_alice_encap.c:523] hkdf_sha3_256 OTBN instruction count = 3374
phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,p256_ecdh_official_api,741264
phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,p256_unmask,444
phase2_alice_encap.c:78] HKEM_PROF_TEST,phase2_alice_encap,check_p256_ss,382
phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,mlkem_encap_load,260380
phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,mlkem_encap_write_inputs,22745
phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,mlkem_encap_execute_wait,171728
phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,mlkem_encap_read_outputs,18019
phase2_alice_encap.c:78] HKEM_PROF_TEST,phase2_alice_encap,check_mlkem_encap,5097
phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,wipe_after_mlkem_encap,1298
phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,hkdf_load,87112
phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,hkdf_write_params,1422
phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,hkdf_write_info_len,282
phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,hkdf_assemble_ikm,783
phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,hkdf_write_ikm,2737
phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,hkdf_execute_wait,5291
phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,hkdf_read_output,886
phase2_alice_encap.c:78] HKEM_PROF_TEST,phase2_alice_encap,check_hkdf_okm,390
phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,wipe_after_hkdf,1331
phase2_alice_encap.c:85] HKEM_PROF,phase2_alice_encap,protocol_total,1315722
phase2_alice_encap.c:86] HKEM_PROF_TEST,phase2_alice_encap,test_total,5869
phase2_alice_encap.c:88] HKEM_PROF_SCOPE,phase2_alice_encap,scope_total,1521685
phase2_alice_encap.c:90] HKEM_PROF_SCOPE,phase2_alice_encap,accounted_total,1321591
phase2_alice_encap.c:92] HKEM_PROF_SCOPE,phase2_alice_encap,unaccounted_total,200094
ottf_main.c:114] Finished test_hybrid_kem_otbn_prompt_ver1_1/ibex/phase2_encap_decap/phase2_alice_encap.c
status.c:37] PASS!
```

### phase2_bob_decap_test

```
ottf_main.c:175] Running test_hybrid_kem_otbn_prompt_ver1_1/ibex/phase2_encap_decap/phase2_bob_decap.c
phase2_bob_decap.c:463] mlkem768_decap OTBN instruction count = 145331
phase2_bob_decap.c:524] p256_ecdh OTBN instruction count: 0x0008dfe7
phase2_bob_decap.c:586] hkdf_sha3_256 OTBN instruction count = 3374
phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,mlkem_decap_load,355541
phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,mlkem_decap_write_inputs,64321
phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,mlkem_decap_execute_wait,217226
phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,mlkem_decap_read_outputs,985
phase2_bob_decap.c:76] HKEM_PROF_TEST,phase2_bob_decap,check_mlkem_decap,386
phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,wipe_after_mlkem_decap,1287
phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,p256_ecdh_official_api,742789
phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,p256_unmask,469
phase2_bob_decap.c:76] HKEM_PROF_TEST,phase2_bob_decap,check_p256_ss,382
phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,hkdf_load,86761
phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,hkdf_write_params,1593
phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,hkdf_write_info_len,275
phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,hkdf_assemble_ikm,816
phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,hkdf_write_ikm,2626
phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,hkdf_execute_wait,5337
phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,hkdf_read_output,889
phase2_bob_decap.c:76] HKEM_PROF_TEST,phase2_bob_decap,check_hkdf_okm,386
phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,wipe_after_hkdf,1259
phase2_bob_decap.c:83] HKEM_PROF,phase2_bob_decap,protocol_total,1482174
phase2_bob_decap.c:84] HKEM_PROF_TEST,phase2_bob_decap,test_total,1154
phase2_bob_decap.c:86] HKEM_PROF_SCOPE,phase2_bob_decap,scope_total,1678677
phase2_bob_decap.c:88] HKEM_PROF_SCOPE,phase2_bob_decap,accounted_total,1483328
phase2_bob_decap.c:90] HKEM_PROF_SCOPE,phase2_bob_decap,unaccounted_total,195349
ottf_main.c:114] Finished test_hybrid_kem_otbn_prompt_ver1_1/ibex/phase2_encap_decap/phase2_bob_decap.c
status.c:37] PASS!
```
