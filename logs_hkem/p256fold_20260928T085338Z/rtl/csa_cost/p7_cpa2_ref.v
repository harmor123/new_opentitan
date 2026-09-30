// P7 Step 6 代价探针：平坦 260 位 CPA，**2 项**相加（= A1 里那个 260 位 CPA 的量级）+ 1 个寄存器。
// 端口与其余三个模块完全相同 ⇒ 与 csa2 的差值给出"增量面积"的**上界** ✓。

module p7_cpa2_ref #(
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
      f_q <= f_q + a_i;               // 2 项平坦 CPA（未用的 b_i/c_i/d_i 会被综合优化掉）
    end
  end

  assign sum_o   = f_q;
  assign carry_o = {W{1'b0}};

endmodule
