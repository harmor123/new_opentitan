(.venv) chy@211:~/new_pqc/opentitan$ bazel build \
  //test_hybrid_kem_otbn_prompt_ver1_1:test_hkdf_only_sim_verilator \
  //test_hybrid_kem_otbn_prompt_ver1_1:test_p256_only_sim_verilator \
  //test_hybrid_kem_otbn_prompt_ver1_1:phase1_keygen_test_sim_verilator \
  //test_hybrid_kem_otbn_prompt_ver1_1:phase2_alice_encap_test_sim_verilator \
  //test_hybrid_kem_otbn_prompt_ver1_1:phase2_bob_decap_test_sim_verilator

for t in test_hkdf_only test_p256_only phase1_keygen_test phase2_alice_encap_test phase2_bob_decap_test; do
  echo "===================== $t ====================="
  rf="bazel-bin/test_hybrid_kem_otbn_prompt_ver1_1/${t}_sim_verilator.bash.runfiles/_main"
  ( cd "$rf" && ./test_hybrid_kem_otbn_prompt_ver1_1/${t}_sim_verilator.bash ) \
      > logs_hkem/ver1_1/${t}.sim.log 2>&1
  cp "$rf/uart0.log" logs_hkem/ver1_1/${t}.uart0.log
  grep -aE "cycles|insn_cnt|OTBN|HKEM|PASS|FAIL" logs_hkem/ver1_1/${t}.uart0.log | tail -60
