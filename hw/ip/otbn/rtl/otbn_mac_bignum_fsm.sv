// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

module otbn_mac_bignum_fsm
  import otbn_pkg::*;
#(
  // This enforces that there is an assertion which checks that state_err_o generates an alert.
  parameter bit EnableAlertTriggerSVA = 1,
  parameter bit SecFixMacOpSeq = 1'b0
)
(
  input  logic clk_i,
  input  logic rst_ni,

  input  logic                  start_i,
  input  logic                  mac_en_i,
  input  logic                  is_vec_i,
  input  logic                  is_mod_i,
  input  logic                  is_lane_i,
  // P3：P-256 模式（与 is_vec_i 同时为 1）。本增量只把它透传到 predec_o；P-256 的 28 拍表在
  // 增量③ 加，届时它同时用于选表。
  input  logic                  is_p256_i,
  input  logic [2:0]            lane_index_i,
  input  mac_elen_e             elen_i,
  input  logic [VLEN/QWLEN-1:0] adder_carry_sel_i,
  input  logic                  acc_add_en_i,
  input  logic [1:0]            op_a_qw_sel_i,
  input  logic [2:0]            op_b_elem0_sel_i,
  input  logic [2:0]            op_b_elem1_sel_i,
  input  logic [1:0]            shuffle_offset_i,

  output mac_bignum_contrl_t contrl_o,
  output mac_bignum_predec_t predec_o,
  output logic               is_busy_o,

  input  logic sec_wipe_i,
  output logic state_err_o
);

  import prim_util_pkg::vbits;

  /**
   * The multi-cycle multiplications require dynamic control signals including predecoded signals.
   * This is implemented by stalling the OTBN pipeline and generating the control signals using
   * this internal state machine. When the final result is ready, the pipeline is un-stalled by
   * asserting the valid flag.
   *
   * For security reasons, this FSM is instantiated twice, once in the predecoder and once in BN
   * MAC. All dynamic signals that require predecoding are generated with this FSM in the
   * instruction fetch stage such that they can be flopped. They are then forwarded to the BN MAC
   * which will compare them to the locally generated predecode signals (as expected signals).
   *
   * The following tables show the progression of the "dynamic" control signals for all
   * multi-cycle operations. There are additional control signals which do not change during the
   * execution. Note, for signals marked with a * the start value is randomized based on bits of
   * URND. This shuffles the execution, giving additional protection against SCA.
   *
   * Dynamic control signals for vectorized multiplication (QW = quad word = 64 bits). In lane mode
   * the op_b_elemX_sel signals are overwritten by the FSM based upon decoded signals.
   *
   *
   * | Signal              |     Cycles (0-3)      | Predecoded |
   * |---------------------|-----------------------|------------|
   * | Step                | QW0 | QW1 | QW2 | QW3 |            |
   * |---------------------|-----|-----|-----|-----|------------|
   * | op_a_qw_sel *       |   0 |   1 |   2 |   3 |        yes |
   * | op_b_elem0_sel *    |   0 |   2 |   4 |   6 |        yes |
   * | op_b_elem1_sel *    |   1 |   3 |   5 |   7 |        yes |
   * | acc_qw_sel *        |   0 |   1 |   2 |   3 |        yes |
   * | acc_wr_en_raw       |   1 |   1 |   1 |   0 |         no |
   * | acc_clear_en        |   0 |   0 |   0 |   1 |         no |
   * | acc_merger_en       |   1 |   1 |   1 |   1 |        yes |
   * | mul_shift_en        |   0 |   0 |   0 |   0 |        yes |
   * | add_res_en          |   0 |   0 |   0 |   0 |        yes |
   * | mul_merger_en       |   1 |   1 |   1 |   1 |        yes |
   * | operation_valid_raw |   0 |   0 |   0 |   1 |        yes |
   *
   * Dynamic control signals for Montgomery multiplication (4 chunks processed over 3 cycles each).
   * In lane mode the op_b_elemX_sel signals are overwritten by the FSM based upon decoded signals.
   *
   * | Signal              |                       Cycles (0-11)                    | Predecoded |
   * |---------------------|--------------------------------------------------------|------------|
   * | Processed quad word |        QW0      ||       QW1       || QW2 ||    QW3    |            |
   * | Montgomery cycle    |  C0 |  C1 |  C2 ||  C0 |  C1 |  C2 || ... || ... |  C2 |            |
   * |---------------------|-----|-----|-----||-----|-----|-----||-----||-----|-----|------------|
   * | op_a_qw_sel *       |   0 |   0 |   0 ||   1 |   1 |   1 ||     ||     |   3 |        yes |
   * | op_b_elem0_sel *    |   0 |   0 |   0 ||   2 |   2 |   2 ||     ||     |   6 |        yes |
   * | op_b_elem1_sel *    |   1 |   1 |   1 ||   3 |   3 |   3 ||     ||     |   7 |        yes |
   * | mul_op_a_tmp_sel    |   A | TMP | TMP ||   A | TMP | TMP ||     ||     | TMP |        yes |
   * | mul_op_b_sel        |   B |  Mu |   Q ||   B |  Mu |   Q ||     ||     |   Q |        yes |
   * | tmp_wr_en_raw       |   1 |   1 |   0 ||   1 |   1 |   0 ||     ||     |   0 |         no |
   * | tmp_clear_en        |   0 |   0 |   1 ||   0 |   0 |   1 ||     ||     |   1 |         no |
   * | c_wr_en_raw         |   1 |   0 |   0 ||   1 |   0 |   0 ||     ||     |   0 |         no |
   * | c_clear_en          |   0 |   0 |   1 ||   0 |   0 |   1 ||     ||     |   1 |         no |
   * | acc_qw_sel *        |   0 |   0 |   0 ||   1 |   1 |   1 ||     ||     |   3 |        yes |
   * | acc_wr_en_raw       |   0 |   0 |   1 ||   0 |   0 |   1 ||     ||     |   0 |         no |
   * | acc_clear_en        |   0 |   0 |   0 ||   0 |   0 |   0 ||     ||     |   1 |         no |
   * | mul_add_en          |   0 |   0 |   1 ||   0 |   0 |   1 ||     ||     |   1 |        yes |
   * | c_add_en            |   0 |   0 |   1 ||   0 |   0 |   1 ||     ||     |   1 |        yes |
   * | add_mod_en          |   0 |   0 |   1 ||   0 |   0 |   1 ||     ||     |   1 |        yes |
   * | acc_merger_en       |   0 |   0 |   1 ||   0 |   0 |   1 ||     ||     |   1 |        yes |
   * | mul_shift_en        |   0 |   0 |   0 ||   0 |   0 |   0 ||     ||     |   0 |        yes |
   * | add_res_en          |   0 |   0 |   0 ||   0 |   0 |   0 ||     ||     |   0 |        yes |
   * | mul_merger_en       |   0 |   0 |   0 ||   0 |   0 |   0 ||     ||     |   0 |        yes |
   * | operation_valid_raw |   0 |   0 |   0 ||   0 |   0 |   0 ||     ||     |   1 |        yes |
   *
   * Because these control signal progressions have a repeating character, we generate for all
   * cycles the desired control signal "combinations" in the form of an array of signals. This
   * allows to implement the state machine as a counter which simply picks the required combination
   * based upon the current count from the arrays. We generate the progressions for each type of
   * multiplication (*_reg, *_vec, *_mod) and also separate the predecoded and regular control
   * signals to simplify the flopping of the signals.
   *
   * In the following, the first part generates these signal combinations. The second part then is
   * the actual logic stepping through the cycles.
   */

  /////////////////////
  // Shuffling logic //
  /////////////////////
  // This captures the shuffle offset when an instruction starts and provides the signal generation
  // with the offset value.
  logic [1:0] shuffle_offset_d, shuffle_offset_q;
  logic [1:0] shuffle_offset;

  assign shuffle_offset_d = is_busy_o ? shuffle_offset_q : shuffle_offset_i;

  // Do not shuffle if it is disabled.
  assign shuffle_offset = SecFixMacOpSeq ? 2'b0 : shuffle_offset_d;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      shuffle_offset_q <= '0;
    end else begin
      shuffle_offset_q <= shuffle_offset_d;
    end
  end

  ///////////////////////////////////////////
  // Multi-cycle control signal generation //
  ///////////////////////////////////////////
  localparam mac_bignum_contrl_t ControlDefault = '0;

  typedef struct packed {
    logic [1:0]            op_a_qw_sel;
    logic [2:0]            op_b_elem0_sel;
    logic [2:0]            op_b_elem1_sel;
    logic                  mul_op_a_tmp_sel;
    mac_mul_op_b_sel_e     mul_op_b_sel;
    logic                  mul_add_en;
    logic                  c_add_en;
    logic                  add_mod_en;
    logic [VLEN/QWLEN-1:0] acc_qw_sel;
    logic                  acc_merger_en;
    logic                  mul_shift_en;
    logic                  mul_merger_en;
    logic                  add_res_en;
    logic                  operation_valid_raw;
    // P3：P-256 的三个逐拍字段（本 FSM 内部产生，再拼进对外的 mac_bignum_predec_t）
    logic [1:0]            shift_imm;
    logic                  acc_zero;
    logic                  so128;
  } mac_bignum_predec_dyn_t;

  localparam mac_bignum_predec_dyn_t PredecDynDefault = '{
    op_a_qw_sel:         2'b0,
    op_b_elem0_sel:      3'b0,
    op_b_elem1_sel:      3'b0,
    mul_op_a_tmp_sel:    1'b1,   // Select A as it is blanked
    mul_op_b_sel:        MulOpB,
    mul_add_en:          1'b0,
    c_add_en:            1'b0,
    add_mod_en:          1'b0,
    acc_qw_sel:          '0,
    acc_merger_en:       1'b0,
    mul_shift_en:        1'b0,
    mul_merger_en:       1'b0,
    add_res_en:          1'b0,
    operation_valid_raw: 1'b0,
    // P3 的 P-256 字段：默认全 0（非 P-256 模式不读它们；两个 FSM 实例取值相同 ⇒ 比对不受影响）
    shift_imm:           2'b0,
    acc_zero:            1'b0,
    so128:               1'b0
  };

  localparam int unsigned LatencyVec = 4;
  localparam int unsigned LatencyMod = 12;
  // P3：bn.p256mul 的 28 拍（contribution 2.pdf §8 / §11 P3）。c0–c15 是 16 个 MAC 微步
  // （与官方 mul_modp 的 high-10/low-6 同序），c16–c26 hold，c27 拉 operation_valid_raw（写回/退休）。
  localparam int unsigned LatencyP256 = 28;
  localparam int unsigned LatencyMax = (LatencyP256 > LatencyVec)
                                     ? ((LatencyP256 > LatencyMod) ? LatencyP256 : LatencyMod)
                                     : ((LatencyVec  > LatencyMod) ? LatencyVec  : LatencyMod);

  // The control and expected signals for a regular multiplication
  mac_bignum_contrl_t     contrl_reg;
  mac_bignum_predec_dyn_t predec_dyn_reg;

  always_comb begin
    contrl_reg               = ControlDefault;
    contrl_reg.acc_wr_en_raw = 1'b1;

    predec_dyn_reg                = PredecDynDefault;
    predec_dyn_reg.op_a_qw_sel    = op_a_qw_sel_i;
    predec_dyn_reg.op_b_elem0_sel = op_b_elem0_sel_i;
    predec_dyn_reg.op_b_elem1_sel = op_b_elem1_sel_i;
  end

  // The dynamic control and predecoding signals for all cycles of a vectorized multiplication.
  // See also table above.
  mac_bignum_contrl_t     contrl_vec[LatencyVec];
  mac_bignum_predec_dyn_t predec_vec[LatencyVec];

  logic [1:0] elem_idx_vec[LatencyVec];

  always_comb begin
    contrl_vec = '{default: ControlDefault};
    predec_vec = '{default: PredecDynDefault};

    for (int unsigned cycle = 0; cycle < LatencyVec; cycle++) begin
      elem_idx_vec[cycle] = 2'(cycle) + shuffle_offset;

      contrl_vec[cycle].acc_wr_en_raw  = 1'b1;
      predec_vec[cycle].op_a_qw_sel    = elem_idx_vec[cycle];
      predec_vec[cycle].op_b_elem0_sel = 3'({elem_idx_vec[cycle], 1'b0});
      predec_vec[cycle].op_b_elem1_sel = 3'({elem_idx_vec[cycle], 1'b1});
      predec_vec[cycle].acc_qw_sel     = (VLEN/QWLEN)'(unsigned'(1) << elem_idx_vec[cycle]);
      predec_vec[cycle].acc_merger_en  = 1'b1;
    end

    // Disable write enable for ACC and clear ACC in last cycle
    contrl_vec[3].acc_wr_en_raw = 1'b0;
    contrl_vec[3].acc_clear_en  = 1'b1;
  end

  // The dynamic control and predecoding signals for the 3 Montgomery cycles as well as all 12
  // execution cycles. See also table above.
  localparam int unsigned LatencyMontgMul = 3;

  mac_bignum_contrl_t     contrl_mod_mul[LatencyMontgMul];
  mac_bignum_predec_dyn_t predec_mod_mul[LatencyMontgMul];
  mac_bignum_contrl_t     contrl_mod[LatencyMod];
  mac_bignum_predec_dyn_t predec_mod[LatencyMod];

  logic [1:0] elem_idx_mod[LatencyMod];

  always_comb begin
    contrl_mod_mul = '{default: ControlDefault};
    predec_mod_mul = '{default: PredecDynDefault};

    // First, construct the signals for the 3 Montgomery multiplication cycles. This pattern is
    // then repeated 4 times to process all 8 vector elements (2 at the same time).
    // Cycle 0
    contrl_mod_mul[0].tmp_wr_en_raw    = 1'b1;
    contrl_mod_mul[0].c_wr_en_raw      = 1'b1;
    // Cycle 1
    contrl_mod_mul[1].tmp_wr_en_raw    = 1'b1;
    predec_mod_mul[1].mul_op_a_tmp_sel = 1'b0;
    predec_mod_mul[1].mul_op_b_sel     = MulOpMu;
    // Cycle 2
    contrl_mod_mul[2].acc_wr_en_raw    = 1'b1;
    contrl_mod_mul[2].tmp_clear_en     = 1'b1; // Clear TMP with randomness
    contrl_mod_mul[2].c_clear_en       = 1'b1; // Clear C with randomness
    predec_mod_mul[2].mul_op_a_tmp_sel = 1'b0;
    predec_mod_mul[2].mul_op_b_sel     = MulOpq;
    predec_mod_mul[2].mul_add_en       = 1'b1;
    predec_mod_mul[2].c_add_en         = 1'b1;
    predec_mod_mul[2].add_mod_en       = 1'b1;
    predec_mod_mul[2].acc_merger_en    = 1'b1;

    // Construct the 4 * 3 = 12 cycles and set the correct qword selection
    for (int unsigned cycle = 0; cycle < LatencyMod; cycle++) begin
      elem_idx_mod[cycle] = 2'(cycle / LatencyMontgMul) + shuffle_offset;

      contrl_mod[cycle]                = contrl_mod_mul[cycle % LatencyMontgMul];
      predec_mod[cycle]                = predec_mod_mul[cycle % LatencyMontgMul];
      predec_mod[cycle].op_a_qw_sel    = elem_idx_mod[cycle];
      predec_mod[cycle].op_b_elem0_sel = 3'({elem_idx_mod[cycle], 1'b0});
      predec_mod[cycle].op_b_elem1_sel = 3'({elem_idx_mod[cycle], 1'b1});
      predec_mod[cycle].acc_qw_sel     = (VLEN/QWLEN)'(unsigned'(1)) << elem_idx_mod[cycle];
    end

    // Clear ACC in the last cycle with randomness
    contrl_mod[LatencyMod - 1].acc_clear_en = 1'b1;
  end

  // P-256 的 16 个 MAC 微步（c0…c15）。每项 8 bit = {a_qw[1:0], b_qw[1:0], shift_imm[1:0],
  // zero_acc, so128}：含义见 MAC_STEPS 的转写——把 a 的第 a_qw 个 64-bit limb 与 b 的第 b_qw 个
  // limb 相乘、左移 64·shift_imm，累加进 ACC；zero_acc=1 表示本次累加前先清零 ACC（bn.mulqacc 的 .z）；
  // so128=1 表示本拍 shift-out 128 位（ACC 取加法器输出的高 128 位，低 128 位留给 Fold Unit 采）。
  // 由 run_dir/rtl/p3_p256_table_check.py 从本文件解析回来与模型 MAC_STEPS 逐项核对（不手抄）。
  localparam int unsigned P256NumSteps = 16;
  localparam logic [7:0]  P256Steps[P256NumSteps] = '{
    8'b00_11_01_1_0,  // c0  : a0·b3 << 64, .z
    8'b01_10_01_0_0,  // c1  : a1·b2 << 64
    8'b10_01_01_0_0,  // c2  : a2·b1 << 64
    8'b11_00_01_0_1,  // c3  : a3·b0 << 64, shift-out 128（seed H）
    8'b01_11_00_0_0,  // c4  : a1·b3
    8'b10_10_00_0_0,  // c5  : a2·b2
    8'b11_01_00_0_0,  // c6  : a3·b1
    8'b10_11_01_0_0,  // c7  : a2·b3 << 64
    8'b11_10_01_0_0,  // c8  : a3·b2 << 64
    8'b11_11_10_0_0,  // c9  : a3·b3 << 128（capture high）
    8'b00_00_00_1_0,  // c10 : a0·b0, .z
    8'b00_01_01_0_0,  // c11 : a0·b1 << 64
    8'b01_00_01_0_1,  // c12 : a1·b0 << 64, shift-out 128（capture LL）
    8'b00_10_00_0_0,  // c13 : a0·b2
    8'b01_01_00_0_0,  // c14 : a1·b1
    8'b10_00_00_0_0   // c15 : a2·b0（capture ACC130）
  };

  mac_bignum_contrl_t     contrl_p256[LatencyP256];
  mac_bignum_predec_dyn_t predec_p256[LatencyP256];

  always_comb begin
    contrl_p256 = '{default: ControlDefault};
    predec_p256 = '{default: PredecDynDefault};

    for (int unsigned cycle = 0; cycle < LatencyP256; cycle++) begin
      if (cycle < P256NumSteps) begin
        contrl_p256[cycle].acc_wr_en_raw  = 1'b1;
        predec_p256[cycle].op_a_qw_sel    = 2'(P256Steps[cycle][7:6]);
        predec_p256[cycle].op_b_elem0_sel = 3'({P256Steps[cycle][5:4], 1'b0});
        predec_p256[cycle].op_b_elem1_sel = 3'({P256Steps[cycle][5:4], 1'b1});
        predec_p256[cycle].mul_shift_en   = 1'b1;   // 乘结果不被 blank
        predec_p256[cycle].add_res_en     = 1'b1;   // 加法器结果进 ACC
        predec_p256[cycle].shift_imm      = P256Steps[cycle][3:2];
        predec_p256[cycle].acc_zero       = P256Steps[cycle][1];
        predec_p256[cycle].so128          = P256Steps[cycle][0];
      end
    end

    // c27（写回/退休拍）才允许操作有效 —— c16…c26 是 hold（不产生任何 MAC/ACC 动作）
    predec_p256[LatencyP256 - 1].operation_valid_raw = 1'b1;
  end

  // Create helper 2D arrays to simplify the indexing in the actual signal selection. The first
  // dimension is to distinguish between regular (0) vs Montgomery (1) multiplication. The second
  // dimension represents the cycles. This allows a neat indexing using the is_mod control signal
  // as well as one common index width. See actual logic below.
  mac_bignum_contrl_t     contrl_multi[3][LatencyMax];
  mac_bignum_predec_dyn_t predec_multi[3][LatencyMax];

  always_comb begin
    // Vectorized multiplication (cycles 4-11 are unused)
    contrl_multi[0] = '{default: ControlDefault};
    predec_multi[0] = '{default: PredecDynDefault};

    for (int unsigned cycle = 0; cycle < LatencyVec; cycle++) begin
      contrl_multi[0][cycle] = contrl_vec[cycle];
      predec_multi[0][cycle] = predec_vec[cycle];
    end

    // Montgomery multiplication
    contrl_multi[1] = '{default: ControlDefault};
    predec_multi[1] = '{default: PredecDynDefault};

    for (int unsigned cycle = 0; cycle < LatencyMod; cycle++) begin
      contrl_multi[1][cycle] = contrl_mod[cycle];
      predec_multi[1][cycle] = predec_mod[cycle];
    end

    // P-256 multiplication (P3)
    contrl_multi[2] = '{default: ControlDefault};
    predec_multi[2] = '{default: PredecDynDefault};

    for (int unsigned cycle = 0; cycle < LatencyP256; cycle++) begin
      contrl_multi[2][cycle] = contrl_p256[cycle];
      predec_multi[2][cycle] = predec_p256[cycle];
    end
  end

  //////////////////////////////////
  // Multi-cycle signal selection //
  //////////////////////////////////
  // This is the actual logic controlling the execution and is based upon a cycle counter. This
  // counter is used as index into the above "computed" static control signal sequences. The
  // selected combination is then assigned to the actual control signals, forwarded to the
  // predecoder or used as expected signals.
  localparam int unsigned                CycleCountWidth = vbits(LatencyMax);
  localparam logic [CycleCountWidth-1:0] EndCycleVec     = CycleCountWidth'(LatencyVec - 1);
  localparam logic [CycleCountWidth-1:0] EndCycleMod     = CycleCountWidth'(LatencyMod - 1);
  localparam logic [CycleCountWidth-1:0] EndCycleP256    = CycleCountWidth'(LatencyP256 - 1);

  mac_bignum_predec_dyn_t     predec_dyn;
  logic [CycleCountWidth-1:0] current_cycle;
  logic                       mod_finishing;
  logic                       vec_finishing;
  logic                       p256_finishing;
  logic                       multi_finishing;
  // P3：三路模式索引（0 = vec，1 = Montgomery，2 = P-256）——P-256 与 is_vec 同时为 1
  logic [1:0]                 mac_mode;

  assign mac_mode = is_p256_i ? 2'd2 : (is_mod_i ? 2'd1 : 2'd0);

  // Evaluate whether this is the last cycle depending on type of multiplication.
  assign mod_finishing   = current_cycle == EndCycleMod;
  assign vec_finishing   = current_cycle == EndCycleVec;
  assign p256_finishing  = current_cycle == EndCycleP256;
  assign multi_finishing = is_p256_i ? p256_finishing :
                           (is_mod_i ? mod_finishing : vec_finishing);

  always_comb begin
    // Default is the regular multiplication
    contrl_o   = contrl_reg;
    predec_dyn = predec_dyn_reg;

    if (is_vec_i) begin
      contrl_o                       = contrl_multi[mac_mode][current_cycle];
      predec_dyn                     = predec_multi[mac_mode][current_cycle];
      predec_dyn.operation_valid_raw = mac_en_i & multi_finishing;
      // 只有"向量乘"才把 mul_res_merger 送进 ACC：Montgomery 与 P-256 都不用它
      predec_dyn.mul_merger_en       = (is_mod_i || is_p256_i) ? 1'b0 : mac_en_i;
    end else begin
      // Regular multiplications are single cycle, set valid flag immediately.
      predec_dyn.operation_valid_raw = mac_en_i;
      predec_dyn.mul_shift_en        = mac_en_i;
      predec_dyn.add_res_en          = mac_en_i;
    end

    // Overwrite operand b selection if in lane mode
    if (is_lane_i) begin
      predec_dyn.op_b_elem0_sel = lane_index_i;
      predec_dyn.op_b_elem1_sel = lane_index_i;
    end
  end

  // Combine the static and dynamic predecoded signals into one signal.
  assign predec_o = '{
    mac_en:              mac_en_i,
    is_vec:              is_vec_i,
    is_mod:              is_mod_i,
    is_lane:             is_lane_i,
    is_p256:             is_p256_i,
    lane_index:          lane_index_i,
    elen:                elen_i,
    shuffle_offset:      shuffle_offset,
    adder_carry_sel:     adder_carry_sel_i,
    acc_add_en:          acc_add_en_i,
    op_a_qw_sel:         predec_dyn.op_a_qw_sel,
    op_b_elem0_sel:      predec_dyn.op_b_elem0_sel,
    op_b_elem1_sel:      predec_dyn.op_b_elem1_sel,
    mul_op_a_tmp_sel:    predec_dyn.mul_op_a_tmp_sel,
    mul_op_b_sel:        predec_dyn.mul_op_b_sel,
    mul_add_en:          predec_dyn.mul_add_en,
    c_add_en:            predec_dyn.c_add_en,
    add_mod_en:          predec_dyn.add_mod_en,
    acc_qw_sel:          predec_dyn.acc_qw_sel,
    acc_merger_en:       predec_dyn.acc_merger_en,
    mul_shift_en:        predec_dyn.mul_shift_en,
    mul_merger_en:       predec_dyn.mul_merger_en,
    add_res_en:          predec_dyn.add_res_en,
    operation_valid_raw: predec_dyn.operation_valid_raw,
    // P3：P-256 每拍变化的三个值（非 P-256 模式下恒 0）
    shift_imm:           predec_dyn.shift_imm,
    acc_zero:            predec_dyn.acc_zero,
    so128:               predec_dyn.so128
  };

  assign is_busy_o = current_cycle != 0;

  // Check that the counter is always in bounds so no undefined control signals are set.
  // P3：界必须按模式给（P-256 = 28 拍），否则 P-256 的正常拍会被误判为越界、或越界时抓不到。
  logic current_cycle_oob;
  assign current_cycle_oob = current_cycle >= (is_p256_i ? CycleCountWidth'(LatencyP256) :
                                               is_mod_i  ? CycleCountWidth'(LatencyMod)  :
                                                           CycleCountWidth'(LatencyVec));

  // To be disabled when testing the out of bound check alert.
  `ASSERT(CurrentCycleIsInBounds_A, !current_cycle_oob, clk_i, !rst_ni || !mac_en_i)

  assign state_err_o = current_cycle_oob;

  ///////////////////
  // Cycle counter //
  ///////////////////
  logic [CycleCountWidth-1:0] cycle_count_d, cycle_count_q;
  logic cycle_do_step;
  logic cycle_clear;
  logic [CycleCountWidth-1:0] cycle_increment;

  assign current_cycle = cycle_count_q;

  assign cycle_clear     = predec_dyn.operation_valid_raw || sec_wipe_i;
  assign cycle_do_step   = mac_en_i && (start_i || is_busy_o);
  assign cycle_increment = CycleCountWidth'(1);

  always_comb begin
    cycle_count_d = cycle_count_q;

    if (cycle_clear) begin
      cycle_count_d = '0;
    end else if (cycle_do_step) begin
      // Wraparound should never happen but is ok.
      cycle_count_d = cycle_count_q + cycle_increment;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      cycle_count_q <= '0;
    end else begin
      cycle_count_q <= cycle_count_d;
    end
  end

  //////////////////////
  // Alert assertions //
  //////////////////////
`ifdef INC_ASSERT
  //VCS coverage off
  // pragma coverage off

  // There is an alert assertion in otbn.sv which checks that state_err_o triggers an alert similar
  // to how it is checked that errors from prim blocks result in an alert. This unused signal is
  // connected / used if such an assertion is present, ensuring the assertion is not forgotten.
  logic unused_assert_connected;
  `ASSERT_INIT_NET(AssertConnected_A, unused_assert_connected === 1'b1 || !EnableAlertTriggerSVA)
`endif

endmodule
