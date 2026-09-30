// P7 Step 6 代价探针：**1 级** 3:2 压缩（carry-save）+ 260 位 carry 状态（跨拍保留）+ 末级 CPA。
// 端口与 ref 模块完全相同 ⇒ 相对 `p7_cpa2_ref` 的增量 = **1 个 260 位 CSA 行 + 1 个 260 位寄存器** ✓
// （与 A4「1 级 CSA」同构）。d_i 在此形态里未被使用 ⇒ 会被综合优化掉（不参与面积）✓。

module p7_csa1_cost #(
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

  // 1 级 3:2 压缩：{a,b,c} → {s1,c1}（carry 权重比 sum 高 1 位）
  wire [W-1:0] s1 = a_i ^ b_i ^ c_i;
  wire [W-1:0] c1 = (a_i & b_i) | (a_i & c_i) | (b_i & c_i);

  reg  [W-1:0] s_q;          // 和向量（carry 状态之一，跨拍保留）
  reg  [W-1:0] c_q;          // carry 向量

  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      s_q <= {W{1'b0}};
      c_q <= {W{1'b0}};
    end else if (en_i) begin
      s_q <= s1;
      c_q <= c1;
    end
  end

  // 末级 CPA（2 项，与 csa2_cost 相同形状 ⇒ 两个 CSA 变体可比）
  assign sum_o   = s_q + {c_q[W-2:0], 1'b0};
  assign carry_o = c_q;

endmodule
