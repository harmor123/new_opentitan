# OTBN 剖面数据 · ver0_2（harness 法，ISS 口径）

> KMAC 硬件哈希。数据版本 **2026-09-20 v4**：全部阶段**直接实测**（`Δ = profiling − control`，`reuse = 0`）。
> 本目录是 `test_perf/harness.py` 的**默认输出位置**；交付归档在 `md文档/新方案/实验数据/`
> （按约定只放 README + 两份汇总，逐版本数据文件不复制，避免重复）。

## 本目录内容

| 文件 | 内容 |
|---|---|
| `re_ver0_2.csv` / `re_ver0_2.json` / `re_ver0_2.md` | harness 三件套：逐阶段 Δ（cycles / insn / stalls / text / data / image / FIPS / 口径 / mulqacc / 调用计数）＋完整指令直方图＋app 逐 PC 覆盖（`exec_insn`） |
| `run.log` | 完整 stdout：macro、逐阶段 Δ、三条闭环表、`[运行健康检查]`、逐 op 分解表、残差归因 |
| `stall_profile_{keygen,encap,decap}.log` | 拍级归因（app 拍数按 PC 摊到符号 / 匿名 wrapper 清零循环；每份含自证） |

## 一键三版（推荐）

```bash
cd ~/new_pqc/opentitan

# ① 三版重测（≈1 分钟/版；ISS 确定性 ⇒ 重跑应与既有数据逐位一致）
for V in ver0_1 ver0_2 ver1_1; do
  P=test_hybrid_kem_otbn_prompt_${V}
  A=(--config test_perf/harness_config.yaml --version "$V"
     --csv logs_hkem/${V}_profiling/re_${V}.csv
     --json logs_hkem/${V}_profiling/re_${V}.json
     --markdown logs_hkem/${V}_profiling/re_${V}.md)
  bazel build //${P}/otbn/mlkem768:all
  python3 test_perf/harness.py "${A[@]}" | tee logs_hkem/${V}_profiling/run.log
done

# ② 三版静态预检（不需要构建，秒级）
python3 test_perf/tools/check/check_stream_shape.py          # 一次看三版
for V in ver0_1 ver0_2 ver1_1; do
  python3 test_perf/tools/check/audit_fidelity.py --version "$V"
  python3 test_perf/tools/check/otbn_symbol_check.py --build test_hybrid_kem_otbn_prompt_${V}/otbn/mlkem768/BUILD
done

# ③ 三版 × 三 op 拍级归因（残差拆到部件；每份日志自带自证）
for V in ver0_1 ver0_2 ver1_1; do for op in keygen encap decap; do
  T=$op; [ "$op" = keygen ] && T=keypair
  python3 test_perf/tools/diag/stall_profile.py --version "$V" --op "$op" --target //test_hybrid_kem_otbn_prompt_${V}/otbn/mlkem768:mlkem768_${T} --out logs_hkem/${V}_profiling/stall_profile_${op}.log
done; done
```

> ⚠ **不要**用 `harness.py --version ver0_1 --version ver0_2 --version ver1_1` 一次跑三版：harness 支持重复 `--version`，但那样 `--json/--csv/--md` 是**同一个文件** ⇒ 会把每版各自的 `re_<版本>.json` 覆盖成一个（三版数据混在一个文件里，逐版文档就生成不出来了）。一键要用上面的**循环 + 每版各自输出路径**。

## 复现（Linux，仓库根执行）

```bash
# ① 重测本版本（约 1 分钟；ISS 确定性 ⇒ 重跑应逐位复现）
bazel build //test_hybrid_kem_otbn_prompt_ver0_2/otbn/mlkem768:all
python3 test_perf/harness.py --config test_perf/harness_config.yaml --version ver0_2     --csv logs_hkem/ver0_2_profiling/re_ver0_2.csv     --json logs_hkem/ver0_2_profiling/re_ver0_2.json     --markdown logs_hkem/ver0_2_profiling/re_ver0_2.md | tee logs_hkem/ver0_2_profiling/run.log

# ② 拍级归因（把残差拆到部件；9 组日志均自证：Σ退役/Σ停滞 == JSON 实测的 insn/stalls）
python3 test_perf/tools/diag/stall_profile.py --version ver0_2 --op <keygen|encap|decap>     --target //test_hybrid_kem_otbn_prompt_ver0_2/otbn/mlkem768:mlkem768_<keypair|encap|decap>     --out logs_hkem/ver0_2_profiling/stall_profile_<op>.log

# ③ 静态预检（不需要构建，秒级；应与历史结果逐条一致）
python3 test_perf/tools/check/check_stream_shape.py                      # 三版流形状/配额/replay
python3 test_perf/tools/check/otbn_symbol_check.py     --build test_hybrid_kem_otbn_prompt_ver0_2/otbn/mlkem768/BUILD          # 符号闭包 0 告警
python3 test_perf/tools/check/audit_fidelity.py --version ver0_2            # ①②③（含桩法 ②''）
```

## 判读（三条硬判据）

1. **运行健康**：`run.log` 的 `[运行健康检查]` 无 ⚠ —— 每行 `ERR_BITS=0` 且执行到自己的 `ecall`（残缺运行会被标 ⚠，不会静默进表）；
2. **调用闭环**：Keccak-f / KMAC API / `bn.mulqacc.wo` 的 Σ阶段 vs 整 app 差异 **+0**；
3. **桩法闭合**：`keygen_poly_gen_matrix_shake + …_rejection − …_stub_overhead` 与直接测量的
   `keygen_poly_gen_matrix` **精确闭合 +0**。

配套文档：`md文档/新方案/ver0_2分解表_*.md`（阶段级分解）· `实验数据/三版对照_全实测.md`（三版横向）·
`实验数据/残差构成_全实测.md`（残差按 PC 摊到部件）。
