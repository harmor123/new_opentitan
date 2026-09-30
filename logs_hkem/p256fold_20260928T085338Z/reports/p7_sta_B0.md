# 时序报告（B0（基线 2d87e79bee，TIMING_RUN=1，同一 flow 与冻结条件））

> 数据源：`/tmp/b0/hw/ip/otbn/pre_syn/syn_out/otbn_core_2026_09_30_18_17_11/reports/timing/*.csv.rpt`（OpenSTA 经 yosys pre_syn 流；本工具直接读原始报告，绕开坏掉的 vendored 名字翻译器）。每条 = `起点,终点,slack(ns)`；**负 = 违例**。
>
> 归属列来自 `ys_translated_names`：2152 组 `_NNNNN_` ↔ 原名（按**相邻行**配对，其中 5 组走上一行回退）。

- **overall**：1000 条，最差 slack **-6.4249 ns**（`_300307_/Q` → `_260106_/D`）
- **reg2reg**：1000 条，最差 slack **-6.4249 ns**（`_300307_/Q` → `_260106_/D`）
- **reg2out**：1000 条，最差 slack **0.5224 ns**（`_300307_/Q` → `dmem_rmask_o[4]`）
- **in2reg**：1000 条，最差 slack **2.6798 ns**（`urnd_ctrl_enabled_i` → `_268796_/D`）
- **in2out**：360 条，最差 slack **0.1072 ns**（`wfi_enabled_i` → `dmem_rmask_o[4]`）

## 最差 15 条路径（overall 组）

| # | 起点 | 起点归属 | 终点 | 终点归属 | slack (ns) |
|---:|---|---|---|---|---:|
| 1 | `_300307_/Q` | `rf_bignum_predec` | `_260106_/D` | `u_otbn_rf_bignum.gen_rf_bignum_ff.u_otbn_rf_bignum_inner.rf` | **-6.4249** |
| 2 | `_300307_/Q` | `rf_bignum_predec` | `_262914_/D` | `u_otbn_rf_bignum.gen_rf_bignum_ff.u_otbn_rf_bignum_inner.rf` | **-6.4249** |
| 3 | `_300307_/Q` | `rf_bignum_predec` | `_265098_/D` | `u_otbn_rf_bignum.gen_rf_bignum_ff.u_otbn_rf_bignum_inner.rf` | **-6.4249** |
| 4 | `_300307_/Q` | `rf_bignum_predec` | `_273471_/D` | `u_otbn_rf_bignum.gen_rf_bignum_ff.u_otbn_rf_bignum_inner.rf` | **-6.4249** |
| 5 | `_300307_/Q` | `rf_bignum_predec` | `_275655_/D` | `u_otbn_rf_bignum.gen_rf_bignum_ff.u_otbn_rf_bignum_inner.rf` | **-6.4249** |
| 6 | `_300307_/Q` | `rf_bignum_predec` | `_260109_/D` | `u_otbn_rf_bignum.gen_rf_bignum_ff.u_otbn_rf_bignum_inner.rf` | **-6.4249** |
| 7 | `_300307_/Q` | `rf_bignum_predec` | `_260418_/D` | `u_otbn_rf_bignum.gen_rf_bignum_ff.u_otbn_rf_bignum_inner.rf` | **-6.4248** |
| 8 | `_300307_/Q` | `rf_bignum_predec` | `_260730_/D` | `u_otbn_rf_bignum.gen_rf_bignum_ff.u_otbn_rf_bignum_inner.rf` | **-6.4248** |
| 9 | `_300307_/Q` | `rf_bignum_predec` | `_261042_/D` | `u_otbn_rf_bignum.gen_rf_bignum_ff.u_otbn_rf_bignum_inner.rf` | **-6.4248** |
| 10 | `_300307_/Q` | `rf_bignum_predec` | `_261354_/D` | `u_otbn_rf_bignum.gen_rf_bignum_ff.u_otbn_rf_bignum_inner.rf` | **-6.4248** |
| 11 | `_300307_/Q` | `rf_bignum_predec` | `_261666_/D` | `u_otbn_rf_bignum.gen_rf_bignum_ff.u_otbn_rf_bignum_inner.rf` | **-6.4248** |
| 12 | `_300307_/Q` | `rf_bignum_predec` | `_261978_/D` | `u_otbn_rf_bignum.gen_rf_bignum_ff.u_otbn_rf_bignum_inner.rf` | **-6.4248** |
| 13 | `_300307_/Q` | `rf_bignum_predec` | `_262290_/D` | `u_otbn_rf_bignum.gen_rf_bignum_ff.u_otbn_rf_bignum_inner.rf` | **-6.4248** |
| 14 | `_300307_/Q` | `rf_bignum_predec` | `_262602_/D` | `u_otbn_rf_bignum.gen_rf_bignum_ff.u_otbn_rf_bignum_inner.rf` | **-6.4248** |
| 15 | `_300307_/Q` | `rf_bignum_predec` | `_263226_/D` | `u_otbn_rf_bignum.gen_rf_bignum_ff.u_otbn_rf_bignum_inner.rf` | **-6.4248** |

## 各组的 slack 范围

| 组 | 条数 | 最差 | 最好 |
|---|---:|---:|---:|
| overall | 1000 | -6.4249 | -5.5342 |
| reg2reg | 1000 | -6.4249 | -5.5342 |
| reg2out | 1000 | 0.5224 | 5.4728 |
| in2reg | 1000 | 2.6798 | 3.2012 |
| in2out | 360 | 0.1072 | 2.9536 |

## 前 1000 条路径的端点归属（top 12）

**起点归属**

| 归属名 | 条数 |
|---|---:|
| `rf_bignum_predec` | 1000 |

**终点归属**

| 归属名 | 条数 |
|---|---:|
| `u_otbn_rf_bignum.gen_rf_bignum_ff.u_otbn_rf_bignum_inner.rf` | 941 |
| `ispr_acc_intg` | 29 |
| `u_otbn_mac_bignum.c_intg_q` | 13 |
| `gen_mai.u_otbn_mai.ispr_mai_in0_s0_q` | 9 |
| `gen_mai.u_otbn_mai.out_cnt_load_val_q` | 3 |
| `gen_mai.u_otbn_mai.ma_in_valid_q` | 1 |
| `u_otbn_controller.u_otbn_loop_controller.g_loop_counters[5].u_loop_count.err_o` | 1 |
| `u_otbn_controller.lsu_addr_saved_q` | 1 |
| `u_otbn_controller.u_otbn_loop_controller.g_loop_counters[3].u_loop_count.err_o` | 1 |
| `u_otbn_controller.u_otbn_loop_controller.g_loop_counters[7].u_loop_count.err_o` | 1 |

