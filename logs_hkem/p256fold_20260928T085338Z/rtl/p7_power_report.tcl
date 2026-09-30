# P7 Step 9 补充：用流程自带的 OpenSTA 对**已有**的 `.sta.v` 网表出 `report_power`（vectorless）。
#
# 目的：**独立工具、同一 liberty、同一网表、同一 α** 校 §8.13.1 的解析式估计（A 档）。
#       输出形状与仓库 DC 流程同构：net / int / leak + units（`hw/syn/tools/dc/parse-syn-report.py` 解析的就是这四项）。
#
# 两条实测教训（2026-09-30，都踩过）：
#   * `lr_synth_sta_netlist_out` / `lr_synth_sdc_file_out` 由 **sta_common.tcl 自己**定义（且只在
#     LR_SYNTH_TIMING_RUN=1 时）⇒ 检查只能放在 source **之后**，前置条件检查放 source 之前。
#   * **`error` 不会中止 OpenSTA 的执行**（打印完继续跑）⇒ 所有护栏一律 `exit 1`（进程码才是判据）。
#
# 前置（由 p7_power_run.sh 设置；手跑需自己 export）：
#   LR_SYNTH_TIMING_RUN=1 / LR_SYNTH_CELL_LIBRARY_PATH / LR_SYNTH_CELL_LIBRARY_NAME / LR_SYNTH_TOP_MODULE
#   LR_SYNTH_OUT_DIR / LR_SYNTH_STA_NETLIST_OUT / LR_SYNTH_SDC_FILE_OUT / P7_ALPHA / [P7_PROBE=1]
# **必须在 hw/ip/otbn/pre_syn 下执行**（`source ./tcl/sta_common.tcl` 按 cwd 解析）。

proc p7_stage {msg} { puts "p7: STAGE $msg" ; flush stdout }

# --- 前置条件（source 之前）：TIMING_RUN 必须为 1 ---
if {![info exists ::env(LR_SYNTH_TIMING_RUN)] || $::env(LR_SYNTH_TIMING_RUN) != 1} {
  puts "p7: FATAL 需要 LR_SYNTH_TIMING_RUN=1（否则 STA 网表/SDC 流程变量不定义 ⇒ read_verilog 拿空值）"
  exit 1
}

p7_stage "source sta_common（read_liberty / read_verilog / link_design / read_sdc）"
if {[catch {source ./tcl/sta_common.tcl} msg]} {
  puts "p7: FATAL source sta_common.tcl 失败：$msg"
  exit 1
}

# --- 后置条件（source 之后）：流程变量已定义、设计已 link ---
foreach v {lr_synth_sta_netlist_out lr_synth_sdc_file_out lr_synth_cell_library_path lr_synth_top_module} {
  if {![info exists $v]} { puts "p7: FATAL 流程变量 `$v` 未定义" ; exit 1 }
}
foreach cmd {set_power_activity report_power} {
  if {[llength [info commands $cmd]] == 0} { puts "p7: FATAL 本机 OpenSTA 没有 `$cmd`" ; exit 1 }
}
if {[catch {set p7_cells [llength [get_cells -hier *]]} msg]} {
  puts "p7: FATAL get_cells 失败：$msg" ; exit 1
}
if {$p7_cells == 0} { puts "p7: FATAL 设计未 link（get_cells 为空）" ; exit 1 }
if {[catch {set p7_ports [llength [get_ports *]]} msg]} {
  puts "p7: FATAL get_ports 失败：$msg" ; exit 1
}
if {$p7_ports == 0} { puts "p7: FATAL 设计未 link（get_ports 为空）" ; exit 1 }
if {[catch {set p7_flops [llength [get_cells -hier -filter "is_sequential == true"]]} msg]} {
  set p7_flops "n/a（本机 filter：$msg）"
}

set p7_alpha 0.1
if {[info exists ::env(P7_ALPHA)]} { set p7_alpha $::env(P7_ALPHA) }
# P7_NO_ACT=1 ⇒ 跳过 set_power_activity（**只为定位段错误**；口径变成工具默认 ⇒ 文件名与文档都要标）
set p7_tag ""
if {[info exists ::env(P7_NO_ACT)]} { set p7_tag "_noact" }
set p7_rep "$lr_synth_out_dir/reports"

puts "p7: top     = $lr_synth_top_module"
puts "p7: netlist = $lr_synth_sta_netlist_out"
puts "p7: sdc     = $lr_synth_sdc_file_out"
puts "p7: lib     = $lr_synth_cell_library_path"
puts "p7: cells   = $p7_cells（端口 $p7_ports；时序单元 $p7_flops）"
puts "p7: alpha   = $p7_alpha （vectorless 输入活动率；duty 用工具默认）"
flush stdout

