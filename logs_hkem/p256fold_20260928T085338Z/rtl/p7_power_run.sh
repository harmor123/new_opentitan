#!/bin/bash
# P7 Step 9 补充：对**已有的** .sta.v 网表跑 OpenSTA report_power（不重综合、不改任何 RTL）。
#
# 用法（任意目录）：
#   bash logs_hkem/p256fold_20260928T085338Z/rtl/p7_power_run.sh <run_dir> <top_module> <alpha> <dest_dir>
# 例（run_dir 可给相对 hw/ip/otbn/pre_syn 的路径，也可给绝对路径）：
#   bash logs_hkem/p256fold_20260928T085338Z/rtl/p7_power_run.sh \
#        syn_out/otbn_p256_fold_2026_09_30_18_47_02 otbn_p256_fold 0.10 \
#        logs_hkem/p256fold_20260928T085338Z/reports
#
# 需要：与跑 pre_syn 时**同一 shell 环境**（sta 在 PATH 里）；liberty 默认取
#       /home/chy/nangate45/NangateOpenCellLibrary_typical.lib（可用 LR_SYNTH_CELL_LIBRARY_PATH 覆盖）。
set -u

RUN=${1:?用法: $0 <run_dir> <top_module> <alpha> <dest_dir>}
TOP=${2:?缺 top_module}
ALPHA=${3:?缺 alpha（如 0.10）}
DEST=${4:?缺 dest_dir}

REPO=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "不在 git 仓库里" >&2; exit 1; }
PRE_SYN="$REPO/hw/ip/otbn/pre_syn"
[ -d "$PRE_SYN" ] || { echo "找不到 $PRE_SYN" >&2; exit 1; }

# run_dir 支持相对 pre_syn 的写法
case "$RUN" in
  /*) RUN_ABS="$RUN" ;;
  *)  RUN_ABS="$PRE_SYN/$RUN" ;;
esac
[ -d "$RUN_ABS" ] || {
  echo "找不到 run 目录: $RUN_ABS" >&2
  echo "查一下还在不在: ls -d $PRE_SYN/syn_out/*_2026_09_30_*" >&2
  exit 1
}

# 从 run 目录里**发现**网表与 SDC（不猜名字；多于一/零个就报错）
mapfile -t NETS < <(ls "$RUN_ABS"/generated/*_netlist.sta.v 2>/dev/null)
mapfile -t SDCS < <(ls "$RUN_ABS"/generated/*.out.sdc 2>/dev/null)
[ "${#NETS[@]}" -eq 1 ] || { echo "网表不唯一/缺失（${#NETS[@]} 个）:" >&2; printf '  %s\n' "${NETS[@]:-无}" >&2; exit 1; }
[ "${#SDCS[@]}" -eq 1 ] || { echo "SDC 不唯一/缺失（${#SDCS[@]} 个）:" >&2; printf '  %s\n' "${SDCS[@]:-无}" >&2; exit 1; }

LIB=${LR_SYNTH_CELL_LIBRARY_PATH:-/home/chy/nangate45/NangateOpenCellLibrary_typical.lib}
[ -f "$LIB" ] || { echo "找不到 liberty: $LIB（用 LR_SYNTH_CELL_LIBRARY_PATH=… 覆盖）" >&2; exit 1; }

echo "[p7] run   = $RUN_ABS"
echo "[p7] top   = $TOP"
echo "[p7] net   = ${NETS[0]}"
echo "[p7] sdc   = ${SDCS[0]}"
echo "[p7] lib   = $LIB"
echo "[p7] alpha = $ALPHA"

mkdir -p "$RUN_ABS/reports"
DEST_ABS="$REPO/$DEST"; case "$DEST" in /*) DEST_ABS="$DEST" ;; esac
mkdir -p "$DEST_ABS"

cd "$PRE_SYN" || exit 1
export LR_SYNTH_IP_NAME=${LR_SYNTH_IP_NAME:-otbn}
export LR_SYNTH_CELL_LIBRARY_PATH="$LIB"
export LR_SYNTH_CELL_LIBRARY_NAME=${LR_SYNTH_CELL_LIBRARY_NAME:-nangate}
export LR_SYNTH_TOP_MODULE="$TOP"
export LR_SYNTH_OUT_DIR="$RUN_ABS"
export LR_SYNTH_STA_NETLIST_OUT="${NETS[0]}"
export LR_SYNTH_SDC_FILE_OUT="${SDCS[0]}"
export P7_ALPHA="$ALPHA"
export P7_HELP=1

LOG="$RUN_ABS/reports/p7_power_${TOP}_a${ALPHA}.log"
sta "$REPO/logs_hkem/p256fold_20260928T085338Z/rtl/p7_power_report.tcl" 2>&1 | tee "$LOG"
rc=${PIPESTATUS[0]}
echo "[p7] sta exit=$rc（日志：$LOG）"

PWR="$RUN_ABS/reports/p7_power_a${ALPHA}.rpt"
ACT="$RUN_ABS/reports/p7_activity_annotation_a${ALPHA}.rpt"
[ -f "$PWR" ] || { echo "没有产出 $PWR ⇒ 看日志" >&2; exit 1; }
cp "$PWR" "$DEST_ABS/p7_sta_power_${TOP}_a${ALPHA}.rpt"
echo "[p7] 已复制 → $DEST_ABS/p7_sta_power_${TOP}_a${ALPHA}.rpt"
if [ -f "$ACT" ]; then
  cp "$ACT" "$DEST_ABS/p7_sta_activity_${TOP}_a${ALPHA}.rpt"
  echo "[p7] 已复制 → $DEST_ABS/p7_sta_activity_${TOP}_a${ALPHA}.rpt"
else
  echo "[p7] （无覆盖率报告：本机 OpenSTA 无 report_activity_annotation，如实记）"
fi
