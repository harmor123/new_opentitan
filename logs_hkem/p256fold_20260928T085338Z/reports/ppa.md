# ppa（由 `p7_step11_results.py --build/--md` 与 `p7_step11_deliverables.py` 生成，**不手写** ✓）

## PPA（8 行）

| run_id | design | source_tag | area_fold | area_core | area_seq | area_comb | area_regs | fmax_mhz | wns_ns | power_w | energy_j | lib | corner | constraint |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| p7-L1-ppa | L1 | measured | 13484.604 | null | null | null | null | 74.00555041628122 | -5.5125 | 0.0123044 | 2.166e-09 | NangateOpenCellLibrary_typical.lib（sha256 8d540a4d…） | typical / 25 C / 1.10 V | clk 8.0 ns（125 MHz） |
| p7-A0-ppa | A0 | measured | null | 319430.888 | null | null | null | 68.39758146151952 | -6.6204 | 0.1744321 | 4.0185000000000007e-07 | NangateOpenCellLibrary_typical.lib（sha256 8d540a4d…） | typical / 25 C / 1.10 V | clk 8.0 ns（125 MHz） |
| p7-A1-ppa | A1 | measured | null | 318693.27 | null | null | null | null | null | 0.1748466 | 3.2224400000000006e-07 | NangateOpenCellLibrary_typical.lib（sha256 8d540a4d…） | typical / 25 C / 1.10 V | clk 8.0 ns（125 MHz） |
| p7-B0-ppa | B0 | measured | null | 305121.152 | null | null | null | 69.32457070759588 | -6.4249 | 0.16371010000000003 | null | NangateOpenCellLibrary_typical.lib（sha256 8d540a4d…） | typical / 25 C / 1.10 V | clk 8.0 ns（125 MHz） |
| p7-L1-ppa-altflow | L1 | measured_altflow | null | null | 5543.4 | 4988.8 | 5543.4 | null | null | null | null | NangateOpenCellLibrary_typical.lib | typical / 25 C / 1.10 V | **TIMING_RUN=0 的设计点**（与 TR1 的面积不可混列 ✗） |
| p7-A0-ppa-altflow | A0 | measured_altflow | null | null | 96516.6 | 175368.5 | 96516.6 | null | null | null | null | NangateOpenCellLibrary_typical.lib | typical / 25 C / 1.10 V | **TIMING_RUN=0 的设计点**（与 TR1 的面积不可混列 ✗） |
| p7-A1-ppa-altflow | A1 | measured_altflow | null | null | 96490.8 | 172262.7 | 96490.8 | null | null | null | null | NangateOpenCellLibrary_typical.lib | typical / 25 C / 1.10 V | **TIMING_RUN=0 的设计点**（与 TR1 的面积不可混列 ✗） |
| p7-B0-ppa-altflow | B0 | measured_altflow | null | null | 92364.2 | 165742.8 | 92364.2 | null | null | null | null | NangateOpenCellLibrary_typical.lib | typical / 25 C / 1.10 V | **TIMING_RUN=0 的设计点**（与 TR1 的面积不可混列 ✗） |

## 结果（§13.3 前 23 列）（19 行）

| run_id | design | workload | session | source_tag | clock_otbn_hz | calls | mul_retired | mul_stall | mul_fetch | mul_self_cycles | app_retired | app_span | host_execute_wait | protocol_total | kat_pass | elf_sha256 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| p7-B0-p256_keygen | B0 | p256_keygen | chip_sim_verilator | measured | 125000000 | null | null | null | null | null | 573922 | 767972 | null | null | True | f4d64e80ce771d342e28609243cba78dcc0aa3b3561294196df3048e2250ba15 |
| p7-B0-p256_ecdh | B0 | p256_ecdh | chip_sim_verilator | measured | 125000000 | null | null | null | null | null | 581607 | 796312 | null | null | True | f4d64e80ce771d342e28609243cba78dcc0aa3b3561294196df3048e2250ba15 |
| p7-B0-mlkem768_encap | B0 | mlkem768_encap | chip_sim_verilator | measured | 125000000 | null | null | null | null | null | 118979 | 171654 | null | null | True | f4d64e80ce771d342e28609243cba78dcc0aa3b3561294196df3048e2250ba15 |
| p7-B1-p256_keygen | B1 | p256_keygen | chip_sim_verilator | measured | 125000000 | null | null | null | null | null | 573922 | 767972 | null | null | True | f4d64e80ce771d342e28609243cba78dcc0aa3b3561294196df3048e2250ba15 |
| p7-B1-p256_ecdh | B1 | p256_ecdh | chip_sim_verilator | measured | 125000000 | null | null | null | null | null | 581607 | 796312 | null | null | True | f4d64e80ce771d342e28609243cba78dcc0aa3b3561294196df3048e2250ba15 |
| p7-B1-mlkem768_encap | B1 | mlkem768_encap | chip_sim_verilator | measured | 125000000 | null | null | null | null | null | 118979 | 171654 | null | null | True | f4d64e80ce771d342e28609243cba78dcc0aa3b3561294196df3048e2250ba15 |
| p7-A0-p256_keygen | A0 | p256_keygen | chip_sim_verilator | measured | 125000000 | null | null | null | null | null | 84679 | 499648 | null | null | True | null |
| p7-A0-p256_ecdh | A0 | p256_ecdh | chip_sim_verilator | measured | 125000000 | null | null | null | null | null | 91893 | 528693 | null | null | True | null |
| p7-A0-mlkem768_encap | A0 | mlkem768_encap | chip_sim_verilator | measured | 125000000 | null | null | null | null | null | 118979 | null | null | null | True | null |
| p7-A1-p256_keygen | A1 | p256_keygen | chip_sim_verilator | measured | 125000000 | null | null | null | null | null | 84679 | 442108 | null | null | True | null |
| p7-A1-p256_ecdh | A1 | p256_ecdh | chip_sim_verilator | measured | 125000000 | null | null | null | null | null | 91893 | 471061 | null | null | True | null |
| p7-A0-percall-ECDH | A0 | p256_ecdh | trace_analysis | measured | 125000000 | 9599 | 1 | 27 | 1 | 30 | null | null | null | null | null | null |
| p7-A1-percall-ECDH | A1 | p256_ecdh | trace_analysis | measured | 125000000 | 9599 | 1 | 21 | 1 | 24 | null | null | null | null | null | null |
| p7-A0-protocol-phase1_keygen | A0 | phase1_keygen | chip_sim_verilator | measured | 125000000 | null | null | null | null | null | null | null | 139546 | 889760 | null | null |
| p7-A0-protocol-phase2_alice_encap | A0 | phase2_alice_encap | chip_sim_verilator | measured | 125000000 | null | null | null | null | null | null | null | 171774 | 1053444 | null | null |
| p7-A0-protocol-phase2_bob_decap | A0 | phase2_bob_decap | chip_sim_verilator | measured | 125000000 | null | null | null | null | null | null | null | 217252 | 1209618 | null | null |
| p7-A1-protocol-phase1_keygen | A1 | phase1_keygen | chip_sim_verilator | measured | 125000000 | null | null | null | null | null | null | null | 139546 | 832200 | null | null |
| p7-A2-projected-p256_ecdh | A2 | p256_ecdh | model | projected | 125000000 | null | null | null | null | null | null | 296210 | null | null | null | null |
| p7-A2-projected-p256_keygen | A2 | p256_keygen | model | projected | 125000000 | null | null | null | null | null | null | 289003 | null | null | null | null |
