#!/bin/bash
# P7 Step 11「时钟扫描」：对 A0/A1/B0/L1 的**已综合网表**各扫一组时钟周期（只跑 OpenSTA ✓ 不重综合 ✓）。
#
# 复用 p7_power_run.sh 的同一套机制：LR_SYNTH_* 环境 + 流程自带 `tcl/sta_common.tcl` ✓；
# 唯一的区别是 period 由 P7_PERIOD_NS 覆盖 ✓。
#
# 用法（任意目录）：bash logs_hkem/p256fold_20260928T085338Z/rtl/p7_sweep/p7_sweep_run.sh [dest_dir]
# 产物：<dest>/sweep_<design>.csv 与合并的 <dest>/sweep_fmax.csv（覆盖占位版 ✓）
set -u

REPO=$(git rev-parse --show-toplevel)
PRE="$REPO/hw/ip/otbn/pre_syn"
SW="$REPO/logs_hkem/p256fold_20260928T085338Z/rtl/p7_sweep"
DEST=${1:-$REPO/logs_hkem/p256fold_20260928T085338Z/ppa}
case "$DEST" in /*) ;; *) DEST="$PWD/$DEST" ;; esac      # ← 相对路径必须在 cd 之前转绝对（踩过一次：cd 后写到了 pre_syn 下 ✗）
LIB=${P7_LIB:-/home/chy/nangate45/NangateOpenCellLibrary_typical.lib}
PERIODS=${P7_PERIODS:-"8.0 7.5 7.0 6.5 6.0"}
[ -f "$LIB" ] || { echo "找不到 liberty: $LIB（用 P7_LIB=…）" >&2; exit 1; }
LIB=$(readlink -f "$LIB")
mkdir -p "$DEST" "$SW/work"
cd "$PRE" || exit 1

# 设计与 run 目录（与 §8.13/§8.15 用的同一批 ✓）
declare -A RUNS=(
  [A0]="syn_out/otbn_core_2026_09_30_18_53_19:otbn_core"
  [A1]="syn_out/otbn_core_2026_09_30_20_22_02:otbn_core"
  [B0]="/tmp/b0/hw/ip/otbn/pre_syn/syn_out/otbn_core_2026_09_30_18_17_11:otbn_core"
  [L1]="syn_out/otbn_p256_fold_2026_09_30_18_47_02:otbn_p256_fold"
)

: > "$DEST/sweep_all.csv"
echo "design,period_ns,slack_ns,fmax_mhz_of_that_point,startpoint,endpoint" >> "$DEST/sweep_all.csv"
for D in A0 A1 B0 L1; do
  R="${RUNS[$D]}"; RUN="${R%%:*}"; TOP="${R##*:}"
  case "$RUN" in /*) RUN_ABS="$RUN" ;; *) RUN_ABS="$PRE/$RUN" ;; esac
  NET=$(ls "$RUN_ABS"/generated/*_netlist.sta.v 2>/dev/null | head -1)
  SDC=$(ls "$RUN_ABS"/generated/*.out.sdc 2>/dev/null | head -1)
  [ -n "$NET" ] && [ -n "$SDC" ] || { echo "[sweep] $D：缺网表/SDC（$RUN_ABS）⇒ 跳过 ✗" >&2; continue; }
  echo "===== $D（$TOP）"
  for P in $PERIODS; do
    W="$SW/work/$D"; mkdir -p "$W"
    env LR_SYNTH_TIMING_RUN=1 LR_SYNTH_IP_NAME=otbn LR_SYNTH_TOP_MODULE="$TOP" \
        LR_SYNTH_CELL_LIBRARY_PATH="$LIB" LR_SYNTH_CELL_LIBRARY_NAME=nangate \
        LR_SYNTH_OUT_DIR="$RUN_ABS" LR_SYNTH_STA_NETLIST_OUT="$NET" LR_SYNTH_SDC_FILE_OUT="$SDC" \
        P7_PERIOD_NS="$P" P7_OUT="$W" \
        sta "$SW/p7_sweep_sta.tcl" > "$W/p${P}.log" 2>&1
    R1="$W/p7_sweep_result.csv"
    if [ -s "$R1" ]; then
      tail -1 "$R1" | awk -v d="$D" -F, '{printf "%s,%s,%s,%s,%s,%s\n", d, $2, $3, ($2>0? 1000/$2 : 0), $4, $5}' >> "$DEST/sweep_all.csv"
      cp "$R1" "$DEST/sweep_${D}_p${P}.csv"
      printf "  period %-4s ⇒ slack %s\n" "$P" "$(tail -1 "$R1" | cut -d, -f3)"
    else
      echo "  period $P ⇒ 失败（看 $W/p${P}.log ✗）" >&2
    fi
  done
done
N=$(($(wc -l < "$DEST/sweep_all.csv") - 1))
if [ "$N" -gt 0 ]; then
  cp "$DEST/sweep_all.csv" "$DEST/sweep_fmax.csv"   # 覆盖占位版（同名 ✓）
  echo "[sweep] 完成：$N 个点 → $DEST/sweep_all.csv（并覆盖 sweep_fmax.csv ✓）"
else
  echo "[sweep] 一个点都没扫到 ⇒ **不覆盖** sweep_fmax.csv（保留占位版 ✗）" >&2
  exit 1
fi
