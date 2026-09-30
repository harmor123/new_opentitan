# P7 Step 9 补充：用流程自带的 OpenSTA 对**已有**的 `.sta.v` 网表出 `report_power`（vectorless）。
#
# 目的：**独立工具、同一 liberty、同一网表、同一 α** 校 §8.13.1 的解析式估计（A 档）。
#       输出形状与仓库 DC 流程同构：net / int / leak + units（`hw/syn/tools/dc/parse-syn-report.py` 解析的就是这四项）。
#
# 前置（由 p7_power_run.sh 设置；手跑需自己 export）：
#   LR_SYNTH_TIMING_RUN=1（**必须**：否则 sta_netlist_out / sdc_file_out 两个流程变量根本不会被定义）
#   LR_SYNTH_CELL_LIBRARY_PATH / LR_SYNTH_CELL_LIBRARY_NAME / LR_SYNTH_TOP_MODULE / LR_SYNTH_OUT_DIR
#   LR_SYNTH_STA_NETLIST_OUT / LR_SYNTH_SDC_FILE_OUT / P7_ALPHA / [P7_PROBE=1]
# **必须在 hw/ip/otbn/pre_syn 下执行**（`source ./tcl/sta_common.tcl` 按 cwd 解析）。

# --- 守护 0：流程变量必须存在（2026-09-30 实测踩过：漏 TIMING_RUN=1 ⇒ 未定义 ⇒ 空报告） ---
foreach v {lr_synth_sta_netlist_out lr_synth_sdc_file_out} {
  if {![info exists $v]} {
    error "流程变量 `$v` 未定义 ⇒ 忘了 LR_SYNTH_TIMING_RUN=1（STA 网表/SDC 的变量只在该模式下定义）"
  }
}

source ./tcl/sta_common.tcl

# --- 守护 1：命令缺一个就停，不许"跑到一半换个口径" ---
foreach cmd {set_power_activity report_power} {
  if {[llength [info commands $cmd]] == 0} {
    error "本机 OpenSTA 没有 `$cmd` ⇒ 停（流程 README 记录测试版本为 OpenSTA 2.2；请确认本机版本）"
  }
}

# --- 守护 2：设计真的 link 上了（否则 report_power 会写空文件而不报错） ---
if {[llength [get_ports *]] == 0} {
  error "设计未 link（`get_ports *` 为空）⇒ 停"
}
set p7_cells [llength [get_cells -hier *]]
if {$p7_cells == 0} { error "`get_cells -hier *` 为空 ⇒ 停" }
if {[catch {set p7_flops [llength [get_cells -hier -filter "is_sequential == true"]]} msg]} {
  set p7_flops "n/a（本机 filter 不支持 is_sequential：$msg）"
}

set p7_alpha 0.1
if {[info exists ::env(P7_ALPHA)]} { set p7_alpha $::env(P7_ALPHA) }
set p7_rep "$lr_synth_out_dir/reports"

puts "p7: top     = $lr_synth_top_module"
puts "p7: netlist = $lr_synth_sta_netlist_out"
puts "p7: sdc     = $lr_synth_sdc_file_out"
puts "p7: lib     = $lr_synth_cell_library_path"
puts "p7: cells   = $p7_cells（含时序单元 $p7_flops）"
puts "p7: alpha   = $p7_alpha （vectorless 输入活动率；duty 用工具默认）"

# 与流程的时序报告保持一致：**不设 propagated clock**（本流程无 CTS，流程自己也未设）
# ⇒ 与 §8.13.1 的解析式估计同口径（那边用 liberty 的时钟脚电容、α=1）。
set_power_activity -input -activity $p7_alpha
puts "p7: set_power_activity -input -activity $p7_alpha 已执行"

# 覆盖率：本机无 report_activity_annotation（2026-09-30 实测）⇒ 如实记，不编
if {[llength [info commands report_activity_annotation]]} {
  report_activity_annotation > $p7_rep/p7_activity_annotation_a${p7_alpha}.rpt
  puts "p7: 覆盖率 → $p7_rep/p7_activity_annotation_a${p7_alpha}.rpt"
} else {
  puts "p7: 本机 OpenSTA 无 report_activity_annotation ⇒ 未记录标注覆盖率（如实记，见 §8.13.7）"
}

report_power > $p7_rep/p7_power_a${p7_alpha}.rpt

# 把报告原文打到 stdout，便于直接贴回来
set fh [open $p7_rep/p7_power_a${p7_alpha}.rpt r]
set txt [read $fh]
close $fh
puts "===== 报告原文：p7_power_a${p7_alpha}.rpt ====="
puts $txt
if {[string length [string trim $txt]] == 0} {
  error "report_power 产出为空 ⇒ 停（上次踩过：网表变量未定义时就是空文件）"
}

# 可选（P7_PROBE=1）：探"全网上平坦 α"变体在本机是否可用。
# 只对**单个对象**试语法（不铺开几万个），成功/失败都打印原文 ⇒ 依据来自本机实测。
if {[info exists ::env(P7_PROBE)]} {
  # 只用**便宜**的对象试探语法（顶层端口/端口上的网/网上的 pin），不铺开 -hier *
  set one_port [lrange [get_ports *] 0 0]
  set one_net  [lrange [get_nets -of_objects [get_ports *]] 0 0]
  set one_pin  [lrange [get_pins -of_objects [get_nets -of_objects [get_ports *]]] 0 0]
  puts "===== set_power_activity 变体探针（单元素；仅探语法，不看数值）====="
  foreach probe [list \
      [list -input] \
      [list -ports $one_port] \
      [list -pins $one_pin] \
      [list -net $one_net] \
      [list -nets $one_net]] {
    set cmd [concat set_power_activity $probe [list -activity 0.1 -duty 0.5]]
    if {[catch {eval $cmd} msg]} {
      puts "探针 [join $probe { }] ⇒ 失败：$msg"
    } else {
      puts "探针 [join $probe { }] ⇒ 可用"
    }
  }
  puts "===== 探针结束（把这段贴回来即可判定能否做「全网上平坦 α」变体）====="
}

exit
