(.venv) chy@211:~/new_pqc/opentitan$   mkdir -p logs_hkem
  for t in test_mlkem_keypair_only test_mlkem_encap_only test_mlkem_decap_only \
           test_p256_only test_hkdf_only phase1_keygen_test \
           phase2_alice_encap_test phase2_bob_decap_test; do
    echo "===== 运行 $t ====="
    rf="bazel-bin/test_hybrid_kem_otbn_prompt_ver0_2/${t}_sim_verilator.bash.runfiles/_main"
    ( cd "$rf" && ./test_hybrid_kem_otbn_prompt_ver0_2/${t}_sim_verilator.bash ) > logs_hkem/ver0_2_2/${t}.sim.log 2>&1
    cp "$rf/uart0.log" logs_hkem/${t}.uart0.log
    echo "----- $t 关键行 -----"
    grep -E "cycles|insn_cnt|instruction|OTBN|HKEM|PASS|FAIL" logs_hkem/${t}.uart0.log | tail -60
  done
===== 运行 test_mlkem_keypair_only =====
----- test_mlkem_keypair_only 关键行 -----
grep: logs_hkem/test_mlkem_keypair_only.uart0.log: binary file matches
===== 运行 test_mlkem_encap_only =====
----- test_mlkem_encap_only 关键行 -----
grep: logs_hkem/test_mlkem_encap_only.uart0.log: binary file matches
===== 运行 test_mlkem_decap_only =====
----- test_mlkem_decap_only 关键行 -----
grep: logs_hkem/test_mlkem_decap_only.uart0.log: binary file matches
===== 运行 test_p256_only =====
----- test_p256_only 关键行 -----
grep: logs_hkem/test_p256_only.uart0.log: binary file matches
===== 运行 test_hkdf_only =====
----- test_hkdf_only 关键行 -----
grep: logs_hkem/test_hkdf_only.uart0.log: binary file matches
===== 运行 phase1_keygen_test =====
----- phase1_keygen_test 关键行 -----
grep: logs_hkem/phase1_keygen_test.uart0.log: binary file matches
===== 运行 phase2_alice_encap_test =====
----- phase2_alice_encap_test 关键行 -----
grep: logs_hkem/phase2_alice_encap_test.uart0.log: binary file matches
===== 运行 phase2_bob_decap_test =====
----- phase2_bob_decap_test 关键行 -----
grep: logs_hkem/phase2_bob_decap_test.uart0.log: binary file matches
(.venv) chy@211:~/new_pqc/opentitan$   for t in test_mlkem_keypair_only test_mlkem_encap_only test_mlkem_decap_only \
           test_p256_only test_hkdf_only phase1_keygen_test \
           phase2_alice_encap_test phase2_bob_decap_test; do
    echo "===================== $t ====================="
    grep -aE "cycles|insn_cnt|instruction|OTBN|HKEM|PASS|FAIL" logs_hkem/${t}.uart0.log | tail -60
  done
