// P7 Step 6 代价探针：**2 级** 3:2 压缩（carry-save）+ 260 位 carry 状态（跨拍保留）+ 末级 CPA。
// 端口与 ref 模块完全相同 ⇒ 相对 `p7_cpa2_ref` 的增量 = **2 个 260 位 CSA 行 + 1 个 260 位寄存器** ✓
// —— 即 §15.1 的 A2「2 级复用 CSA + CPA」里的**新增硬件**。

module p7_csa2_cost #(
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

  // 第 1 级：{a,b,c} → {s1,c1}
  wire [W-1:0] s1 = a_i ^ b_i ^ c_i;
  wire [W-1:0] c1 = (a_i & b_i) | (a_i & c_i) | (b_i & c_i);

  // 第 2 级：{s1,c1,d} → {s2,c2}
  wire [W-1:0] s2 = s1 ^ c1 ^ d_i;
  wire [W-1:0] c2 = (s1 & c1) | (s1 & d_i) | (c1 & d_i);

  reg  [W-1:0] s_q;
  reg  [W-1:0] c_q;

  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      s_q <= {W{1'b0}};
      c_q <= {W{1'b0}};
    end else if (en_i) begin
      s_q <= s2;
      c_q <= c2;
    end
  end

  // 末级 CPA（2 项，与 csa1_cost 相同形状）
  assign sum_o   = s_q + {c_q[W-2:0], 1'b0};
  assign carry_o = c_q;

endmodule
