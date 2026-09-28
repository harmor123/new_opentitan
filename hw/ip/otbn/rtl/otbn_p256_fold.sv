// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// P-256 Fold Unit —— P2 独立单元（contribution 2.pdf §5 / §6 / §8 / §10.2–§10.3）
//
// 契约（Step 1：先写死，再写 RTL；每一条都有对应 assert 或注释）
//  * F        : signed 260-bit accumulator；c3 由 MAC shift-out 残量**直接 seed**
//               （「F←H，直接接线写入，不使用 CPA」，§8 行 c3）。               §6 第 13 页；§8
//  * h0..h7   : 256-bit 临时寄存器；c9 从 BN-MAC **当拍新结果**旁路采样
//               （不是 acc_q，也不是前一拍 ACC），不从 WDR 另开端口。            §6 第 13 页；§10.2
//  * LL       : 128-bit；c12 采样 MAC shift-out **低半字**。                      §6 第 13 页
//  * ACC130   : 130-bit；c15 采 shift-out 之后 ACC 的更新值，**此后保持**。        §10.2
//  * L0       : 258-bit = {ACC[129:0], LL[127:0]}，整体扩到 260 位进 CPA
//               —— **绝不截断 ACC[129:128]**。                                  §6 第 14 页
//  * k / x    : c19 时 k = signed'(F[259:256])、x = F[255:0]
//               （「实现时 k 是 F[259:256] 的 signed 4-bit 解释，x 是 F[255:0]」）
//               ⇒ 该拍 operand mux 把 CPA 第一输入从 F 切为 **zero-extended x**。 §5 第 25–27 行；§6 第 13 页
//  * T        : T = x + k·d，12 项 `k·d` 编译期常量 LUT（最大 signed 228 bit）；
//               不占用 64×64 multiplier、不送回 BN-MAC。                        §5 第 29–30 行
//  * 校正     : 「先用已注册 T 的符号选加 p 或减 p，再根据 candidate 的符号选择写回。
//               **无需另放一个全宽比较器**」；260-bit signed 加法，不用 unsigned borrow。§5 第 33–38 行
//  * 拼接方向 : 文档表为 low-word-first，与 SV {high,...,low} **相反**。            §10.3 静态检查第 4 条
//  * 静态检查 : 唯一 260-bit CPA（加/减共享 + 输入反相）；无 barrel shifter；
//               无新增通用 multiplier；有符号 cast 与常量宽度显式。              §6 第 14 页；§10.3
//
// 调度（§8 表 c0…c21；与模型 `light()` 的 fold trace 同号同序，完成周期固定 22 拍）
//   c0–c2 : idle（高部前 3 次乘；Fold Unit 无操作）
//   c3    : F ← H = {MAC[127:0], 128'b0}（直接 seed，不经 CPA）
//   c4–c8 : hold
//   c9    : h0..h7 ← mac_result_pre_so[255:0]（当拍 MAC 新结果，统一捕获全部 256 位）
//   c10   : F ← F + 2A      c11: F ← F + 2Bv    c12: F ← F + P0（并保存 LL128）
//   c13   : F ← F + P1      c14: F ← F − M0     c15: F ← F − M1（L0 可从 ACC130、LL128 重建）
//   c16   : F ← F − M2      c17: F ← F − M3    （F = H + C′）
//   c18   : F ← F + L0（258 bit 零扩到 260）   → R′ 就绪
//   c19   : k ← signed'(F[259:256])；F ← x + k·d，x = F[255:0]（−p < T < 2p）
//   c20   : 一次条件 ±p（T<0 → +p；T≥0 → −p，candidate<0 则保留 T）→ result 在 F 中就绪
//   c21   : 唯一 wd 写回（abort/error 抑制；fused instruction 退休不在本单元）
//
// P2 范围说明：本单元是**独立单元级**验证对象（PDF §11 P2 第一步：先按固定周期注入验证单元）。
//             不含完整性编码 / URND wiping / 安全清理阶段（§10.6，属 P7）；清理若需独立占拍按
//             §9 行 29–31 另计，不得与功能模型同拍。但保留 abort/wipe 的暂存清零与写回抑制
//             （P2 Step 7 的断言依赖它）。
// 依赖：无（纯 SV；P3 再按 §10.5 接入 otbn_pkg / 控制器 / WDR 写回仲裁）。

