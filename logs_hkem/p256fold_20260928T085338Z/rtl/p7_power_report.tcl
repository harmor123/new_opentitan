# P7 Step 9 补充：用流程自带的 OpenSTA 对**已有**的 `.sta.v` 网表出 `report_power`（vectorless）。
#
# 目的：**独立工具、同一 liberty、同一网表、同一 α** 校 §8.13.1 的解析式估计（A 档）。
#       输出形状与仓库 DC 流程同构：net / int / leak + units（`hw/syn/tools/dc/parse-syn-report.py` 解析的就是这四项）。
#
# 前置（由 p7_power_run.sh 设置；手跑需自己 export）：
#   LR_SYNTH_CELL_LIBRARY_PATH / LR_SYNTH_CELL_LIBRARY_NAME / LR_SYNTH_TOP_MODULE / LR_SYNTH_OUT_DIR
#   LR_SYNTH_STA_NETLIST_OUT / LR_SYNTH_SDC_FILE_OUT / P7_ALPHA / [P7_HELP=1]
# **必须在 hw/ip/otbn/pre_syn 下执行**（`source ./tcl/sta_common.tcl` 按 cwd 解析）。

source ./tcl/sta_common.tcl

# --- 守护：命令缺一个就停，不许"跑到一半换个口径" ---
foreach cmd {set_power_activity report_power} {
  if {[llength [info commands $cmd]] == 0} {
    error "本机 OpenSTA 没有 `$cmd` ⇒ 停（流程 README 记录测试版本为 OpenSTA 2.2；请确认本机版本）"
  }
}

set p7_alpha 0.1
if {[info exists ::env(P7_ALPHA)]} { set p7_alpha $::env(P7_ALPHA) }
set p7_rep "$lr_synth_out_dir/reports"

puts "p7: top     = $lr_synth_top_module"
puts "p7: netlist = $lr_synth_sta_netlist_out"
puts "p7: sdc     = $lr_synth_sdc_file_out"
puts "p7: lib     = $lr_synth_cell_library_path"
puts "p7: alpha   = $p7_alpha （vectorless 输入活动率；duty 用工具默认）"

# 与流程的时序报告保持一致：**不设 propagated clock**（本流程无 CTS，流程自己也未设）
# ⇒ 与 §8.13.1 的解析式估计同口径（那边用 liberty 的时钟脚电容、α=1）。
set_power_activity -input -activity $p7_alpha
puts "p7: set_power_activity -input -activity $p7_alpha 已执行"

# 覆盖率：决定这份数能不能引用（无该命令时如实跳过，不编）
if {[llength [info commands report_activity_annotation]]} {
  report_activity_annotation > $p7_rep/p7_activity_annotation_a${p7_alpha}.rpt
  puts "p7: 覆盖率 → $p7_rep/p7_activity_annotation_a${p7_alpha}.rpt"
} else {
  puts "p7: 本机 OpenSTA 无 report_activity_annotation ⇒ 未记录标注覆盖率（如实记）"
}

report_power > $p7_rep/p7_power_a${p7_alpha}.rpt

# 把报告原文打到 stdout，便于直接贴回来
set fh [open $p7_rep/p7_power_a${p7_alpha}.rpt r]
set txt [read $fh]
close $fh
puts "===== 报告原文：p7_power_a${p7_alpha}.rpt ====="
puts $txt

# 可选：打印本机 `set_power_activity` 的实际用法（P7_HELP=1），用于决定能否做"全网上平坦 α"的变体
if {[info exists ::env(P7_HELP)]} {
  puts "===== 本机 set_power_activity 用法（无参调用）====="
  catch {set_power_activity} msg
  puts $msg
}

exit
