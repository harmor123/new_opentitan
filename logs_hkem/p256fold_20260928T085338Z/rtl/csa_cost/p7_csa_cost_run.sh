#!/bin/bash
# P7 Step 6「双 CSA 决策」：量 A2 的**增量面积** —— 对四个孤立模块各跑一次流程自带的
# `tcl/yosys_run_synth.tcl` + `tcl/sta_run_reports.tcl`（**一行不改**），条件与 A1 完全相同：
#   同一 liberty、clk 8000 ps、ABC -D 4000（= 8000−4000）、flatten、TIMING_RUN=1、
#   连 SDC 都用流程自己的 `otbn.nangate.sdc` / `otbn_abc.nangate.sdc`（通用模板，无 otbn 专用端口名）。
#
# **不重综合 A1、不改任何设计 RTL、不进设计文件清单**（模块只从 <out>/generated/ 读）。
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
echo "[csa] liberty = $LIB"
sha256sum "$LIB" | sed 's/^/[csa] sha256 /'

for M in p7_cpa4_ref p7_cpa2_ref p7_csa1_cost p7_csa2_cost; do
  OUT="syn_out/csa_cost_${M}_$(date +%Y_%m_%d_%H_%M_%S)"
  mkdir -p "$OUT/generated" "$OUT/reports"
  cp "$COST/$M.v" "$OUT/generated/$M.v"
  echo "===== $M → $OUT"

  env LR_SYNTH_IP_NAME=otbn LR_SYNTH_TOP_MODULE="$M" \
      LR_SYNTH_CELL_LIBRARY_PATH="$LIB" LR_SYNTH_CELL_LIBRARY_NAME=nangate \
      LR_SYNTH_CONFIG_FILE="$COST/p7_csa_cost_conf.tcl" \
      LR_SYNTH_OUT_DIR="$OUT" LR_SYNTH_TIMING_RUN=1 LR_SYNTH_FLATTEN=1 \
      yosys -c ./tcl/yosys_run_synth.tcl 2>&1 | tee "$OUT/run.log"
  if ! grep -q 'End Yosys Stat Report' "$OUT/run.log"; then
    echo "[csa] $M：yosys 没跑完 ⇒ 停（看 $OUT/run.log）" >&2; exit 1
  fi

  env LR_SYNTH_IP_NAME=otbn LR_SYNTH_TOP_MODULE="$M" \
      LR_SYNTH_CELL_LIBRARY_PATH="$LIB" LR_SYNTH_CELL_LIBRARY_NAME=nangate \
      LR_SYNTH_CONFIG_FILE="$COST/p7_csa_cost_conf.tcl" \
      LR_SYNTH_OUT_DIR="$OUT" LR_SYNTH_TIMING_RUN=1 LR_SYNTH_FLATTEN=1 \
      sta ./tcl/sta_run_reports.tcl 2>&1 | tee -a "$OUT/run.log"

  # 面积（同一个 `stat -liberty` 报告）+ 时序汇总（overall 组）
  if [ ! -s "$OUT/reports/area.rpt" ]; then
    echo "[csa] $M：没有 area.rpt ⇒ 看 $OUT/run.log" >&2; exit 1
  fi
  echo "[csa] $M 面积（$OUT/reports/area.rpt）："
  grep -E 'Chip area|Total area|^[[:space:]]*[A-Za-z0-9_]+[[:space:]]+[0-9]+\.[0-9]+' "$OUT/reports/area.rpt" | tail -4 | sed 's/^/[csa]   /'
  cp "$OUT/reports/area.rpt" "$DEST/p7_csa_cost_${M}_area.rpt"
  for f in overall reg2reg reg2out in2reg; do
    [ -f "$OUT/reports/timing/$f.csv.rpt" ] && cp "$OUT/reports/timing/$f.csv.rpt" "$DEST/p7_csa_cost_${M}_${f}.csv.rpt"
  done
  echo "[csa] 已复制面积/时序 → $DEST/p7_csa_cost_${M}_*"
done

echo "[csa] 完成。增量口径：A2 = area(p7_csa2_cost) − area(p7_cpa2_ref)（上界形态）到"
echo "[csa]        area(p7_csa2_cost) − area(p7_cpa4_ref)（下界形态）；A4 同理换 p7_csa1_cost。"
echo "[csa] 各模块面积：logs_hkem/p256fold_20260928T085338Z/reports/p7_csa_cost_*_area.rpt"
