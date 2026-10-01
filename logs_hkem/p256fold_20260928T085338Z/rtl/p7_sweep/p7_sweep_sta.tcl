# P7 Step 11「时钟扫描」：对**已综合好的网表**只重跑 OpenSTA，用 create_clock **覆盖**周期。
#
# 目的：给出 PDF §17 清单里的 `sweep_*.csv`（「正/负 slack 修正后记录可达时钟」）。
# 口径：**同一份网表**（8 ns 的 ABC 映射）在不同目标周期下的 slack ⇒ 可达时钟 = slack ≥ 0 的最小周期 ✓；
#       若要严格"按目标周期重新映射"，每个周期都得重综合（本流程 ABC 是单趟映射 ✗）—— 本扫描只反映
#       **同一硬件**的时序余量，这一点写进 CSV 的 note 里，不冒充"每周期都重映射" ✗。
#
# 前置（由 p7_sweep_run.sh 设置）：LR_SYNTH_* 同流程、P7_PERIOD_NS、P7_OUT。
# 必须在 hw/ip/otbn/pre_syn 下执行（`source ./tcl/sta_common.tcl` 按 cwd 解析）。

source ./tcl/sta_common.tcl

foreach v {lr_synth_sta_netlist_out lr_synth_clk_input lr_synth_top_module} {
  if {![info exists $v]} { puts "p7: FATAL 流程变量 `$v` 未定义" ; exit 1 }
}
set p7_p 8.0
if {[info exists ::env(P7_PERIOD_NS)]} { set p7_p $::env(P7_PERIOD_NS) }
set p7_out $::env(P7_OUT)

# 覆盖 SDC 里的时钟：先尝试删掉（若不存在/不支持则静默跳过 ✓），再按扫描点重建
catch {remove_clock [get_clocks $lr_synth_clk_input]}
create_clock -name $lr_synth_clk_input -period $p7_p [get_ports $lr_synth_clk_input]

# **自证**：读回来的周期必须等于扫描点；不等就退出（不许出一行错数据 ✗）
set p7_got [get_property [get_clocks $lr_synth_clk_input] period]
if {[expr {abs($p7_got - $p7_p)}] > 1e-6} {
  puts "p7: FATAL 时钟覆盖未生效（period=$p7_got，期望 $p7_p）⇒ 停，不要拿这份数 ✗"
  exit 1
}
puts "p7: period = $p7_got ns（= 扫描点 ✓ 覆盖已自证）"
flush stdout

set paths [find_timing_paths -group_count 1 -path_group $lr_synth_clk_input]
if {[llength $paths] == 0} { puts "p7: FATAL 拿不到路径" ; exit 1 }
set p [lindex $paths 0]
set fh [open "$p7_out/p7_sweep_result.csv" "w"]
puts $fh "design,period_ns,slack_ns,startpoint,endpoint"
puts $fh [format "%s,%.3f,%.4f,%s,%s" $lr_synth_top_module $p7_p \
              [get_property $p slack] \
              [get_property [get_property $p startpoint] full_name] \
              [get_property [get_property $p endpoint] full_name]]
close $fh
puts "p7: slack = [get_property $p slack] ns ⇒ $p7_out/p7_sweep_result.csv"
exit
