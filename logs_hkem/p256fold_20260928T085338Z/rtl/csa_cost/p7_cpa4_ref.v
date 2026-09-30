// P7 Step 6「双 CSA 决策」代价探针 —— **孤立模块，不进设计**（只为同条件综合出面积）。
//
// 四个模块**端口完全相同**（clk_i / rst_ni / en_i / a_i / b_i / c_i / d_i / sum_o / carry_o，W=260），
// 差别只在"求和结构"：
//
//   p7_cpa4_ref  : 平坦 260 位 CPA，4 项相加 + 1 个 260 位寄存器   ← CPA 侧**上界**
//   p7_cpa2_ref  : 平坦 260 位 CPA，2 项相加 + 1 个 260 位寄存器   ← CPA 侧**下界**（A1 的 CPA 量级）
//   p7_csa1_cost : 1 级 3:2 压缩 + carry 状态 + 末级 CPA          ← 与 A4（1 级 CSA）同构
//   p7_csa2_cost : 2 级 3:2 压缩 + carry 状态 + 末级 CPA          ← §15.1 的 A2「2 级复用 CSA + CPA」
//
// 末级 CPA 三个 CSA 模块都有（把 carry-save 转回二进制）⇒ 在差值里与 ref 的 CPA 抵消 ✓。
// ⇒ **A2 的增量面积** 落在区间 [area(csa2) − area(cpa4_ref), area(csa2) − area(cpa2_ref)] 内
//   （下界对应"CPA 侧本来就是 4 项平坦"的假设，上界对应"CPA 侧是 2 项"的假设）✓。
// 条件与 A1 完全相同（同一 flow 的 tcl、同一 liberty、clk 8000 ps、ABC -D 4000、flatten、同一 SDC 模板）。

module p7_cpa4_ref #(
  parameter integer W = 260
) (
  input  wire         clk_i,
  input  wire         rst_ni,
  input  wire         en_i,
  input  wire [W-1:0] a_i,
  input  wire [W-1:0] b_i,
  input  wire [W-1:0] c_i,
  input  wire [W-1:0] d_i,
  output wire [W-1:0] sum_o,
  output wire [W-1:0] carry_o
);

  reg [W-1:0] f_q;

  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      f_q <= {W{1'b0}};
    end else if (en_i) begin
      f_q <= a_i + b_i + c_i + d_i;   // 平坦 260 位 CPA（4 项）
    end
  end

  assign sum_o   = f_q;
  assign carry_o = {W{1'b0}};

endmodule
