# 时序报告（A1 + Step 5 预译码（overlap 常量化，TIMING_RUN=1，ABC -D 4000））

> 数据源：`/home/chy/new_pqc/opentitan/hw/ip/otbn/pre_syn/syn_out/otbn_core_2026_09_30_20_22_02/reports/timing/*.csv.rpt`（OpenSTA 经 yosys pre_syn 流；本工具直接读原始报告，绕开坏掉的 vendored 名字翻译器）。每条 = `起点,终点,slack(ns)`；**负 = 违例**。
>
> 归属列来自 `ys_translated_names`：2131 组 `_NNNNN_` ↔ 原名（按**相邻行**配对，其中 4 组走上一行回退）。

- **overall**：1000 条，最差 slack **-6.4325 ns**（`insn_cnt_o` → `_275689_`）
- **reg2reg**：1000 条，最差 slack **-6.4325 ns**（`insn_cnt_o` → `_275689_`）
- **reg2out**：1000 条，最差 slack **0.4699 ns**（`insn_cnt_o` → `dmem_rmask_o[4]`）
- **in2reg**：1000 条，最差 slack **2.5672 ns**（`urnd_ctrl_enabled_i` → `_286106_`）
- **in2out**：360 条，最差 slack **0.0775 ns**（`wfi_enabled_i` → `dmem_rmask_o[4]`）

> ⚠ **这些 csv 已被 vendored 翻译器覆盖**（overall, reg2reg, reg2out, in2reg, in2out）：`translate_timing_csv.py` 会**原地重写**同一个文件、加表头 `Start Point, End Point, WNS (ns)`、并用 `generated_cell_re` **剥掉 pin 名** ⇒ 只剩裸单元名。它自称的「翻译」在本设计上不生效（`build_translated_names_dict` 把字典建成 `{原名: _NNNN_}`，而查表用 `_NNNN_`，永不命中）；净效果 = 丢 pin + 加表头。**归属用 `--names` 自己算**。

## 最差 12 条路径（overall 组）

| # | 起点 | 起点归属 | 终点 | 终点归属 | slack (ns) |
|---:|---|---|---|---|---:|
| 1 | `insn_cnt_o` | `（未在映射中）` | `_275689_` | `u_otbn_rf_bignum.gen_rf_bignum_ff.u_otbn_rf_bignum_inner.rf` | **-6.4325** |
| 2 | `insn_cnt_o` | `（未在映射中）` | `_280685_` | `u_otbn_rf_bignum.gen_rf_bignum_ff.u_otbn_rf_bignum_inner.rf` | **-6.4325** |
| 3 | `insn_cnt_o` | `（未在映射中）` | `imem_sec_wipe_urnd_key_o` | `（未在映射中）` | **-6.4324** |
| 4 | `insn_cnt_o` | `（未在映射中）` | `u_otbn_rf_bignum.gen_rf_bignum_ff.u_otbn_rf_bignum_inner.rf` | `（未在映射中）` | **-6.4324** |
| 5 | `insn_cnt_o` | `（未在映射中）` | `imem_sec_wipe_urnd_key_o` | `（未在映射中）` | **-6.4324** |
| 6 | `insn_cnt_o` | `（未在映射中）` | `u_otbn_rf_bignum.gen_rf_bignum_ff.u_otbn_rf_bignum_inner.rf` | `（未在映射中）` | **-6.4324** |
| 7 | `insn_cnt_o` | `（未在映射中）` | `u_otbn_rf_bignum.gen_rf_bignum_ff.u_otbn_rf_bignum_inner.rf` | `（未在映射中）` | **-6.4324** |
| 8 | `insn_cnt_o` | `（未在映射中）` | `_276625_` | `u_otbn_rf_bignum.gen_rf_bignum_ff.u_otbn_rf_bignum_inner.rf` | **-6.4324** |
| 9 | `insn_cnt_o` | `（未在映射中）` | `u_otbn_rf_bignum.gen_rf_bignum_ff.u_otbn_rf_bignum_inner.rf` | `（未在映射中）` | **-6.4324** |
| 10 | `insn_cnt_o` | `（未在映射中）` | `u_otbn_rnd.current_state` | `（未在映射中）` | **-6.4324** |
| 11 | `insn_cnt_o` | `（未在映射中）` | `ispr_acc_intg` | `（未在映射中）` | **-6.4324** |
| 12 | `insn_cnt_o` | `（未在映射中）` | `u_otbn_rnd.current_state` | `（未在映射中）` | **-6.4324** |

## 各组的 slack 范围

| 组 | 条数 | 最差 | 最好 |
|---|---:|---:|---:|
| overall | 1000 | -6.4325 | -5.5279 |
| reg2reg | 1000 | -6.4325 | -5.5279 |
| reg2out | 1000 | 0.4699 | 5.4747 |
| in2reg | 1000 | 2.5672 | 3.1564 |
| in2out | 360 | 0.0775 | 3.0103 |

## 前 1000 条路径的端点归属（top 12）

**起点归属**

| 归属名 | 条数 |
|---|---:|
| `（未在映射中）` | 1000 |

**终点归属**

| 归属名 | 条数 |
|---|---:|
| `（未在映射中）` | 508 |
| `u_otbn_rf_bignum.gen_rf_bignum_ff.u_otbn_rf_bignum_inner.rf` | 462 |
| `ispr_acc_intg` | 10 |
| `ispr_kmac_data_s0_rdata` | 6 |
| `u_otbn_mac_bignum.c_intg_q` | 6 |
| `u_otbn_mac_bignum.u_otbn_p256_fold.ll_o` | 3 |
| `u_otbn_instruction_fetch.u_mac_bignum_fsm.current_cycle` | 2 |
| `u_otbn_kmac_if.data_s0_pending_q` | 1 |
| `u_otbn_controller.u_otbn_loop_controller.g_loop_counters[5].u_loop_count.err_o` | 1 |
| `u_otbn_controller.lsu_addr_saved_q` | 1 |