===================== test_mlkem_keypair_only =====================
I00006 test_mlkem_keypair_only.c:50] mlkem768_keypair cycles: 176505, OTBN insn_cnt: 157624
I00008 status.c:37] PASS!
===================== test_mlkem_encap_only =====================
I00006 test_mlkem_encap_only.c:125] mlkem768_encap cycles: 216186, OTBN insn_cnt: 196446
I00008 status.c:37] PASS!
===================== test_mlkem_decap_only =====================
I00006 test_mlkem_decap_only.c:267] mlkem768_decap cycles: 277351, OTBN insn_cnt: 255383
I00008 status.c:37] PASS!
===================== test_p256_only =====================
I00004 test_p256_only.c:110] Keygen A OTBN instruction count: 0x0008c1e2, cycles: 767961
I00006 test_p256_only.c:117] Keygen B OTBN instruction count: 0x0008c1e2, cycles: 766868
I00008 test_p256_only.c:150] ECDH A OTBN instruction count: 0x0008dfe7, cycles: 796457
I00010 test_p256_only.c:158] ECDH B OTBN instruction count: 0x0008dfe7, cycles: 796241
I00013 status.c:37] PASS!
===================== test_hkdf_only =====================
I00003 test_hkdf_only.c:227] Loading HKDF-HMAC-SHA3-256 OTBN app...
I00005 test_hkdf_only.c:417] HKDF cycles = 5249, total OTBN instructions = 3374
I00008 test_hkdf_only.c:504] HKDF-HMAC-SHA3-256 standalone correctness PASS.
===================== phase1_keygen_test =====================
I00010 phase1_keygen_test.c:76] HKEM_PROF,phase1_keygen,p256_keygen_total,716352
I00011 phase1_keygen_test.c:76] HKEM_PROF,phase1_keygen,mlkem_keypair_load,291475
I00012 phase1_keygen_test.c:76] HKEM_PROF,phase1_keygen,mlkem_keypair_write_inputs,1566
I00013 phase1_keygen_test.c:76] HKEM_PROF,phase1_keygen,mlkem_keypair_execute_wait,176545
I00014 phase1_keygen_test.c:76] HKEM_PROF,phase1_keygen,mlkem_keypair_read_outputs,55384
I00015 phase1_keygen_test.c:73] HKEM_PROF_TEST,phase1_keygen,check_mlkem_keypair,15604
I00016 phase1_keygen_test.c:76] HKEM_PROF,phase1_keygen,wipe_after_mlkem_keypair,1291
I00017 phase1_keygen_test.c:80] HKEM_PROF,phase1_keygen,protocol_total,1242613
I00018 phase1_keygen_test.c:81] HKEM_PROF_TEST,phase1_keygen,test_total,15604
I00019 phase1_keygen_test.c:83] HKEM_PROF_SCOPE,phase1_keygen,scope_total,1615664
I00020 phase1_keygen_test.c:85] HKEM_PROF_SCOPE,phase1_keygen,accounted_total,1258217
I00021 phase1_keygen_test.c:87] HKEM_PROF_SCOPE,phase1_keygen,unaccounted_total,357447
I00025 status.c:37] PASS!
===================== phase2_alice_encap_test =====================
I00003 phase2_alice_encap.c:417] p256_ecdh OTBN instruction count: 0x0008dfe7
I00004 phase2_alice_encap.c:451] mlkem768_encap OTBN instruction count = 196446
I00005 phase2_alice_encap.c:523] hkdf_sha3_256 OTBN instruction count = 3374
I00006 phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,p256_ecdh_official_api,741523
I00007 phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,p256_unmask,420
I00008 phase2_alice_encap.c:78] HKEM_PROF_TEST,phase2_alice_encap,check_p256_ss,391
I00009 phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,mlkem_encap_load,357295
I00010 phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,mlkem_encap_write_inputs,22418
I00011 phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,mlkem_encap_execute_wait,216238
I00012 phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,mlkem_encap_read_outputs,17314
I00013 phase2_alice_encap.c:78] HKEM_PROF_TEST,phase2_alice_encap,check_mlkem_encap,5032
I00014 phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,wipe_after_mlkem_encap,1334
I00015 phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,hkdf_load,85682
I00016 phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,hkdf_write_params,1483
I00017 phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,hkdf_write_info_len,315
I00018 phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,hkdf_assemble_ikm,789
I00019 phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,hkdf_write_ikm,2716
I00020 phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,hkdf_execute_wait,5331
I00021 phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,hkdf_read_output,864
I00022 phase2_alice_encap.c:78] HKEM_PROF_TEST,phase2_alice_encap,check_hkdf_okm,381
I00023 phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,wipe_after_hkdf,1264
I00024 phase2_alice_encap.c:85] HKEM_PROF,phase2_alice_encap,protocol_total,1454986
I00025 phase2_alice_encap.c:86] HKEM_PROF_TEST,phase2_alice_encap,test_total,5804
I00026 phase2_alice_encap.c:88] HKEM_PROF_SCOPE,phase2_alice_encap,scope_total,1661140
I00027 phase2_alice_encap.c:90] HKEM_PROF_SCOPE,phase2_alice_encap,accounted_total,1460790
I00028 phase2_alice_encap.c:92] HKEM_PROF_SCOPE,phase2_alice_encap,unaccounted_total,200350
I00031 status.c:37] PASS!
===================== phase2_bob_decap_test =====================
I00003 phase2_bob_decap.c:463] mlkem768_decap OTBN instruction count = 255383
I00004 phase2_bob_decap.c:524] p256_ecdh OTBN instruction count: 0x0008dfe7
I00005 phase2_bob_decap.c:586] hkdf_sha3_256 OTBN instruction count = 3374
I00006 phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,mlkem_decap_load,398467
I00007 phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,mlkem_decap_write_inputs,64994
I00008 phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,mlkem_decap_execute_wait,277418
I00009 phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,mlkem_decap_read_outputs,940
I00010 phase2_bob_decap.c:76] HKEM_PROF_TEST,phase2_bob_decap,check_mlkem_decap,375
I00011 phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,wipe_after_mlkem_decap,1311
I00012 phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,p256_ecdh_official_api,742781
I00013 phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,p256_unmask,448
I00014 phase2_bob_decap.c:76] HKEM_PROF_TEST,phase2_bob_decap,check_p256_ss,350
I00015 phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,hkdf_load,87652
I00016 phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,hkdf_write_params,1557
I00017 phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,hkdf_write_info_len,282
I00018 phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,hkdf_assemble_ikm,758
I00019 phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,hkdf_write_ikm,2771
I00020 phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,hkdf_execute_wait,5312
I00021 phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,hkdf_read_output,861
I00022 phase2_bob_decap.c:76] HKEM_PROF_TEST,phase2_bob_decap,check_hkdf_okm,353
I00023 phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,wipe_after_hkdf,1319
I00024 phase2_bob_decap.c:83] HKEM_PROF,phase2_bob_decap,protocol_total,1586871
I00025 phase2_bob_decap.c:84] HKEM_PROF_TEST,phase2_bob_decap,test_total,1078
I00026 phase2_bob_decap.c:86] HKEM_PROF_SCOPE,phase2_bob_decap,scope_total,1783708
I00027 phase2_bob_decap.c:88] HKEM_PROF_SCOPE,phase2_bob_decap,accounted_total,1587949
I00028 phase2_bob_decap.c:90] HKEM_PROF_SCOPE,phase2_bob_decap,unaccounted_total,195759
I00033 status.c:37] PASS!