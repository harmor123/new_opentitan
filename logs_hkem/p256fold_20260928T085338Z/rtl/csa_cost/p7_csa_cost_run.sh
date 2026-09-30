#!/bin/bash
# P7 Step 6「双 CSA 决策」：量 A2 的**增量面积** —— 对四个孤立模块各跑一次流程自带的
# `tcl/yosys_run_synth.tcl` + `tcl/sta_run_reports.tcl`（**一行不改**），条件与 A1 完全相同：
#   同一 liberty、clk 8000 ps、ABC -D 4000（= 8000−4000）、flatten、TIMING_RUN=1、
#   连 SDC 都用流程自己的 `otbn.nangate.sdc` / `otbn_abc.nangate.sdc`（通用模板，无 otbn 专用端口名）。
#
# **不重综合 A1、不改任何设计 RTL、不进设计文件清单**（模块只从 <out>/generated/ 读）。
# 屏幕只打印摘要（完整日志在 <out>/run.log）；四条面积与增量写进 <dest>/p7_csa_cost_summary.txt ✓。
#
# 用法（任意目录）：
#   bash logs_hkem/p256fold_20260928T085338Z/rtl/csa_cost/p7_csa_cost_run.sh [dest_dir]
set -u

REPO=$(git rev-parse --show-toplevel)
PRE="$REPO/hw/ip/otbn/pre_syn"
COST="$REPO/logs_hkem/p256fold_20260928T085338Z/rtl/csa_cost"
DEST=${1:-$REPO/logs_hkem/p256fold_20260928T085338Z/reports}
LIB=${P7_LIB:-/home/chy/nangate45/NangateOpenCellLibrary_typical.lib}
[ -f "$LIB" ] || { echo "找不到 liberty: $LIB（用 P7_LIB=/path/to.lib 覆盖）" >&2; exit 1; }
LIB=$(readlink -f "$LIB")
[ -d "$PRE" ] || { echo "找不到 $PRE" >&2; exit 1; }
mkdir -p "$DEST"

cd "$PRE" || exit 1
echo "[csa] liberty sha256: $(sha256sum "$LIB" | cut -d' ' -f1)"

for M in p7_cpa4_ref p7_cpa2_ref p7_csa1_cost p7_csa2_cost; do
  OUT="syn_out/csa_cost_${M}_$(date +%Y_%m_%d_%H_%M_%S)"
  mkdir -p "$OUT/generated" "$OUT/reports/timing"     # ← timing/ 必须先建（上次就是漏了它 ✗）
  cp "$COST/$M.v" "$OUT/generated/$M.v"

  env LR_SYNTH_IP_NAME=otbn LR_SYNTH_TOP_MODULE="$M" \
      LR_SYNTH_CELL_LIBRARY_PATH="$LIB" LR_SYNTH_CELL_LIBRARY_NAME=nangate \
      LR_SYNTH_CONFIG_FILE="$COST/p7_csa_cost_conf.tcl" \
      LR_SYNTH_OUT_DIR="$OUT" LR_SYNTH_TIMING_RUN=1 LR_SYNTH_FLATTEN=1 \
      yosys -c ./tcl/yosys_run_synth.tcl > "$OUT/run.log" 2>&1
  if ! grep -q 'End Yosys Stat Report' "$OUT/run.log"; then
    echo "[csa] $M：yosys 没跑完 ⇒ 停" >&2; tail -20 "$OUT/run.log" >&2; exit 1
  fi

  env LR_SYNTH_IP_NAME=otbn LR_SYNTH_TOP_MODULE="$M" \
      LR_SYNTH_CELL_LIBRARY_PATH="$LIB" LR_SYNTH_CELL_LIBRARY_NAME=nangate \
      LR_SYNTH_CONFIG_FILE="$COST/p7_csa_cost_conf.tcl" \
      LR_SYNTH_OUT_DIR="$OUT" LR_SYNTH_TIMING_RUN=1 LR_SYNTH_FLATTEN=1 \
      sta ./tcl/sta_run_reports.tcl >> "$OUT/run.log" 2>&1

  [ -s "$OUT/reports/area.rpt" ] || { echo "[csa] $M：没有 area.rpt ⇒ 停" >&2; exit 1; }
  A=$(grep -oE "Chip area for module '[^']+': [0-9.]+" "$OUT/reports/area.rpt" | tail -1 | awk '{print $NF}')
  S=$(grep -oE 'used for sequential elements: [0-9.]+ \([0-9.]+%\)' "$OUT/reports/area.rpt" | tail -1)
  echo "[csa] $M: ${A} µm²  ${S}"
  cp "$OUT/reports/area.rpt" "$DEST/p7_csa_cost_${M}_area.rpt"
  for f in overall reg2reg reg2out in2reg; do
    [ -f "$OUT/reports/timing/$f.csv.rpt" ] && cp "$OUT/reports/timing/$f.csv.rpt" "$DEST/p7_csa_cost_${M}_${f}.csv.rpt"
  done
done

# 汇总（面积 + 增量区间）—— 屏幕与文件各一份 ✓
SUM="$DEST/p7_csa_cost_summary.txt"
python3 - "$DEST" > "$SUM" <<'PY'
import pathlib, re, sys
d = pathlib.Path(sys.argv[1])
def area(m):
    t = (d / ("p7_csa_cost_%s_area.rpt" % m)).read_text(errors="replace")
    return float(re.search(r"Chip area for module '[^']+': ([0-9.]+)", t).group(1))
def seq(m):
    t = (d / ("p7_csa_cost_%s_area.rpt" % m)).read_text(errors="replace")
    m2 = re.search(r"used for sequential elements: ([0-9.]+) \(([0-9.]+)%\)", t)
    return (float(m2.group(1)), float(m2.group(2)))
a = {m: area(m) for m in ("p7_cpa4_ref", "p7_cpa2_ref", "p7_csa1_cost", "p7_csa2_cost")}
print("P7 Step 6 代价探针：A2 / A4 的增量面积（同 flow、同 liberty、clk 8000 ps、ABC -D 4000、flatten）")
for m in a:
    s, p = seq(m)
    print("  %-14s %10.3f um^2   sequential %8.3f (%4.1f%%)" % (m, a[m], s, p))
print("")
print("A2 增量（2 级 CSA + 260-bit carry 状态 + 末级 CPA，相对平坦 CPA）：")
print("  lower  bound (vs 4-term flat CPA): %8.3f um^2" % (a["p7_csa2_cost"] - a["p7_cpa4_ref"]))
print("  upper  bound (vs 2-term flat CPA): %8.3f um^2" % (a["p7_csa2_cost"] - a["p7_cpa2_ref"]))
print("A4 增量（1 级 CSA 形态）：")
print("  lower  bound: %8.3f um^2" % (a["p7_csa1_cost"] - a["p7_cpa4_ref"]))
print("  upper  bound: %8.3f um^2" % (a["p7_csa1_cost"] - a["p7_cpa2_ref"]))
PY
cat "$SUM"
echo "[csa] 汇总已写：$SUM（贴这一份就够 ✓）"