done
DEBUG: /home/chy/new_pqc/opentitan/rules/autogen.bzl:603:14: NOTE: stamping is disabled, the build_info section will use a fixed version string
DEBUG: /home/chy/new_pqc/opentitan/rules/autogen.bzl:536:14: NOTE: stamping is disabled, the build_info section will use a fixed version string
INFO: Analyzed 5 targets (690 packages loaded, 32500 targets configured).
INFO: From Action test_hybrid_kem_otbn_prompt_ver1_1/test_hkdf_only_sim_verilator.dis:
external/+lowrisc_rv32imcb_toolchain+lowrisc_rv32imcb_toolchain/bin/riscv32-unknown-elf-objdump: Warning: .note.gnu.build-id section is corrupt/empty
INFO: From Action test_hybrid_kem_otbn_prompt_ver1_1/test_p256_only_sim_verilator.dis:
external/+lowrisc_rv32imcb_toolchain+lowrisc_rv32imcb_toolchain/bin/riscv32-unknown-elf-objdump: Warning: .note.gnu.build-id section is corrupt/empty
INFO: From Action test_hybrid_kem_otbn_prompt_ver1_1/phase1_keygen_test_sim_verilator.dis:
external/+lowrisc_rv32imcb_toolchain+lowrisc_rv32imcb_toolchain/bin/riscv32-unknown-elf-objdump: Warning: .note.gnu.build-id section is corrupt/empty
INFO: From Action test_hybrid_kem_otbn_prompt_ver1_1/phase2_alice_encap_test_sim_verilator.dis:
external/+lowrisc_rv32imcb_toolchain+lowrisc_rv32imcb_toolchain/bin/riscv32-unknown-elf-objdump: Warning: .note.gnu.build-id section is corrupt/empty
INFO: From Action test_hybrid_kem_otbn_prompt_ver1_1/phase2_bob_decap_test_sim_verilator.dis:
external/+lowrisc_rv32imcb_toolchain+lowrisc_rv32imcb_toolchain/bin/riscv32-unknown-elf-objdump: Warning: .note.gnu.build-id section is corrupt/empty
INFO: Found 5 targets...
INFO: Elapsed time: 7.163s, Critical Path: 3.32s
INFO: 68 processes: 2068 action cache hit, 21 internal, 47 linux-sandbox.
INFO: Build completed successfully, 68 total actions
===================== test_hkdf_only =====================
I00003 test_hkdf_only.c:227] Loading HKDF-HMAC-SHA3-256 OTBN app...
I00005 test_hkdf_only.c:417] HKDF cycles = 5283, total OTBN instructions = 3374
I00008 test_hkdf_only.c:504] HKDF-HMAC-SHA3-256 standalone correctness PASS.
===================== test_p256_only =====================
I00004 test_p256_only.c:110] Keygen A OTBN instruction count: 0x0008c1e2, cycles: 767972
I00006 test_p256_only.c:117] Keygen B OTBN instruction count: 0x0008c1e2, cycles: 766738
I00008 test_p256_only.c:150] ECDH A OTBN instruction count: 0x0008dfe7, cycles: 796312
I00010 test_p256_only.c:158] ECDH B OTBN instruction count: 0x0008dfe7, cycles: 795942
I00013 status.c:37] PASS!
===================== phase1_keygen_test =====================
I00010 phase1_keygen_test.c:76] HKEM_PROF,phase1_keygen,p256_keygen_total,716380
I00011 phase1_keygen_test.c:76] HKEM_PROF,phase1_keygen,mlkem_keypair_load,245809
I00012 phase1_keygen_test.c:76] HKEM_PROF,phase1_keygen,mlkem_keypair_write_inputs,1537
I00013 phase1_keygen_test.c:76] HKEM_PROF,phase1_keygen,mlkem_keypair_execute_wait,139529
I00014 phase1_keygen_test.c:76] HKEM_PROF,phase1_keygen,mlkem_keypair_read_outputs,55010
I00015 phase1_keygen_test.c:73] HKEM_PROF_TEST,phase1_keygen,check_mlkem_keypair,15561
I00016 phase1_keygen_test.c:76] HKEM_PROF,phase1_keygen,wipe_after_mlkem_keypair,1224
I00017 phase1_keygen_test.c:80] HKEM_PROF,phase1_keygen,protocol_total,1159489
I00018 phase1_keygen_test.c:81] HKEM_PROF_TEST,phase1_keygen,test_total,15561
I00019 phase1_keygen_test.c:83] HKEM_PROF_SCOPE,phase1_keygen,scope_total,1532984
I00020 phase1_keygen_test.c:85] HKEM_PROF_SCOPE,phase1_keygen,accounted_total,1175050
I00021 phase1_keygen_test.c:87] HKEM_PROF_SCOPE,phase1_keygen,unaccounted_total,357934
I00025 status.c:37] PASS!
===================== phase2_alice_encap_test =====================
I00003 phase2_alice_encap.c:417] p256_ecdh OTBN instruction count: 0x0008dfe7
I00004 phase2_alice_encap.c:451] mlkem768_encap OTBN instruction count = 118987
I00005 phase2_alice_encap.c:523] hkdf_sha3_256 OTBN instruction count = 3374
I00006 phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,p256_ecdh_official_api,741412
I00007 phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,p256_unmask,442
I00008 phase2_alice_encap.c:78] HKEM_PROF_TEST,phase2_alice_encap,check_p256_ss,414
I00009 phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,mlkem_encap_load,256788
I00010 phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,mlkem_encap_write_inputs,22465
I00011 phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,mlkem_encap_execute_wait,171767
I00012 phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,mlkem_encap_read_outputs,17383
I00013 phase2_alice_encap.c:78] HKEM_PROF_TEST,phase2_alice_encap,check_mlkem_encap,5027
I00014 phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,wipe_after_mlkem_encap,1300
I00015 phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,hkdf_load,85451
I00016 phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,hkdf_write_params,1336
I00017 phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,hkdf_write_info_len,271
I00018 phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,hkdf_assemble_ikm,810
I00019 phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,hkdf_write_ikm,2722
I00020 phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,hkdf_execute_wait,5272
I00021 phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,hkdf_read_output,899
I00022 phase2_alice_encap.c:78] HKEM_PROF_TEST,phase2_alice_encap,check_hkdf_okm,420
I00023 phase2_alice_encap.c:81] HKEM_PROF,phase2_alice_encap,wipe_after_hkdf,1338
I00024 phase2_alice_encap.c:85] HKEM_PROF,phase2_alice_encap,protocol_total,1309656
I00025 phase2_alice_encap.c:86] HKEM_PROF_TEST,phase2_alice_encap,test_total,5861
I00026 phase2_alice_encap.c:88] HKEM_PROF_SCOPE,phase2_alice_encap,scope_total,1515515
I00027 phase2_alice_encap.c:90] HKEM_PROF_SCOPE,phase2_alice_encap,accounted_total,1315517
I00028 phase2_alice_encap.c:92] HKEM_PROF_SCOPE,phase2_alice_encap,unaccounted_total,199998
I00031 status.c:37] PASS!
===================== phase2_bob_decap_test =====================
I00003 phase2_bob_decap.c:463] mlkem768_decap OTBN instruction count = 145331
I00004 phase2_bob_decap.c:524] p256_ecdh OTBN instruction count: 0x0008dfe7
I00005 phase2_bob_decap.c:586] hkdf_sha3_256 OTBN instruction count = 3374
I00006 phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,mlkem_decap_load,355868
I00007 phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,mlkem_decap_write_inputs,64552
I00008 phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,mlkem_decap_execute_wait,217219
I00009 phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,mlkem_decap_read_outputs,999
I00010 phase2_bob_decap.c:76] HKEM_PROF_TEST,phase2_bob_decap,check_mlkem_decap,417
I00011 phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,wipe_after_mlkem_decap,1256
I00012 phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,p256_ecdh_official_api,742924
I00013 phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,p256_unmask,465
I00014 phase2_bob_decap.c:76] HKEM_PROF_TEST,phase2_bob_decap,check_p256_ss,381
I00015 phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,hkdf_load,87055
I00016 phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,hkdf_write_params,1608
I00017 phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,hkdf_write_info_len,348
I00018 phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,hkdf_assemble_ikm,800
I00019 phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,hkdf_write_ikm,2780
I00020 phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,hkdf_execute_wait,5263
I00021 phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,hkdf_read_output,918
I00022 phase2_bob_decap.c:76] HKEM_PROF_TEST,phase2_bob_decap,check_hkdf_okm,387
I00023 phase2_bob_decap.c:79] HKEM_PROF,phase2_bob_decap,wipe_after_hkdf,1250
I00024 phase2_bob_decap.c:83] HKEM_PROF,phase2_bob_decap,protocol_total,1483305
I00025 phase2_bob_decap.c:84] HKEM_PROF_TEST,phase2_bob_decap,test_total,1185
I00026 phase2_bob_decap.c:86] HKEM_PROF_SCOPE,phase2_bob_decap,scope_total,1680413
I00027 phase2_bob_decap.c:88] HKEM_PROF_SCOPE,phase2_bob_decap,accounted_total,1484490
I00028 phase2_bob_decap.c:90] HKEM_PROF_SCOPE,phase2_bob_decap,unaccounted_total,195923
I00033 status.c:37] PASS!

ver0_2 vs ver1_1 对比表

┌─────────┬─────────────┬─────────────┬────────┬─────────────┬─────────────┬────────┬─────────────┐
│  模块   │ ver0_2 周期 │ ver1_1 周期 │  变化  │ ver0_2 指令 │ ver1_1 指令 │  变化  │  CPI 变化   │
├─────────┼─────────────┼─────────────┼────────┼─────────────┼─────────────┼────────┼─────────────┤
│ keypair │     176,505 │     139,461 │ −21.0% │     157,624 │      97,301 │ −38.3% │ 1.12 → 1.43 │
├─────────┼─────────────┼─────────────┼────────┼─────────────┼─────────────┼────────┼─────────────┤
│ encap   │     216,186 │     171,721 │ −20.6% │     196,446 │     118,987 │ −39.4% │ 1.10 → 1.44 │
├─────────┼─────────────┼─────────────┼────────┼─────────────┼─────────────┼────────┼─────────────┤
│ decap   │     277,351 │     217,160 │ −21.7% │     255,383 │     145,331 │ −43.1% │ 1.09 → 1.49 │
└─────────┴─────────────┴─────────────┴────────┴─────────────┴─────────────┴────────┴─────────────┘