module otbn_p256_fold #(
  parameter int unsigned W = 260,  // 累加器宽度（§5：「采用 signed 260 bit」）
  parameter int unsigned AW = 130  // ACC 低部 tap 宽度（§10.2：「low ACC tap 至少 130」）
) (
  input  logic                clk_i,
  input  logic                rst_ni,

  // 控制
  input  logic                start_i,  // 一拍脉冲：本拍进入 c0（内部暂存已清）
  input  logic                abort_i,  // 错误/取消：清暂存，且**不产生**旧结果写回
  input  logic                wipe_i,   // 安全清理请求：清 F/h/LL/ACC130

  // MAC 内部 tap（§10.2 建议名；P2 由 testbench 按固定周期注入）
  input  logic [255:0]        mac_result_pre_so_i, // shift-out 选择**之前**的 MAC 加法器输出（当拍新结果）
  input  logic [AW-1:0]       mac_acc_after_so_i,  // shift-out **之后** ACC 的更新值（c15 采）

  // 观测/控制输出
  output logic                busy_o,
  output logic [4:0]          cycle_o,     // c0..c21；未运行 = 5'd31
  output logic signed [W-1:0] f_o,         // 当前 F（scoreboard 逐拍比对对象）
  output logic [255:0]        h_o,         // h0..h7（c9 捕获）
  output logic [127:0]        ll_o,        // LL（c12 捕获）
  output logic [AW-1:0]       acc130_o,    // ACC130（c15 捕获，此后保持）
  output logic signed [3:0]   k_o,         // c19 的 k（−4…7）
  output logic                wd_valid_o,  // c21 唯一写回脉冲
  output logic [255:0]        wd_o         // result（< p < 2^256）
);

  // ---------------------------------------------------------------------------
  // 常量（由 run_dir/unit/gen_kd_sv.py 从模型 p256_fold_model.py 生成并逐位自检，不手工抄写）
  // ---------------------------------------------------------------------------
  localparam logic [W-1:0] P260  = W'(260'h0ffffffff00000001000000000000000000000000ffffffffffffffffffffffff);
  // 边界常量必须声明成 **signed**：SV 的混合符号比较按无符号做 ⇒ 若这里写成 logic [W:0]，
  // `$signed(cpa_ext) > NEG_P` 会退化成无符号比较（T=0 时 0 > 2^261−p 为假 ⇒ 断言误报）。
  localparam logic signed [W:0] NEG_P = -$signed({1'b0, P260});   // −p（261-bit signed）
  localparam logic signed [W:0] TWO_P = 2*$signed({1'b0, P260});  //  2p（261-bit signed）

  // KD LUT：k = −4…7 的 (k·d) & MASKW，260-bit 二补码；case 标签即 k 的 4-bit 位型
  localparam logic [W-1:0] KD_00 = W'(260'hffffffffc00000004000000000000000000000003fffffffffffffffffffffffc); // k=-4
  localparam logic [W-1:0] KD_01 = W'(260'hffffffffd00000003000000000000000000000002fffffffffffffffffffffffd); // k=-3
  localparam logic [W-1:0] KD_02 = W'(260'hffffffffe00000002000000000000000000000001fffffffffffffffffffffffe); // k=-2
  localparam logic [W-1:0] KD_03 = W'(260'hfffffffff00000001000000000000000000000000ffffffffffffffffffffffff); // k=-1
  localparam logic [W-1:0] KD_04 = W'(260'h00000000000000000000000000000000000000000000000000000000000000000); // k= 0
  localparam logic [W-1:0] KD_05 = W'(260'h000000000fffffffeffffffffffffffffffffffff000000000000000000000001); // k= 1
  localparam logic [W-1:0] KD_06 = W'(260'h000000001fffffffdfffffffffffffffffffffffe000000000000000000000002); // k= 2
  localparam logic [W-1:0] KD_07 = W'(260'h000000002fffffffcfffffffffffffffffffffffd000000000000000000000003); // k= 3
  localparam logic [W-1:0] KD_08 = W'(260'h000000003fffffffbfffffffffffffffffffffffc000000000000000000000004); // k= 4
  localparam logic [W-1:0] KD_09 = W'(260'h000000004fffffffafffffffffffffffffffffffb000000000000000000000005); // k= 5
  localparam logic [W-1:0] KD_10 = W'(260'h000000005fffffff9fffffffffffffffffffffffa000000000000000000000006); // k= 6
  localparam logic [W-1:0] KD_11 = W'(260'h000000006fffffff8fffffffffffffffffffffff9000000000000000000000007); // k= 7

  // ---------------------------------------------------------------------------
  // 状态
  // ---------------------------------------------------------------------------
  logic [4:0]          cycle_q, cycle_d;
  logic                busy_q, busy_d;

  logic signed [W-1:0] f_q, f_d;
  logic [255:0]        h_q, h_d;         // h0..h7（word j = h_q[32*j +: 32]）
  logic [127:0]        ll_q, ll_d;
  logic [AW-1:0]       acc130_q, acc130_d;
  logic signed [3:0]   k_q, k_d;

  logic                wd_valid_q, wd_valid_d;
  logic [255:0]        wd_q, wd_d;

  logic [3:0]          k_c19;            // c19 的 k 位型 = F[259:256]

  assign busy_o     = busy_q;
  assign cycle_o    = busy_q ? cycle_q : 5'd31;
  assign f_o        = f_q;
  assign h_o        = h_q;
  assign ll_o       = ll_q;
  assign acc130_o   = acc130_q;
  assign k_o        = k_q;
  assign wd_valid_o = wd_valid_q;
  assign wd_o       = wd_q;

  assign k_c19      = f_q[W-1 -: 4];

  // ---------------------------------------------------------------------------
  // 前端 row mux 的行向量（§6 第 14 页：「选择 2A、2Bv、P0、P1、M0…M3；另选 L0、k·d、p」）
  //   LANES 表是 low-word-first（LANES['A'] = [None,None,None,3,4,5,6,7] ⇒ 低 3 字为零），
  //   SV 拼接必须反过来写 {high, ..., low}（§10.3 静态检查第 4 条）。
  //   全部为常量位置的 h 字拼接（纯 wiring），**无 barrel shifter**。
  // ---------------------------------------------------------------------------
  logic [255:0] v_a, v_b, v_p0, v_p1, v_m0, v_m1, v_m2, v_m3;
  logic [W-1:0] t_2a, t_2b, t_p0, t_p1, t_n0, t_n1, t_n2, t_n3, t_l0;

  assign v_a  = {h_q[32*7 +: 32], h_q[32*6 +: 32], h_q[32*5 +: 32], h_q[32*4 +: 32],
                 h_q[32*3 +: 32], 32'b0, 32'b0, 32'b0};
  assign v_b  = {32'b0, h_q[32*7 +: 32], h_q[32*6 +: 32], h_q[32*5 +: 32],
                 h_q[32*4 +: 32], 32'b0, 32'b0, 32'b0};
  assign v_p0 = {h_q[32*0 +: 32], h_q[32*5 +: 32], h_q[32*7 +: 32], h_q[32*6 +: 32],
                 h_q[32*5 +: 32], h_q[32*2 +: 32], h_q[32*1 +: 32], h_q[32*0 +: 32]};
  assign v_p1 = {h_q[32*7 +: 32], h_q[32*6 +: 32], 32'b0, 32'b0,
                 32'b0, h_q[32*3 +: 32], h_q[32*2 +: 32], h_q[32*1 +: 32]};
  assign v_m0 = {h_q[32*2 +: 32], h_q[32*0 +: 32], h_q[32*2 +: 32], h_q[32*1 +: 32],
                 h_q[32*0 +: 32], h_q[32*5 +: 32], h_q[32*4 +: 32], h_q[32*3 +: 32]};
  assign v_m1 = {h_q[32*3 +: 32], h_q[32*1 +: 32], h_q[32*3 +: 32], h_q[32*2 +: 32],
                 h_q[32*1 +: 32], h_q[32*6 +: 32], h_q[32*5 +: 32], h_q[32*4 +: 32]};
  assign v_m2 = {h_q[32*4 +: 32], 32'b0, 32'b0, 32'b0,
                 h_q[32*7 +: 32], h_q[32*7 +: 32], h_q[32*6 +: 32], h_q[32*5 +: 32]};
  assign v_m3 = {h_q[32*5 +: 32], 32'b0, 32'b0, 32'b0,
                 32'b0, 32'b0, h_q[32*7 +: 32], h_q[32*6 +: 32]};

  assign t_2a = {4'b0, v_a} << 1;   // 2A（常量左移 1；bit256 可能为 1）
  assign t_2b = {4'b0, v_b} << 1;   // 2Bv
  assign t_p0 = {4'b0, v_p0};       // P0
  assign t_p1 = {4'b0, v_p1};       // P1
  assign t_n0 = {4'b0, v_m0};       // −M0 = ~t_n0 + 1（由 CPA 输入反相 + 进位完成，不另设减法器）
  assign t_n1 = {4'b0, v_m1};
  assign t_n2 = {4'b0, v_m2};
  assign t_n3 = {4'b0, v_m3};

  // L0 = {ACC[129:0], LL[127:0]}（258 bit）零扩到 260：**绝不截断 ACC[129:128]**
  assign t_l0 = {{(W-AW-128){1'b0}}, acc130_q, ll_q};

  // k·d 常量选择网络（12 项；k = −8…−5 给安全默认值，并由 A_k_in_range 命中）
  function automatic logic [W-1:0] kd_lut(input logic signed [3:0] k);
    unique case (k)
      4'hc:    kd_lut = KD_00;  // −4
      4'hd:    kd_lut = KD_01;  // −3
      4'he:    kd_lut = KD_02;  // −2
      4'hf:    kd_lut = KD_03;  // −1
      4'h0:    kd_lut = KD_04;  //  0
      4'h1:    kd_lut = KD_05;  //  1
      4'h2:    kd_lut = KD_06;  //  2
      4'h3:    kd_lut = KD_07;  //  3
      4'h4:    kd_lut = KD_08;  //  4
      4'h5:    kd_lut = KD_09;  //  5
      4'h6:    kd_lut = KD_10;  //  6
      4'h7:    kd_lut = KD_11;  //  7
      default: kd_lut = '0;     // 安全默认：不得依赖 x 获得不受控优化
    endcase
  endfunction

  // ---------------------------------------------------------------------------
  // 唯一 260-bit CPA：operand mux（row mux + x+k·d 的 F→zero-extended x 切换 + ±p）
  // ---------------------------------------------------------------------------
  logic [W-1:0] cpa_a, cpa_b;
  logic         cpa_sub;   // 1 = 减：第二输入取反 + 进位 1（与加法共享同一加法器）

  always_comb begin
    cpa_a   = f_q;
    cpa_b   = '0;
    cpa_sub = 1'b0;
    if (busy_q) begin
      unique case (cycle_q)
        5'd10:   cpa_b = t_2a;                             // F ← F + 2A
        5'd11:   cpa_b = t_2b;                             // F ← F + 2Bv
        5'd12:   cpa_b = t_p0;                             // F ← F + P0
        5'd13:   cpa_b = t_p1;                             // F ← F + P1
        5'd14:   begin cpa_b = ~t_n0; cpa_sub = 1'b1; end  // F ← F − M0
        5'd15:   begin cpa_b = ~t_n1; cpa_sub = 1'b1; end  // F ← F − M1
        5'd16:   begin cpa_b = ~t_n2; cpa_sub = 1'b1; end  // F ← F − M2
        5'd17:   begin cpa_b = ~t_n3; cpa_sub = 1'b1; end  // F ← F − M3
        5'd18:   cpa_b = t_l0;                             // F ← F + L0
        5'd19:   begin                                     // T ← x + k·d，x = zero-extended F[255:0]
          cpa_a = {{(W-256){1'b0}}, f_q[255:0]};
          cpa_b = kd_lut($signed(k_c19));
        end
        5'd20:   begin                                     // candidate ← T ± p（第二输入在 mux 里取 ±p；无全宽比较器）
          cpa_b   = f_q[W-1] ? P260 : ~P260;               // T<0 ⇒ +p；T≥0 ⇒ −p（反相 + 进位）
          cpa_sub = ~f_q[W-1];
        end
        default: ;
      endcase
    end
  end

  // 精确和（W+1 位有符号）：仅用于「落在 signed 260 范围内」的组合检查与 candidate 符号
  logic [W:0] cpa_ext;
  assign cpa_ext = {cpa_a[W-1], cpa_a} + {cpa_b[W-1], cpa_b} + {{W{1'b0}}, cpa_sub};

  // ---------------------------------------------------------------------------
  // 组合次态
  // ---------------------------------------------------------------------------
  always_comb begin
    cycle_d    = cycle_q;
    busy_d     = busy_q;
    f_d        = f_q;
    h_d        = h_q;
    ll_d       = ll_q;
    acc130_d   = acc130_q;
    k_d        = k_q;
    wd_valid_d = 1'b0;
    wd_d       = wd_q;

    if (start_i) begin
      // 新一次操作：进入 c0；清掉上一次的全部暂存与提交标志
      // ⇒「第二次操作读不到第一次的 F/h/LL」（P2 Step 7）
      cycle_d    = 5'd0;
      busy_d     = 1'b1;
      f_d        = '0;
      h_d        = '0;
      ll_d       = '0;
      acc130_d   = '0;
      k_d        = '0;
      wd_valid_d = 1'b0;
    end else if (busy_q) begin
      cycle_d = cycle_q + 5'd1;
      if (cycle_q == 5'd21) begin
        busy_d = 1'b0;                                            // 完成周期固定：c0…c21 共 22 拍
      end
      if (cycle_q == 5'd19) begin
        k_d = k_c19;                                              // k = signed'(F[259:256])
      end
      unique case (cycle_q)
        5'd3:  f_d      = {4'b0, mac_result_pre_so_i[127:0], 128'b0}; // seed H（直接接线，不经 CPA）
        5'd9:  h_d      = mac_result_pre_so_i;                        // 当拍 MAC 新结果 → h0..h7
        5'd10, 5'd11, 5'd13, 5'd14, 5'd16, 5'd17, 5'd18, 5'd19:
               f_d      = cpa_ext[W-1:0];                             // 行累加 / +L0 / x+k·d
        5'd12: begin                                                  // 同拍两件事必须写在**同一个 item**（case 首个匹配项胜出）
          ll_d = mac_result_pre_so_i[127:0];                          // shift-out 前低 128 位
          f_d  = cpa_ext[W-1:0];                                      // F ← F + P0
        end
        5'd15: begin
          acc130_d = mac_acc_after_so_i;                              // shift-out 后 ACC 更新值
          f_d      = cpa_ext[W-1:0];                                  // F ← F − M1
        end
        5'd20: f_d      = (f_q[W-1] || !cpa_ext[W-1]) ? cpa_ext[W-1:0] : f_q; // 一次条件 ±p
        5'd21: begin                                                  // 唯一 wd 写回
          wd_d       = f_q[255:0];
          wd_valid_d = ~abort_i;
        end
        default: ;
      endcase
    end else begin
      cycle_d = 5'd31;                                                // idle 标记
    end

    // 错误 / 取消 / 清理：清暂存，且不得提交半成品（P2 Step 7）
    if (abort_i || wipe_i) begin
      f_d        = '0;
      h_d        = '0;
      ll_d       = '0;
      acc130_d   = '0;
      k_d        = '0;
      wd_valid_d = 1'b0;
      if (abort_i) begin
        busy_d  = 1'b0;
        cycle_d = 5'd31;
      end
    end

    // ---- 断言（与次态**同一个 always_comb**）----
    // 说明（如实记录）：把断言并进本块，**并没有**改变「采样晚一拍」的现象——该现象的根因在
    // testbench 的时钟纪律（必须先在低电平 eval 让输入传播、再抬沿；见 TB 的 tick() 注释与
    // unit/otbn_tap_probe 结构分叉实验）。保留这种写法是因为它在断言处**看不到**该现象：
    // 同一块里断言读到的 `*_d` 与 flop 提交的是同一批值，而分块读时两者可能不一致。

    // Step 3：c3 / c9 / c12 采样点（正面；三条各自独立命名）
    if (busy_q && (cycle_q == 5'd3)) begin
    A_c3_H_no_off_by_one: assert (f_d == {4'b0, mac_result_pre_so_i[127:0], 128'b0})
      else $error("A_c3_H_no_off_by_one: c3 未按 {MAC[127:0],128'b0} seed F");
    end
    if (busy_q && (cycle_q == 5'd9)) begin
    A_c9_high_no_off_by_one: assert (h_d == mac_result_pre_so_i)
      else $error("A_c9_high_no_off_by_one: c9 未采当拍 MAC 新结果");
    end
    if (busy_q && (cycle_q == 5'd12)) begin
    A_c12_LL_no_off_by_one: assert (ll_d == {128'b0, mac_result_pre_so_i[127:0]})
      else $error("A_c12_LL_no_off_by_one: c12 未采 shift-out 前低 128 位");
    end

    // Step 4：L0 拼接（258 bit）不得截断 ACC[129:128]；ACC130 在 c15 之后保持
    if (busy_q && (cycle_q == 5'd18)) begin
    A_L0_no_truncate: assert (cpa_b == {{(W-AW-128){1'b0}}, acc130_q, ll_q})
      else $error("A_L0_no_truncate: L0 未按 {ACC[129:0],LL[127:0]} 零扩到 260");
    end
    if (busy_q && (cycle_q > 5'd15) && (cycle_q <= 5'd20)) begin
    A_ACC130_hold: assert (acc130_d == acc130_q)
      else $error("A_ACC130_hold: c15 之后 ACC130 被改写");
    end

    // F 的 signed 260-bit 范围：261 位精确和的最高两位相同（无溢出 / 下溢）
    if (busy_q && (cycle_q >= 5'd10) && (cycle_q <= 5'd20)) begin
    A_F_signed260_no_overflow: assert (cpa_ext[W] == cpa_ext[W-1])
      else $error("A_F_signed260_no_overflow: 精确和超出 signed 260 位");
    end

    // c19 的 k 合法域（LUT 只覆盖 −4…7；−8…−5 不得出现）
    if (busy_q && (cycle_q == 5'd19)) begin
    A_k_in_range: assert (($signed(k_c19) >= -4) && ($signed(k_c19) <= 7))
      else $error("A_k_in_range: k 落在 LUT 未覆盖的 −8…−5");
    end

    // c19 结果范围：−p < T < 2p
    if (busy_q && (cycle_q == 5'd19)) begin
    A_T_range: assert (($signed(cpa_ext) > NEG_P) && ($signed(cpa_ext) < TWO_P))
      else $error("A_T_range: T 不在 (−p, 2p)");
    end

    // c20：T<0 分支必须得到 candidate ≥ 0（一次 ±p 的完备性，§5）
    if (busy_q && (cycle_q == 5'd20) && f_q[W-1]) begin
    A_neg_T_takes_candidate: assert (!cpa_ext[W-1])
      else $error("A_neg_T_takes_candidate: T<0 的 candidate 仍为负");
    end

    // result 在 F 中就绪且 < p（写回值）
    if (wd_valid_o) begin
    A_result_lt_p: assert ({4'b0, wd_q} < P260)
      else $error("A_result_lt_p: 写回值 ≥ p");
    end

    // Step 7：写回只在 c21 发生一次；abort 抑制写回；wipe 清暂存
    if (wd_valid_d) begin
    A_wd_only_at_c21: assert (busy_q && (cycle_q == 5'd21) && !abort_i)
      else $error("A_wd_only_at_c21: 写回不在 c21 或发生在 abort 拍");
    end
    if (abort_i) begin
    A_no_wd_on_abort: assert (!wd_valid_d)
      else $error("A_no_wd_on_abort: abort 拍仍产生写回");
    end
    if (wipe_i) begin
    A_wipe_clears: assert ((f_d == '0) && (h_d == '0) && (ll_d == '0) && (acc130_d == '0))
      else $error("A_wipe_clears: wipe 未清干净 F/h/LL/ACC130");
    end
    end

  // ---------------------------------------------------------------------------
  // 时序
  // ---------------------------------------------------------------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      cycle_q    <= 5'd31;
      busy_q     <= 1'b0;
      f_q        <= '0;
      h_q        <= '0;
      ll_q       <= '0;
      acc130_q   <= '0;
      k_q        <= '0;
      wd_valid_q <= 1'b0;
      wd_q       <= '0;
    end else begin
      cycle_q    <= cycle_d;
      busy_q     <= busy_d;
      f_q        <= f_d;
      h_q        <= h_d;
      ll_q       <= ll_d;
      acc130_q   <= acc130_d;
      k_q        <= k_d;
      wd_valid_q <= wd_valid_d;
      wd_q       <= wd_d;
    end
  end

endmodule
