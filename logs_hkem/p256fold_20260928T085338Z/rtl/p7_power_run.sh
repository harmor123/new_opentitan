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
# liberty：默认 /home/chy/nangate45/NangateOpenCellLibrary_typical.lib（= §8.13.1 用的那一份）；
#          **不继承环境里的 LR_SYNTH_CELL_LIBRARY_PATH**（2026-09-30 踩过：环境里指向 ORFS 那份，
#          会静默换库）。要换库就显式 P7_LIB=/path/to.lib。
# 需要：与跑 pre_syn 时**同一 shell 环境**（sta 在 PATH 里）。
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

LIB=${P7_LIB:-/home/chy/nangate45/NangateOpenCellLibrary_typical.lib}
[ -f "$LIB" ] || { echo "找不到 liberty: $LIB（用 P7_LIB=/path/to.lib 覆盖）" >&2; exit 1; }
LIB=$(readlink -f "$LIB")   # 后面要 cd 到 pre_syn 再 read_liberty ⇒ 必须绝对路径
if [ -n "${LR_SYNTH_CELL_LIBRARY_PATH:-}" ] && [ "$LR_SYNTH_CELL_LIBRARY_PATH" != "$LIB" ]; then
  echo "[p7] 注意：环境里的 LR_SYNTH_CELL_LIBRARY_PATH=$LR_SYNTH_CELL_LIBRARY_PATH"
  echo "[p7]       本次**不用**它，用的是 P7_LIB 的 $LIB（口径必须与 §8.13.1 一致）"
fi

echo "[p7] run   = $RUN_ABS"
echo "[p7] top   = $TOP"
echo "[p7] net   = ${NETS[0]}"
echo "[p7] sdc   = ${SDCS[0]}"
echo "[p7] lib   = $LIB"
echo "[p7] alpha = $ALPHA"
# 把输入指纹钉住（写进日志 ⇒ 文档里能对表）
( cd "$RUN_ABS" && sha256sum "${NETS[0]}" "${SDCS[0]}" "$LIB" ) | sed 's/^/[p7] sha256 /'

mkdir -p "$RUN_ABS/reports"
DEST_ABS="$REPO/$DEST"; case "$DEST" in /*) DEST_ABS="$DEST" ;; esac
mkdir -p "$DEST_ABS"

cd "$PRE_SYN" || exit 1
export LR_SYNTH_TIMING_RUN=1          # **必须**：STA 网表/SDC 两个流程变量只在该模式下定义
export LR_SYNTH_IP_NAME=${LR_SYNTH_IP_NAME:-otbn}
export LR_SYNTH_CELL_LIBRARY_PATH="$LIB"
export LR_SYNTH_CELL_LIBRARY_NAME=${LR_SYNTH_CELL_LIBRARY_NAME:-nangate}
export LR_SYNTH_TOP_MODULE="$TOP"
export LR_SYNTH_OUT_DIR="$RUN_ABS"
export LR_SYNTH_STA_NETLIST_OUT="${NETS[0]}"
export LR_SYNTH_SDC_FILE_OUT="${SDCS[0]}"
export P7_ALPHA="$ALPHA"
export P7_PROBE=1

LOG="$RUN_ABS/reports/p7_power_${TOP}_a${ALPHA}.log"
sta "$REPO/logs_hkem/p256fold_20260928T085338Z/rtl/p7_power_report.tcl" 2>&1 | tee "$LOG"
sta_rc=${PIPESTATUS[0]}
echo "[p7] sta exit=$sta_rc（日志：$LOG）"

PWR="$RUN_ABS/reports/p7_power_a${ALPHA}.rpt"
ACT="$RUN_ABS/reports/p7_activity_annotation_a${ALPHA}.rpt"

# --- 硬判据 1：tcl 必须跑到末尾（打印 DONE）⇒ 排除"崩在中途"（本次实测 exit=139 段错误） ---
if ! grep -q '^p7: DONE' "$LOG"; then
  echo "日志里没有 'p7: DONE' ⇒ tcl 没跑完（sta exit=$sta_rc）" >&2
  echo "---- 最后一个阶段标记 ----" >&2
  grep '^p7: STAGE' "$LOG" | tail -3 >&2
  echo "---- 日志末尾 15 行 ----" >&2
  tail -15 "$LOG" >&2
  [ -f "$PWR" ] && { echo "---- 报告（若已写出）前 20 行 ----" >&2; head -20 "$PWR" >&2; }
  exit 1
fi

# --- 硬判据 2：报告非空 + 含功耗表头；Error 行只作信息（OpenSTA 的 error 不中止执行） ---
echo "[p7] 日志里的 Error 行数 = $(grep -c '^Error' "$LOG" || true)（信息项；判据是 DONE + 报告内容）"
[ -s "$PWR" ] || { echo "报告为空/缺失：$PWR ⇒ 看日志 $LOG" >&2; exit 1; }
if ! grep -q -E 'Total|Internal|Switching|Leakage' "$PWR"; then
  echo "报告里没有功耗表头（Total/Internal/Switching/Leakage）：$PWR ⇒ 看日志" >&2
  head -20 "$PWR" >&2
  exit 1
fi

cp "$PWR" "$DEST_ABS/p7_sta_power_${TOP}_a${ALPHA}.rpt"
echo "[p7] 已复制 → $DEST_ABS/p7_sta_power_${TOP}_a${ALPHA}.rpt"
if [ -f "$ACT" ]; then
  cp "$ACT" "$DEST_ABS/p7_sta_activity_${TOP}_a${ALPHA}.rpt"
  echo "[p7] 已复制 → $DEST_ABS/p7_sta_activity_${TOP}_a${ALPHA}.rpt"
else
  echo "[p7] （无覆盖率报告：本机 OpenSTA 无 report_activity_annotation，如实记）"
fi
UNITS="$RUN_ABS/reports/p7_units_a${ALPHA}.rpt"
if [ -f "$UNITS" ]; then
  cp "$UNITS" "$DEST_ABS/p7_sta_units_${TOP}_a${ALPHA}.rpt"
  echo "[p7] 已复制 → $DEST_ABS/p7_sta_units_${TOP}_a${ALPHA}.rpt"
else
  echo "[p7] （无单位报告：本机 OpenSTA 无 report_units）"
fi