# 与流程的时序报告保持一致：**不设 propagated clock**（本流程无 CTS，流程自己也未设）
# ⇒ 与 §8.13.1 的解析式估计同口径（那边用 liberty 的时钟脚电容、α=1）。
p7_stage "set_power_activity -input -activity $p7_alpha"
if {$p7_tag eq "_noact"} {
  puts "p7: P7_NO_ACT=1 ⇒ **不调** set_power_activity（用工具默认 0.1/0.5）——只为定位段错误，口径必须标注 ✗"
} else {
  if {[catch {set_power_activity -input -activity $p7_alpha} msg]} {
    puts "p7: FATAL set_power_activity 失败（不许退回默认活动率）：$msg"
    exit 1
  }
  puts "p7: set_power_activity OK"
}

# 覆盖率：本机 OpenSTA 2.0.17 无 report_activity_annotation（2026-09-30 实测）⇒ 如实记，不编
if {[llength [info commands report_activity_annotation]]} {
  p7_stage "report_activity_annotation"
  if {[catch {report_activity_annotation > $p7_rep/p7_activity_annotation_a${p7_alpha}${p7_tag}.rpt} msg]} {
    puts "p7: 警告 report_activity_annotation 失败：$msg"
  } else {
    puts "p7: 覆盖率 → $p7_rep/p7_activity_annotation_a${p7_alpha}${p7_tag}.rpt"
  }
} else {
  puts "p7: 本机 OpenSTA 无 report_activity_annotation ⇒ 未记录标注覆盖率（如实记，见 §8.13.7）"
}
flush stdout

p7_stage "report_power（大设计可能很慢/可能崩；崩了就靠本行定位）"
if {[catch {report_power > $p7_rep/p7_power_a${p7_alpha}${p7_tag}.rpt} msg]} {
  puts "p7: FATAL report_power 失败：$msg"
  exit 1
}
set fh [open $p7_rep/p7_power_a${p7_alpha}${p7_tag}.rpt r]
set txt [read $fh]
close $fh
puts "p7: report_power OK（$p7_rep/p7_power_a${p7_alpha}${p7_tag}.rpt，[string length $txt] 字符）"
if {[string length [string trim $txt]] == 0} { puts "p7: FATAL 报告为空" ; exit 1 }
puts "===== 报告原文：p7_power_a${p7_alpha}${p7_tag}.rpt ====="
puts $txt

# 单位（判据的判据：数值要能对上 §8.13.1，就必须证明两边单位一致）
if {[llength [info commands report_units]]} {
  if {[catch {report_units > $p7_rep/p7_units_a${p7_alpha}${p7_tag}.rpt} msg]} {
    puts "p7: 警告 report_units 失败：$msg"
  } else {
    set uf [open $p7_rep/p7_units_a${p7_alpha}${p7_tag}.rpt r]
    set ut [read $uf]
    close $uf
    puts "===== 单位原文：p7_units_a${p7_alpha}${p7_tag}.rpt ====="
    puts $ut
  }
} else {
  puts "p7: 本机 OpenSTA 无 report_units ⇒ 单位只能靠交叉验证推（§8.13.7 说明）"
}
puts "p7: DONE"
flush stdout

# 可选（P7_PROBE=1）：探"全网上平坦 α"变体在本机是否可用。
# 只对**单个**对象试语法（不铺开 -hier *）；成功/失败都打印原文 ⇒ 依据来自本机实测。
# 放在 DONE **之后**：探针若崩，不影响判据。
if {[info exists ::env(P7_PROBE)]} {
  puts "===== set_power_activity 变体探针（单元素；仅探语法，不看数值）====="
  if {[catch {
    set one_port [lrange [get_ports *] 0 0]
    set one_net  [lrange [get_nets -of_objects [get_ports *]] 0 0]
    set one_pin  [lrange [get_pins -of_objects [get_nets -of_objects [get_ports *]]] 0 0]
  } msg]} {
    puts "探针取对象失败：$msg"
    set one_port "" ; set one_net "" ; set one_pin ""
  }
  foreach probe [list [list -input] [list -ports $one_port] [list -pins $one_pin] \
                      [list -net $one_net] [list -nets $one_net]] {
    set cmd [concat set_power_activity $probe [list -activity 0.1 -duty 0.5]]
    if {[catch {eval $cmd} msg]} {
      puts "探针 [join $probe { }] ⇒ 失败：$msg"
    } else {
      puts "探针 [join $probe { }] ⇒ 可用"
    }
  }
  puts "===== 探针结束 ====="
  flush stdout
}

exit
