# P7 Step 6 代价探针的 flow 配置（**只用于孤立模块**；与 otbn 的十项条件逐项一致）。
# 由 p7_csa_cost_run.sh 经 LR_SYNTH_CONFIG_FILE 传入（lr_synth_flow_var_setup.tcl:24 source 它）。

# IO 约束（与 otbn_lr_synth_conf.tcl 相同：输出 70%、输入 30%）
set lr_synth_outputs [list {*_o 70.0}]
set lr_synth_inputs  [list {*_i 30.0}]

# 时钟/复位名与时钟周期（8000 ps = 125 MHz，与 A1 相同）
set lr_synth_clk_input clk_i
set lr_synth_rst_input rst_ni
set lr_synth_clk_period 8000.0

# ABC 的加速周期（与 otbn 配置相同 ⇒ ABC 拿到 -D 4000）
set lr_synth_abc_clk_uprate 4000.0
