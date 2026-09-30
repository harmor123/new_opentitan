# 时序报告（A0 + Step 5 预译码（TIMING_RUN=1，ABC -D 4000））

> 数据源：`/home/chy/new_pqc/opentitan/hw/ip/otbn/pre_syn/syn_out/otbn_core_2026_09_30_18_53_19/reports/timing/*.csv.rpt`（OpenSTA 经 yosys pre_syn 流；本工具直接读原始报告，绕开坏掉的 vendored 名字翻译器）。每条 = `起点,终点,slack(ns)`；**负 = 违例**。
>
> 归属列来自 `ys_translated_names`：2153 组 `_NNNNN_` ↔ 原名（按**相邻行**配对，其中 4 组走上一行回退）。

- **overall**：1000 条，最差 slack **-7.0239 ns**（`_321079_/Q` → `_282595_/D`）
- **reg2reg**：1000 条，最差 slack **-7.0239 ns**（`_321079_/Q` → `_282595_/D`）
- **reg2out**：1000 条，最差 slack **0.4908 ns**（`_321079_/Q` → `dmem_rmask_o[4]`）
- **in2reg**：1000 条，最差 slack **2.4650 ns**（`urnd_ctrl_enabled_i` → `_291500_/D`）
- **in2out**：360 条，最差 slack **0.0884 ns**（`wfi_enabled_i` → `dmem_rmask_o[4]`）

## 最差 12 条路径（overall 组）

| # | 起点 | 起点归属 | 终点 | 终点归属 | slack (ns) |
|---:|---|---|---|---|---:|
| 1 | `_321079_/Q` | `rf_bignum_predec` | `_282595_/D` | `u_otbn_rf_bignum.gen_rf_bignum_ff.u_otbn_rf_bignum_inner.rf` | **-7.0239** |
| 2 | `_321079_/Q` | `rf_bignum_predec` | `_295191_/D` | `u_otbn_rf_bignum.gen_rf_bignum_ff.u_otbn_rf_bignum_inner.rf` | **-7.0239** |
| 3 | `_321079_/Q` | `rf_bignum_predec` | `_283847_/D` | `u_otbn_rf_bignum.gen_rf_bignum_ff.u_otbn_rf_bignum_inner.rf` | **-7.0238** |
| 4 | `_321079_/Q` | `rf_bignum_predec` | `_297063_/D` | `u_otbn_rf_bignum.gen_rf_bignum_ff.u_otbn_rf_bignum_inner.rf` | **-7.0238** |
| 5 | `_321079_/Q` | `rf_bignum_predec` | `_280099_/D` | `u_otbn_rf_bignum.gen_rf_bignum_ff.u_otbn_rf_bignum_inner.rf` | **-7.0238** |
| 6 | `_321079_/Q` | `rf_bignum_predec` | `_280411_/D` | `u_otbn_rf_bignum.gen_rf_bignum_ff.u_otbn_rf_bignum_inner.rf` | **-7.0238** |
| 7 | `_321079_/Q` | `rf_bignum_predec` | `_280723_/D` | `u_otbn_rf_bignum.gen_rf_bignum_ff.u_otbn_rf_bignum_inner.rf` | **-7.0238** |
| 8 | `_321079_/Q` | `rf_bignum_predec` | `_281035_/D` | `u_otbn_rf_bignum.gen_rf_bignum_ff.u_otbn_rf_bignum_inner.rf` | **-7.0238** |
| 9 | `_321079_/Q` | `rf_bignum_predec` | `_281347_/D` | `u_otbn_rf_bignum.gen_rf_bignum_ff.u_otbn_rf_bignum_inner.rf` | **-7.0238** |
| 10 | `_321079_/Q` | `rf_bignum_predec` | `_281659_/D` | `u_otbn_rf_bignum.gen_rf_bignum_ff.u_otbn_rf_bignum_inner.rf` | **-7.0238** |
| 11 | `_321079_/Q` | `rf_bignum_predec` | `_281971_/D` | `u_otbn_rf_bignum.gen_rf_bignum_ff.u_otbn_rf_bignum_inner.rf` | **-7.0238** |
| 12 | `_321079_/Q` | `rf_bignum_predec` | `_282283_/D` | `u_otbn_rf_bignum.gen_rf_bignum_ff.u_otbn_rf_bignum_inner.rf` | **-7.0238** |

## 各组的 slack 范围

| 组 | 条数 | 最差 | 最好 |
|---|---:|---:|---:|
| overall | 1000 | -7.0239 | -6.1248 |
| reg2reg | 1000 | -7.0239 | -6.1248 |
| reg2out | 1000 | 0.4908 | 5.4736 |
| in2reg | 1000 | 2.4650 | 3.2030 |
| in2out | 360 | 0.0884 | 2.9918 |

## 前 1000 条路径的端点归属（top 12）

**起点归属**

| 归属名 | 条数 |
|---|---:|
| `rf_bignum_predec` | 1000 |

**终点归属**

| 归属名 | 条数 |
|---|---:|
| `u_otbn_rf_bignum.gen_rf_bignum_ff.u_otbn_rf_bignum_inner.rf` | 923 |
| `ispr_acc_intg` | 25 |
| `ispr_kmac_data_s0_rdata` | 13 |
| `u_otbn_mac_bignum.c_intg_q` | 13 |
| `u_otbn_mac_bignum.u_otbn_p256_fold.ll_o` | 9 |
| `u_otbn_instruction_fetch.u_mac_bignum_fsm.current_cycle` | 5 |
| `u_otbn_lsu.lsu_word_select` | 3 |
| `u_otbn_kmac_if.no_more_msg_allowed_q` | 1 |
| `u_otbn_kmac_if.ctrl_error_q` | 1 |
| `u_otbn_kmac_if.data_s1_pending_q` | 1 |
| `u_otbn_kmac_if.data_s0_pending_q` | 1 |
| `u_otbn_controller.u_otbn_loop_controller.g_loop_counters[5].u_loop_count.err_o` | 1 |

