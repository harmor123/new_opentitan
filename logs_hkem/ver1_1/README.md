(.venv) chy@211:~/new_pqc/opentitan$ bazel build \
  //test_hybrid_kem_otbn_prompt_ver1_1:test_mlkem_keypair_only_sim_verilator \
  //test_hybrid_kem_otbn_prompt_ver1_1:test_mlkem_encap_only_sim_verilator \
  //test_hybrid_kem_otbn_prompt_ver1_1:test_mlkem_decap_only_sim_verilator

for t in test_mlkem_keypair_only test_mlkem_encap_only test_mlkem_decap_only; do
  echo "===== $t ====="
  rf="bazel-bin/test_hybrid_kem_otbn_prompt_ver1_1/${t}_sim_verilator.bash.runfiles/_main"
  ( cd "$rf" && ./test_hybrid_kem_otbn_prompt_ver1_1/${t}_sim_verilator.bash ) \
      > logs_hkem/ver1_1/${t}.sim.log 2>&1
  cp "$rf/uart0.log" logs_hkem/ver1_1/${t}.uart0.log
  grep -a "cycles.*insn_cnt\|PASS\|FAIL" logs_hkem/ver1_1/${t}.uart0.log
done
INFO: Analyzed 3 targets (0 packages loaded, 10 targets configured).
INFO: Found 3 targets...
INFO: Elapsed time: 0.912s, Critical Path: 0.16s
INFO: 1 process: 42 action cache hit, 1 internal.
INFO: Build completed successfully, 1 total action
===== test_mlkem_keypair_only =====
I00006 test_mlkem_keypair_only.c:50] mlkem768_keypair cycles: 139461, OTBN insn_cnt: 97301
I00008 status.c:37] PASS!
===== test_mlkem_encap_only =====
I00006 test_mlkem_encap_only.c:125] mlkem768_encap cycles: 171721, OTBN insn_cnt: 118987
I00008 status.c:37] PASS!
===== test_mlkem_decap_only =====
I00006 test_mlkem_decap_only.c:267] mlkem768_decap cycles: 217160, OTBN insn_cnt: 145331
I00008 status.c:37] PASS!

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