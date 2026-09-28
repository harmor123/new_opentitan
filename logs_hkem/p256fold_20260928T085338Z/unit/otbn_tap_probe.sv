// 诊断用最小模块（**不是** P2 的 DUT）：为「锁存是否与呈现同拍」做**结构分叉**实验。
//
// 三条路径锁存同一个量（`{4'b0, tap_i[127:0], 128'b0}`），差别只在中间有没有 always_comb：
//   路径 1 `cap_direct_o`：端口 → flop（表达式直连端口）
//   路径 2 `cap_comb_o`  ：端口 → always_comb 变量 → flop
//   路径 3 `cap_comb2_o` ：同路径 2，但另有第二个 always_comb 也读该变量（模拟 RTL 里的断言块）
// 另有与 fold unit 相同的计数器（`cnt_q <= cnt_q + 1`，表达式直连）与 busy。
//
// 一次运行即可判定：哪种结构会落后一拍（事实），从而定位 fold unit 采样晚一拍的根因。

module otbn_tap_probe (
  input  logic         clk_i,
  input  logic         rst_ni,
  input  logic         start_i,
  input  logic [255:0] tap_i,
  output logic [255:0] cap_direct_o,
  output logic [255:0] cap_comb_o,
  output logic [255:0] cap_comb2_o,
  output logic [7:0]   cnt_o,
  output logic         busy_o
);

  logic [255:0] cap_direct_q, cap_comb_q, cap_comb2_q;
  logic [255:0] comb_v, comb_v2;
  logic [7:0]   cnt_q;
  logic         busy_q;

  // 路径 1：端口 → flop
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) cap_direct_q <= '0;
    else         cap_direct_q <= {4'b0, tap_i[127:0], 128'b0};
  end

  // 路径 2：端口 → always_comb → flop
  always_comb begin
    comb_v = {4'b0, tap_i[127:0], 128'b0};
  end
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) cap_comb_q <= '0;
    else         cap_comb_q <= comb_v;
  end

  // 路径 3：同路径 2，且第二个 always_comb 也读该变量（模拟 fold unit 的断言块）
  always_comb begin
    comb_v2 = comb_v;
    if (busy_q && (cnt_q == 8'd3)) begin
      A_probe: assert (comb_v2 == comb_v) else $error("probe assert");
    end
  end
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) cap_comb2_q <= '0;
    else         cap_comb2_q <= comb_v2;
  end

  // 计数器 / busy（与 fold unit 同款写法：表达式直连）
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      cnt_q  <= '0;
      busy_q <= 1'b0;
    end else begin
      cnt_q <= cnt_q + 8'd1;
      if (start_i) busy_q <= 1'b1;
    end
  end

  assign cap_direct_o = cap_direct_q;
  assign cap_comb_o   = cap_comb_q;
  assign cap_comb2_o  = cap_comb2_q;
  assign cnt_o        = cnt_q;
  assign busy_o       = busy_q;

endmodule
