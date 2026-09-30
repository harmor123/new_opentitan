# 时序报告（A0（serial 常量化，TIMING_RUN=1，ABC -D 4000））

> 数据源：`/home/chy/new_pqc/opentitan/hw/ip/otbn/pre_syn/syn_out/otbn_core_2026_09_30_16_59_16/reports/timing/*.csv.rpt`（OpenSTA 经 yosys pre_syn 流；本工具直接读原始报告，绕开坏掉的 vendored 名字翻译器）。每条 = `起点,终点,slack(ns)`；**负 = 违例**。
>
> 归属列来自 `ys_translated_names`：2129 组 `_NNNNN_` ↔ 原名（按**相邻行**配对，其中 5 组走上一行回退）。

- **overall**：1000 条，最差 slack **-6.6204 ns**（`_317066_/Q` → `_278426_/D`）
- **reg2reg**：1000 条，最差 slack **-6.6204 ns**（`_317066_/Q` → `_278426_/D`）
- **reg2out**：1000 条，最差 slack **0.3689 ns**（`_317066_/Q` → `dmem_rmask_o[4]`）
- **in2reg**：1000 条，最差 slack **2.2532 ns**（`urnd_ctrl_enabled_i` → `_286985_/D`）
- **in2out**：360 条，最差 slack **0.1865 ns**（`wfi_enabled_i` → `dmem_rmask_o[4]`）

## 最差 15 条路径（overall 组）

| # | 起点 | 起点归属 | 终点 | 终点归属 | slack (ns) |
|---:|---|---|---|---|---:|
| 1 | `_317066_/Q` | `rf_bignum_predec` | `_278426_/D` | `u_otbn_rf_bignum.gen_rf_bignum_ff.u_otbn_rf_bignum_inner.rf` | **-6.6204** |
| 2 | `_317066_/Q` | `rf_bignum_predec` | `_279362_/D` | `u_otbn_rf_bignum.gen_rf_bignum_ff.u_otbn_rf_bignum_inner.rf` | **-6.6204** |
| 3 | `_317066_/Q` | `rf_bignum_predec` | `_281858_/D` | `u_otbn_rf_bignum.gen_rf_bignum_ff.u_otbn_rf_bignum_inner.rf` | **-6.6204** |
| 4 | `_317066_/Q` | `rf_bignum_predec` | `_292574_/D` | `u_otbn_rf_bignum.gen_rf_bignum_ff.u_otbn_rf_bignum_inner.rf` | **-6.6204** |
| 5 | `_317066_/Q` | `rf_bignum_predec` | `_276242_/D` | `u_otbn_rf_bignum.gen_rf_bignum_ff.u_otbn_rf_bignum_inner.rf` | **-6.6204** |
| 6 | `_317066_/Q` | `rf_bignum_predec` | `_276554_/D` | `u_otbn_rf_bignum.gen_rf_bignum_ff.u_otbn_rf_bignum_inner.rf` | **-6.6204** |
| 7 | `_317066_/Q` | `rf_bignum_predec` | `_276866_/D` | `u_otbn_rf_bignum.gen_rf_bignum_ff.u_otbn_rf_bignum_inner.rf` | **-6.6204** |
| 8 | `_317066_/Q` | `rf_bignum_predec` | `_277178_/D` | `u_otbn_rf_bignum.gen_rf_bignum_ff.u_otbn_rf_bignum_inner.rf` | **-6.6204** |
| 9 | `_317066_/Q` | `rf_bignum_predec` | `_277490_/D` | `u_otbn_rf_bignum.gen_rf_bignum_ff.u_otbn_rf_bignum_inner.rf` | **-6.6204** |
| 10 | `_317066_/Q` | `rf_bignum_predec` | `_277802_/D` | `u_otbn_rf_bignum.gen_rf_bignum_ff.u_otbn_rf_bignum_inner.rf` | **-6.6204** |
| 11 | `_317066_/Q` | `rf_bignum_predec` | `_278114_/D` | `u_otbn_rf_bignum.gen_rf_bignum_ff.u_otbn_rf_bignum_inner.rf` | **-6.6204** |
| 12 | `_317066_/Q` | `rf_bignum_predec` | `_278738_/D` | `u_otbn_rf_bignum.gen_rf_bignum_ff.u_otbn_rf_bignum_inner.rf` | **-6.6204** |
| 13 | `_317066_/Q` | `rf_bignum_predec` | `_279050_/D` | `u_otbn_rf_bignum.gen_rf_bignum_ff.u_otbn_rf_bignum_inner.rf` | **-6.6204** |
| 14 | `_317066_/Q` | `rf_bignum_predec` | `_279674_/D` | `u_otbn_rf_bignum.gen_rf_bignum_ff.u_otbn_rf_bignum_inner.rf` | **-6.6204** |
| 15 | `_317066_/Q` | `rf_bignum_predec` | `_280298_/D` | `u_otbn_rf_bignum.gen_rf_bignum_ff.u_otbn_rf_bignum_inner.rf` | **-6.6204** |

## 各组的 slack 范围

| 组 | 条数 | 最差 | 最好 |
|---|---:|---:|---:|
| overall | 1000 | -6.6204 | -5.9603 |
| reg2reg | 1000 | -6.6204 | -5.9603 |
| reg2out | 1000 | 0.3689 | 5.4764 |
| in2reg | 1000 | 2.2532 | 3.0528 |
| in2out | 360 | 0.1865 | 2.9536 |

## 前 1000 条路径的端点归属（top 12）

**起点归属**

| 归属名 | 条数 |
|---|---:|
| `rf_bignum_predec` | 740 |
| `u_otbn_controller.u_otbn_loop_controller.loop_info_stack.cnt_err` | 260 |

**终点归属**

| 归属名 | 条数 |
|---|---:|
| `u_otbn_rf_bignum.gen_rf_bignum_ff.u_otbn_rf_bignum_inner.rf` | 693 |
| `u_otbn_mac_bignum.p256_fold_f` | 248 |
| `rnd_data` | 13 |
| `u_otbn_mac_bignum.c_intg_q` | 13 |
| `ispr_acc_intg` | 12 |
| `u_otbn_mac_bignum.u_otbn_p256_fold.acc130_o` | 12 |
| `u_otbn_mac_bignum.u_otbn_p256_fold.mode_q` | 1 |
| `u_otbn_controller.u_otbn_loop_controller.g_loop_counters[5].u_loop_count.err_o` | 1 |
| `u_otbn_controller.lsu_addr_saved_q` | 1 |
| `u_otbn_kmac_if.no_more_msg_allowed_q` | 1 |
| `u_otbn_controller.u_otbn_loop_controller.g_loop_counters[3].u_loop_count.err_o` | 1 |
| `u_otbn_controller.u_otbn_loop_controller.g_loop_counters[7].u_loop_count.err_o` | 1 |

