// 诊断用最小模块（**不是** P2 的 DUT）：只做两件事——每拍无条件把宽输入 `tap_i` 锁存，
// 以及把计数器 +1。用途：用**独立于 fold unit** 的实验，确定「TB 在第 k 拍呈现的 tap」
// 在 Verilator 流程里是第 k 拍被锁存（对齐）还是第 k+1 拍（滞后）。
//
// 事实来源（Linux 实跑）：P2 单元 TB 里，DUT 在 c3 采到的 seed 等于 `pre_so[2]`
// （即"上一拍呈现的 tap"）。本模块用来判断这是**流程性质**还是 fold unit 自身的问题。

module otbn_tap_probe (
  input  logic         clk_i,
  input  logic         rst_ni,
  input  logic         start_i,
  input  logic [255:0] tap_i,
  output logic [255:0] cap_o,    // 每拍锁存的 tap
  output logic [7:0]   cnt_o,    // 每拍 +1
  output logic         busy_o
);

  logic [255:0] cap_q;
  logic [7:0]   cnt_q;
  logic         busy_q;

  assign cap_o  = cap_q;
  assign cnt_o  = cnt_q;
  assign busy_o = busy_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      cap_q  <= '0;
      cnt_q  <= '0;
      busy_q <= 1'b0;
    end else begin
      cap_q  <= tap_i;               // 无条件锁存：本拍沿锁存本拍呈现的 tap
      cnt_q  <= cnt_q + 8'd1;
      if (start_i) busy_q <= 1'b1;
    end
  end

endmodule
