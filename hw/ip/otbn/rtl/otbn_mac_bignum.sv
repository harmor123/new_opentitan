// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`include "prim_assert.sv"

/**
 * OTBN bignum multiply and accumulate module
 *
 * This module supports 3 types of multiplication and accumulation instructions:
 * - bn.mulqacc: Regular 64-bit multiplication with result shifting and accumulation capabilities
 *     (see instruction description). The 64-bit multiplication operands can be selected from the
 *     input WDRs. Executes in one cycle.
 * - bn.mulv(l): Vectorized multiplication of 32-bit elements from 256-bit vectors (WDRs). Operates
 *     either vector-element-wise or multiples each element of vector A with a fixed element of
 *     vector B. The later mode is referred to as lane-wise multiplication. Performs two 32-bit
 *     multiplications in parallel and takes 4 cycles to process the 256-bit vectors.
 * - bn.mulvm(l): Vectorized Montgomery multiplication of 32-bit elements from 256-bit vectors
 *     (WDRs). Also supports the lane mode. Performs two Montgomery multiplications in parallel
 *     over the duration of 3 cycles. It takes 3 * 4 = 12 cycles to process the 256-bit vectors.
 *     The final conditional subtraction step of the Montgomery algorithm is neglected to optimize
 *     area and timing. See below for more details about the Montgomery implementation.
 *
 * The multi-cycle instructions stall the OTBN pipeline by keeping the operation_valid_o flag low
 * until the computation has finished. This multi-cycle logic is controlled by an internal FSM
 * which controls the data path. It operates in tandem with a duplicate in the instruction fetch
 * stage. This duplicate generates the predecoded signals which are compared here to the locally
 * generated signals.
 *
 * The main components of this module are a vectorized 64-bit multiplier capable of computing
 * either 1 64-bit or 2 32-bit multiplications at once, a vectorized 256-bit adder as well as the
 * 256-bit wide ACC WSR. These components allow to implement the regular 64-bit multiplication with
 * accumulation in a single cycle. For the vectorized multiplications, the multiplications are
 * pipelined on the vectorized multiplier to save area. The partial results are combined to a full
 * 256-bit vector using the ACC WSR. As the Montgomery multiplication requires 3 multiplications
 * these are also pipelined on the vectorized multiplier and the final result is constructed in the
 * ACC WSR. Both vectorized instructions clear the ACC WSR at the end of the instruction using
 * random data supplied externally. See below.
 *
 * Montgomery implementation details:
 * The Montgomery algorithm efficiently computes a multiplication and reduction by converting
 * divisions to power of two divisions and modulo operations. This module implements the unsigned
 * version of Montgomery and does not compute the conditional subtraction step to optimize for area
 * and timing.
 *
 * Algorithm inputs:
 * - a, b: Operands in [0, q[
 * - d:    Bitwidth of operands (fixed to 32 bit)
 * - q:    Modulus in ]0, 2^d]
 * - mu:   Montgomery constant, precomputed, mu = (-q)^(-1) mod 2^d
 *
 * The required constants q and mu are expected to be in the MOD WSR at following locations:
 * q  @ [31:0]
 * mu @ [63:32]
 *
 * Outputs:
 * - r = a*b * 2^(-d) mod q and r in [0,q[
 *
 * This can be computed with (where []_d are the lower d bits, []^d are the higher d bits):
 *   c = a * b
 *   r = [c + [[c]_d * mu]_d * q]^d
 *   if r >= q then                      <- not implemented in this HW
 *       return r - q
 *   return r
 *
 * Due to the neglected conditional subtraction the result is in ]0,2q[ and can be reduced into
 * ]0,q[ using the bn.addvm instruction.
 *
 * As the 3 multiplications are pipelined onto the multiplier it requires two additional registers
 * for intermediate values named "TMP" and "C". These registers hold the following intermediate
 * values when computing a Montgomery multiplication:
 *   Cycle 1:  Reg(TMP) = [a*b]_d,     Reg(C) = a*b
 *   Cycle 2:  Reg(TMP) = [TMP*mu]_d,  Reg(C) = a*b
 *   Cycle 3:  Output   = c + (TMP)*q mod q = [c + (TMP)*q]^d
 *
 * These two hidden registers are cleared with randomness after each vector chunk (i.e., every 3
 * cycles).
 *
 * Register clearing details:
 * As described, the ACC WSR and the two hidden registers are cleared using randomness. The ACC WSR
 * is directly cleared by writing the current value of URND to it. The two hidden registers are
 * cleared with a permutation of URND as shown below. The permutation is based on a netlist secret.
 * The remaining permuted bits are used as shuffling index which the predecoding logic samples.
 *
 *              +-------------+
 * URND --+---->| Permutation |-----+----------+----------+
 *        |     +-------------+     |          |          |
 *        |                      [127:0]   [192:128]   [194:193]
 *        v                         v          v           v
 *     +-----+                   +-----+    +-----+     Used as
 *     | ACC |                   |  C  |    | TMP |    shuffling
 *     +-----+                   +-----+    +-----+      index
 */
module otbn_mac_bignum
  import otbn_pkg::*;
#(
  // Compile-time permutation for URND permutation
  parameter bn_mac_urnd_perm_t RndCnstBnMacUrndPerm = RndCnstBnMacUrndPermDefault,
  parameter bit SecFixMacOpSeq = 1'b0
) (
  input logic clk_i,
  input logic rst_ni,

  input mac_bignum_operation_t operation_i,
  // The signal mac_en_i must only used by the FSM or by assertions! Everywhere else use the
  // predecoded version. This ensures that there is a redundancy check in place.
  input logic                  mac_en_i,
  input logic                  mac_commit_i,

  // P3: start impulse for the P-256 fold unit.  It is asserted one cycle before this instruction's
  // first execution cycle (see otbn_instruction_fetch's p256_fold_start_o) so that the fold unit's
  // internal cycle counter lines up with the FSM's current_cycle.
  input logic                  p256_fold_start_i,

  // P4: P-256 schedule select (0 = overlap, 1 = serial).  Drives the fold unit's mode, the
  // write-back cycle and this module's FSM (the fetch-side FSM gets the same value from otbn_core).
  input logic                  p256_serial_mode_i,

  output logic [WLEN-1:0] operation_result_o,
  output logic            operation_valid_o,
  output flags_t          operation_flags_o,
  output flags_t          operation_flags_en_o,
  output logic            operation_intg_violation_err_o,

  input  mac_bignum_predec_t predec_i,
  output logic               predec_error_o,

  input  logic [WLEN-1:0] urnd_data_i,
  input  logic            sec_wipe_urnd_i,
  input  logic            sec_wipe_running_i,
  output logic            sec_wipe_err_o,
  output logic [1:0]      shuffle_offset_o,

  output logic [ExtWLEN-1:0] ispr_acc_intg_o,
  input  logic [ExtWLEN-1:0] ispr_acc_wr_data_intg_i,
  input  logic               ispr_acc_wr_en_i,

  input  logic [ExtWLEN-1:0] ispr_mod_intg_i,

  output logic state_err_o
);
  localparam int unsigned ELEN = QWLEN / 2;

  // URND permutations for register clearing
  logic [WLEN-1:0]  urnd_permutation;
  logic             unused_urnd_permutation;
  logic [WLEN-1:0]  acc_clear_data;
  logic [HWLEN-1:0] c_clear_data;
  logic [QWLEN-1:0] tmp_clear_data;

  for (genvar i = 0; i < WLEN; i++) begin : gen_urnd_perm
    assign urnd_permutation[i] = urnd_data_i[RndCnstBnMacUrndPerm[i]];
  end

  assign acc_clear_data   = urnd_data_i;
  assign c_clear_data     = urnd_permutation[HWLEN-1:0];
  assign tmp_clear_data   = urnd_permutation[HWLEN         +: QWLEN];
  assign shuffle_offset_o = urnd_permutation[HWLEN + QWLEN +: 2];

  assign unused_urnd_permutation = ^urnd_permutation[HWLEN + QWLEN + 2 +: QWLEN - 2];

  //////////////////
  // ACC Register //
  //////////////////
  logic                          acc_wr_en;
  logic                          acc_clear_en;
  logic [ExtWLEN-1:0]            acc_intg_d;
  logic [ExtWLEN-1:0]            acc_intg_q;
  logic [ExtWLEN-1:0]            acc_intg_calc;
  logic [WLEN-1:0]               acc_no_intg_d;
  logic [WLEN-1:0]               acc_no_intg_q;
  logic [2*BaseWordsPerWLEN-1:0] acc_intg_err;
  for (genvar i_word = 0; i_word < BaseWordsPerWLEN; i_word++) begin : g_acc_words
    prim_secded_inv_39_32_enc i_secded_enc (
      .data_i(acc_no_intg_d[i_word * 32 +: 32]),
      .data_o(acc_intg_calc[i_word * 39 +: 39])
    );
    prim_secded_inv_39_32_dec i_secded_dec (
      .data_i    (acc_intg_q[i_word * 39 +: 39]),
      .data_o    (/* unused because we abort on any integrity error */),
      .syndrome_o(/* unused */),
      .err_o     (acc_intg_err[i_word * 2 +: 2])
    );
    assign acc_no_intg_q[i_word * 32 +: 32] = acc_intg_q[i_word * 39 +: 32];
  end

  always_ff @(posedge clk_i) begin
    if (acc_wr_en) begin
      acc_intg_q <= acc_intg_d;
    end
  end

  ////////////////
  // Register C //
  ////////////////
  logic                           c_wr_en;
  logic                           c_clear_en;
  logic [ExtHWLEN-1:0]            c_intg_d;
  logic [ExtHWLEN-1:0]            c_intg_q;
  logic [HWLEN-1:0]               c_new_value;
  logic [HWLEN-1:0]               c_no_intg_d;
  logic [HWLEN-1:0]               c_no_intg_q;
  logic [2*BaseWordsPerHWLEN-1:0] c_intg_err;

  for (genvar i_word = 0; i_word < BaseWordsPerHWLEN; i_word++) begin : g_c_words
    prim_secded_inv_39_32_enc i_c_secded_enc (
      .data_i(c_no_intg_d[i_word * 32 +: 32]),
      .data_o(c_intg_d[i_word * 39 +: 39])
    );
    prim_secded_inv_39_32_dec i_c_secded_dec (
      .data_i    (c_intg_q[i_word * 39 +: 39]),
      .data_o    (/* unused because we abort on any integrity error */),
      .syndrome_o(/* unused */),
      .err_o     (c_intg_err[i_word * 2 +: 2])
    );
    assign c_no_intg_q[i_word * 32 +: 32] = c_intg_q[i_word * 39 +: 32];
  end

  always_comb begin
    c_no_intg_d = '0;
    unique case (1'b1)
      (sec_wipe_urnd_i | c_clear_en): c_no_intg_d = c_clear_data;
      default:                        c_no_intg_d = c_new_value;
    endcase
  end

  always_ff @(posedge clk_i) begin
    if (c_wr_en) begin
      c_intg_q <= c_intg_d;
    end
  end

  //////////////////
  // Register TMP //
  //////////////////
  logic                           tmp_wr_en;
  logic                           tmp_clear_en;
  logic [ExtQWLEN-1:0]            tmp_intg_d;
  logic [ExtQWLEN-1:0]            tmp_intg_q;
  logic [QWLEN-1:0]               tmp_new_value;
  logic [QWLEN-1:0]               tmp_no_intg_d;
  logic [QWLEN-1:0]               tmp_no_intg_q;
  logic [2*BaseWordsPerQWLEN-1:0] tmp_intg_err;

  for (genvar i_word = 0; i_word < BaseWordsPerQWLEN; i_word++) begin : g_tmp_words
    prim_secded_inv_39_32_enc i_tmp_secded_enc (
      .data_i(tmp_no_intg_d[i_word * 32 +: 32]),
      .data_o(tmp_intg_d[i_word * 39 +: 39])
    );
    prim_secded_inv_39_32_dec i_tmp_secded_dec (
      .data_i    (tmp_intg_q[i_word * 39 +: 39]),
      .data_o    (/* unused because we abort on any integrity error */),
      .syndrome_o(/* unused */),
      .err_o     (tmp_intg_err[i_word * 2 +: 2])
    );
    assign tmp_no_intg_q[i_word * 32 +: 32] = tmp_intg_q[i_word * 39 +: 32];
  end

  always_comb begin
    tmp_no_intg_d = '0;
    unique case (1'b1)
      (sec_wipe_urnd_i | tmp_clear_en): tmp_no_intg_d = tmp_clear_data;
      default:                          tmp_no_intg_d = tmp_new_value;
    endcase
  end

  always_ff @(posedge clk_i) begin
    if (tmp_wr_en) begin
      tmp_intg_q <= tmp_intg_d;
    end
  end

  ////////////////////
  // Input blanking //
  ////////////////////
  logic [WLEN-1:0] operand_a_blanked;
  logic [WLEN-1:0] operand_b_blanked;

  // SEC_CM: DATA_REG_SW.SCA
  prim_blanker #(.Width(WLEN)) u_operand_a_blanker (
    .in_i (operation_i.operand_a),
    .en_i (predec_i.mac_en),
    .out_o(operand_a_blanked)
  );

  // SEC_CM: DATA_REG_SW.SCA
  prim_blanker #(.Width(WLEN)) u_operand_b_blanker (
    .in_i (operation_i.operand_b),
    .en_i (predec_i.mac_en),
    .out_o(operand_b_blanked)
  );

  ///////////////////
  // MOD Extractor //
  ///////////////////
  // The modulus and Montgomery constant are expected in the MOD register at:
  // q  @ [31:0]
  // mu @ [63:32]
  logic [2*39-1:0] ispr_mod_intg_blanked;
  logic            unused_ispr_mod_intg;
  logic [63:0]     mod_no_intg;
  logic [3:0]      mod_intg_err;

  // Only the first two 32-bit words are required as q and mu reside in the first 64 bits.
  // This needs blanking to avoid mixing values from MOD with the input B when performing a regular
  // multiplication.
  // SEC_CM: DATA_REG_SW.SCA
  prim_blanker #(.Width(2*39)) u_mod_blanker (
    .in_i (ispr_mod_intg_i[2*39-1:0]),
    .en_i (predec_i.is_mod),
    .out_o(ispr_mod_intg_blanked)
  );

  assign unused_ispr_mod_intg = ^ispr_mod_intg_i[ExtWLEN-1:2*39];

  for (genvar i_word = 0; i_word < 2; i_word++) begin : g_mod_words
    prim_secded_inv_39_32_dec i_mod_secded_dec (
      .data_i    (ispr_mod_intg_blanked[i_word * 39 +: 39]),
      .data_o    (/* unused because we abort on any integrity error */),
      .syndrome_o(/* unused */),
      .err_o     (mod_intg_err[i_word * 2 +: 2])
    );
    assign mod_no_intg[i_word * 32 +: 32] = ispr_mod_intg_blanked[i_word * 39 +: 32];
  end

  // For the 32-bit vectorized multiplications we have to replicate the constants
  logic [QWLEN-1:0] mod_q;  // The Montgomery modulus q
  logic [QWLEN-1:0] mod_mu; // The Montgomery constant mu

  assign mod_q  = {2{mod_no_intg[31:0]}};
  assign mod_mu = {2{mod_no_intg[63:32]}};

  ///////////////////////////
  // Vectorized multiplier //
  ///////////////////////////

  // Input operand quad word selection
  logic [QWLEN-1:0] qword_a;
  logic [QWLEN-1:0] qword_b;

  // This MUX is predecoded to optimize timing.
  assign qword_a = operand_a_blanked[predec_i.op_a_qw_sel * QWLEN +: QWLEN];

  // The qword_b MUXing is elementwise to implement the lane functionality.
  // These 8-to-1 MUXs are predecoded to optimize timing.
  assign qword_b[   0+:ELEN] = operand_b_blanked[predec_i.op_b_elem0_sel * ELEN +: ELEN];
  assign qword_b[ELEN+:ELEN] = operand_b_blanked[predec_i.op_b_elem1_sel * ELEN +: ELEN];

  // Multiplier operand selection
  logic [QWLEN-1:0] mul_op_a;
  logic [QWLEN-1:0] mul_op_b;
  logic [HWLEN-1:0] mul_res;

  assign mul_op_a = predec_i.mul_op_a_tmp_sel ? qword_a : tmp_no_intg_q;

  // Here a regular MUX is sufficient because q and mu are blanked for regular multiplications.
  // For Montgomery these values are anyway combined.
  always_comb begin
    unique case (predec_i.mul_op_b_sel)
      MulOpB:  mul_op_b = qword_b;
      MulOpMu: mul_op_b = mod_mu;
      MulOpq:  mul_op_b = mod_q;
      default: mul_op_b = qword_b;
    endcase
  end

  otbn_vec_multiplier u_vec_multiplier (
    .operand_a_i(mul_op_a),
    .operand_b_i(mul_op_b),
    .elen_i     (predec_i.elen),
    .result_o   (mul_res)
  );

  //////////////////////////////////////////////////////////
  // Multiplier result handling for vectorized Montgomery //
  //////////////////////////////////////////////////////////
  // Store the full result to register C
  assign c_new_value = mul_res;

  // Store only the lower ELEN bits of the parallel multiplications to register TMP.
  assign tmp_new_value = {mul_res[QWLEN +: QWLEN / 2], mul_res[0 +: QWLEN / 2]};

  // Adder operand blanking and extension
  logic [HWLEN-1:0] half_mul_res_add;
  logic [WLEN-1:0]  mul_res_add;

  // SEC_CM: DATA_REG_SW.SCA
  prim_blanker #(.Width(HWLEN)) u_half_mul_res_blanker (
    .in_i (mul_res),
    .en_i (predec_i.mul_add_en),
    .out_o(half_mul_res_add)
  );

  assign mul_res_add = {{HWLEN{1'b0}}, half_mul_res_add};

  //////////////////////////////////////////////////////////////////////
  // Multiplier result handling for regular vectorized multiplication //
  //////////////////////////////////////////////////////////////////////
  // Truncating and blanking of results towards the ACC merger for vectorized multiplication
  // without modulo reduction.
  logic [QWLEN-1:0] mul_res_merger;

  // SEC_CM: DATA_REG_SW.SCA
  prim_blanker #(.Width(QWLEN)) u_mul_res_merger_blanker (
    .in_i (tmp_new_value),
    .en_i (predec_i.mul_merger_en),
    .out_o(mul_res_merger)
  );

  ///////////////////////////////////////////////////////////
  // Multiplier result handling for regular multiplication //
  ///////////////////////////////////////////////////////////
  // Blank and shift result prior to accumulation
  logic [HWLEN-1:0] mul_res_pre_shifted;
  logic [WLEN-1:0]  mul_res_shifted;

  // SEC_CM: DATA_REG_SW.SCA
  prim_blanker #(.Width(HWLEN)) u_mul_res_shift_blanker (
    .in_i (mul_res),
    .en_i (predec_i.mul_shift_en),
    .out_o(mul_res_pre_shifted)
  );

  // Shift the HWLEN multiply result into a WLEN word before accumulating using the shift amount
  // supplied in the instruction (pre_acc_shift_imm). The shift is on a QWORD granularity and a
  // 192-bit shift will drop the upper QWORD of the multiply result.
  // P3: for bn.p256mul the shift amount changes on every cycle (16 micro-operations), so it comes
  // from the predecoded signals instead of the instruction. Everything else uses the instruction
  // value, exactly as before.
  logic [1:0] acc_shift_imm;
  assign acc_shift_imm = predec_i.is_p256 ? predec_i.shift_imm : operation_i.pre_acc_shift_imm;

  always_comb begin
    mul_res_shifted = '0;

    unique case (acc_shift_imm)
      2'd0:    mul_res_shifted = {{QWLEN * 2{1'b0}}, mul_res_pre_shifted};
      2'd1:    mul_res_shifted = {{QWLEN{1'b0}}, mul_res_pre_shifted, {QWLEN{1'b0}}};
      2'd2:    mul_res_shifted = {mul_res_pre_shifted, {QWLEN * 2{1'b0}}};
      2'd3:    mul_res_shifted = {mul_res_pre_shifted[QWLEN-1:0], {QWLEN * 3{1'b0}}};
      // The default is the first case but with the blanker disabled, so the output is '0.
      default: mul_res_shifted = {{QWLEN * 2{1'b0}}, mul_res_pre_shifted};
    endcase
  end

  `ASSERT_KNOWN_IF(PreAccShiftImmKnown, acc_shift_imm, mac_en_i)

  //////////////////////
  // Vectorized Adder //
  //////////////////////
  logic [HWLEN-1:0] c_blanked;
  logic [WLEN-1:0]  acc_add_blanked;
  logic [WLEN-1:0]  adder_op_a;
  logic [WLEN-1:0]  adder_op_b;
  logic [WLEN-1:0]  adder_result;

  // SEC_CM: DATA_REG_SW.SCA
  prim_blanker #(.Width(HWLEN)) u_reg_c_blanker (
    .in_i (c_no_intg_q),
    .en_i (predec_i.c_add_en),
    .out_o(c_blanked)
  );

  // SEC_CM: DATA_REG_SW.SCA
  // acc_add_en is so if .Z set in MULQACC (zero_acc) so accumulator reads as 0
  // P3: for bn.p256mul the ".z" behaviour is per-cycle (acc_zero), so the blanker is controlled by
  // that in P-256 mode and by the instruction signal otherwise.
  logic acc_add_en_eff;
  assign acc_add_en_eff = predec_i.is_p256 ? ~predec_i.acc_zero : predec_i.acc_add_en;

  prim_blanker #(.Width(WLEN)) u_acc_add_blanker (
    .in_i (acc_no_intg_q),
    .en_i (acc_add_en_eff),
    .out_o(acc_add_blanked)
  );

  // Perform the additions. The vectorized path only uses the lower 128 bits of the adder and
  // operates on 64-bit elements. The full 256 bit width is used for bn.mulqacc instructions.
  // Here the MUXs can be implemented with OR gates because input signals are exclusively blanked
  // for the whole duration of an instruction.
  // - c_blanked is only non zero for Montgomery multiplications where mul_res_shifted is unused.
  //   Vice versa mul_res_shifted is only non zero for regular multiplications where c_blanked is
  //   unused.
  // - mul_res_add is only non zero for vectorized multiplications where acc_add_blanked is unused.
  //   Vice versa acc_add_blanked is only non zero for regular multiplications where mul_res_add is
  //   blanked.
  assign adder_op_a = {{128{1'b0}}, c_blanked} | mul_res_shifted;
  assign adder_op_b = mul_res_add              | acc_add_blanked;

  otbn_vec_adder #(
    .LVLEN(WLEN),
    .LVChunkLEN(QWLEN)
  ) u_vec_adder (
    .operand_a_i       (adder_op_a),
    .operand_b_i       (adder_op_b),
    .operand_b_invert_i(1'b0), // always add, never subtract
    .carries_in_i      ('0),
    .use_ext_carry_i   (predec_i.adder_carry_sel),
    .sum_o             (adder_result),
    .carries_out_o     (/* unused */)
  );

  /////////////////////////////////////////////
  // Vectorized adder modulo result handling //
  /////////////////////////////////////////////
  logic [QWLEN-1:0] adder_result_mod;
  logic [QWLEN-1:0] montg_r;

  // Montgomery upper bit selection
  // Take only the upper ELEN bits of the addition.
  // The result is "r" of the montgomery algorithm
  assign adder_result_mod = {adder_result[32 * 3 +: 32], adder_result[32 * 1 +: 32]};

  prim_blanker #(.Width(QWLEN)) u_add_mod_blanker (
    .in_i (adder_result_mod),
    .en_i (predec_i.add_mod_en),
    .out_o(montg_r)
  );

  // The conditional subtraction is not performed to optimize timing and area.
  // It can be performed using the bn.addvm instruction with a zero vector.
  logic [QWLEN-1:0] montg_r_cor;
  assign montg_r_cor = montg_r;

  ///////////////////////////////////////////
  // ACC merging for vectorized operations //
  ///////////////////////////////////////////
  logic [QWLEN-1:0] acc_new_qw;
  logic [WLEN-1:0]  acc_blanked;
  logic [WLEN-1:0]  acc_merged;

  // This MUX can be implemented using a regular OR because both inputs are exclusively blanked.
  // The mul_res_merger comes directly from a blanker which is only active (passes data through) if
  // we are performing a regular vectorized multiplication (default or lane). In this case the
  // montg_r_cor is all zero as the signal is blanked with u_add_mod_blanker. During a Montgomery
  // multiplication the montg_r_cor contains the data but mul_res_merger is blanked.
  // These blankers are exclusively used for the whole duration of an instruction.
  assign acc_new_qw = montg_r_cor | mul_res_merger;

  // This blanker is used to zero the ACC register
  prim_blanker #(.Width(WLEN)) u_acc_merger_blanker (
    .in_i (acc_no_intg_q),
    .en_i (predec_i.acc_merger_en),
    .out_o(acc_blanked)
  );

  // Place the computed 64-bit chunk at the desired location in the ACC register.
  for (genvar qw = 0; qw < VLEN/QWLEN; qw++) begin : gen_acc_merged
    assign acc_merged[qw * QWLEN +: QWLEN] = predec_i.acc_qw_sel[qw] ?
        acc_new_qw : acc_blanked[qw * QWLEN +: QWLEN];
  end

  //////////////////////////////////////////////////////
  // Adder result handling for regular multiplication //
  //////////////////////////////////////////////////////
  logic [WLEN-1:0] adder_result_blanked;
  logic [WLEN-1:0] regular_acc_update_value;

  prim_blanker #(.Width(WLEN)) u_add_res_blanker (
    .in_i (adder_result),
    .en_i (predec_i.add_res_en),
    .out_o(adder_result_blanked)
  );

  // P3: the shift-out (ACC takes the upper half of the adder result) is per-cycle for bn.p256mul
  // (so128) and set by the instruction (shift_acc) otherwise. The flags keep using the instruction
  // signal on purpose: they are disabled for vectorized/P-256 instructions anyway.
  logic acc_shift_out;
  assign acc_shift_out = predec_i.is_p256 ? predec_i.so128 : operation_i.shift_acc;

  assign regular_acc_update_value = acc_shift_out ?
      {{HWLEN{1'b0}}, adder_result_blanked[HWLEN+:HWLEN]} :
      adder_result_blanked;

  /////////////////
  // Flag update //
  /////////////////
  // Vectorized operation never updates flags
  logic [1:0] adder_result_hw_is_zero;

  // Split zero check between the two halves of the result. This is used for flag setting (see
  // below).
  assign adder_result_hw_is_zero[0] = adder_result_blanked[WLEN/2-1:0] == 'h0;
  assign adder_result_hw_is_zero[1] = adder_result_blanked[WLEN/2+:WLEN/2] == 'h0;

  assign operation_flags_o.L    = adder_result_blanked[0];
  // L is always updated for .WO, and for .SO when writing to the lower half-word
  assign operation_flags_en_o.L = predec_i.is_vec       ? 1'b0                         :
                                  operation_i.shift_acc ? ~operation_i.wr_hw_sel_upper : 1'b1;

  // For .SO M is taken from the top-bit of shifted out half-word, otherwise it is taken from the
  // top-bit of the full result.
  assign operation_flags_o.M    = operation_i.shift_acc ? adder_result_blanked[WLEN/2-1] :
                                                          adder_result_blanked[WLEN-1];
  // M is always updated for .WO, and for .SO when writing to the upper half-word.
  assign operation_flags_en_o.M = predec_i.is_vec       ? 1'b0                        :
                                  operation_i.shift_acc ? operation_i.wr_hw_sel_upper : 1'b1;

  // For .SO Z is calculated from the shifted out half-word, otherwise it is calculated on the full
  // result.
  assign operation_flags_o.Z    = operation_i.shift_acc ? adder_result_hw_is_zero[0] :
                                                          &adder_result_hw_is_zero;

  // Z is updated for .WO. For .SO updates are based upon result and half-word:
  // - When writing to lower half-word always update Z.
  // - When writing to upper half-word clear Z if result is non-zero otherwise leave it alone.
  assign operation_flags_en_o.Z =
      predec_i.is_vec                                     ? 1'b0                        :
      operation_i.shift_acc & operation_i.wr_hw_sel_upper ? ~adder_result_hw_is_zero[0] : 1'b1;

  // MAC never sets the carry flag
  assign operation_flags_o.C    = 1'b0;
  assign operation_flags_en_o.C = 1'b0;

  ////////////////
  // ACC update //
  ////////////////
  always_comb begin
    acc_no_intg_d = '0;
    unique case (1'b1)
      // Non-encoded inputs have to be encoded before writing to the register.
      (sec_wipe_urnd_i | acc_clear_en): begin
        acc_no_intg_d = acc_clear_data;
        acc_intg_d    = acc_intg_calc;
      end
      default: begin
        // If performing an ACC ISPR write the next accumulator value is taken from the ISPR write
        // data, otherwise it is drawn from the adder result or the vectorized ACC merger.
        if (ispr_acc_wr_en_i) begin
          acc_intg_d = ispr_acc_wr_data_intg_i;
        end else begin
          // The MUX for the input selection can be implemented with a simple OR gate because both
          // inputs are exclusively blanked. For regular multiplications acc_merged is zero because
          // the ACC merger just receives zero values. For vectorized multiplications (incl.
          // Montgomery) the regular_acc_update_value is zero because add_res_en is reset.
          // These blankers are exclusively used for the whole duration of an instruction.
          acc_no_intg_d = acc_merged | regular_acc_update_value;
          acc_intg_d    = acc_intg_calc;
        end
      end
    endcase
  end

  ///////////////////////////
  // Register Write Enable //
  ///////////////////////////
  // The raw write enables are set by the state machine. These are then combined with the input
  // signals which handle the validity of the instruction.
  logic acc_wr_en_raw;
  logic tmp_wr_en_raw;
  logic c_wr_en_raw;

  assign acc_wr_en = ((acc_wr_en_raw | acc_clear_en) & (predec_i.mac_en & mac_commit_i))
                     | ispr_acc_wr_en_i | sec_wipe_urnd_i;
  assign tmp_wr_en = ((tmp_wr_en_raw | tmp_clear_en) & (predec_i.mac_en & mac_commit_i))
                     | sec_wipe_urnd_i;
  assign c_wr_en   = ((c_wr_en_raw | c_clear_en) & (predec_i.mac_en & mac_commit_i))
                     | sec_wipe_urnd_i;

  /////////////////////////
  // Multi-cycle control //
  /////////////////////////
  // The multi-cycle execution is controlled by a FSM. This FSM works in tandem with a duplicate
  // in the instruction fetch stage. The duplicate operates one cycle in advance and provides the
  // predecoded signals. These signals are compared to the ones generated here.
  mac_bignum_contrl_t contrl;
  mac_bignum_predec_t expected_predec;

  otbn_mac_bignum_fsm #(
    .SecFixMacOpSeq(SecFixMacOpSeq)
  ) u_mac_bignum_fsm (
    .clk_i,
    .rst_ni,

    // This FSM here must use the decoded signals as the counterpart operates on the predecoded
    // signals. Otherwise both FSMs would be controlled with the same control signals.
    .start_i          (mac_en_i),
    .mac_en_i         (mac_en_i),
    .is_vec_i         (operation_i.is_vec),
    .is_mod_i         (operation_i.is_mod),
    .is_lane_i        (operation_i.is_lane),
    .is_p256_i        (operation_i.is_p256),
    .p256_serial_i    (p256_serial_mode_i),
    .lane_index_i     (operation_i.lane_index),
    .elen_i           (operation_i.elen),
    .adder_carry_sel_i(operation_i.adder_carry_sel),
    .acc_add_en_i     (operation_i.acc_add_en),
    .op_a_qw_sel_i    (operation_i.op_a_qw_sel_raw),
    .op_b_elem0_sel_i (operation_i.op_b_elem0_sel_raw),
    .op_b_elem1_sel_i (operation_i.op_b_elem1_sel_raw),
    // We cannot recompute the shuffling index here because we don't have the URND bits from the
    // last cycle. Instead we just use the value from the predecoder. This means deterministic URND
    // bits in the predecoder (e.g., when attacked) will make the shuffling deterministic. But that
    // is acceptable as the shuffling is a SCA countermeasure on top of the masking expected to be
    // implemented in software.
    .shuffle_offset_i (predec_i.shuffle_offset),

    .sec_wipe_i(sec_wipe_urnd_i),

    .contrl_o (contrl),
    .predec_o (expected_predec),
    .is_busy_o(/* only used in predecoder */),

    // Any tampering on the internal state will abort the execution.
    .state_err_o(state_err_o)
  );

  // For non modulo vectorized multiplications, the blanker must be active if the instructions
  // starts and it must definitively be high if it is already ongoing.
  // P3：P-256 也算 is_vec，但它同样不使用 mul_res_merger（走的是加法器 + ACC 通路）⇒ 排除在外。
  `ASSERT(VecMulBlankerMulMergerEn_A,
          predec_i.is_vec && !predec_i.is_mod && !predec_i.is_p256 && predec_i.mac_en
          |-> predec_i.mul_merger_en,
          clk_i, !rst_ni || !predec_i.mac_en)

  // We have separate control signals to have a clean separation between the control logic and data
  // path components.
  assign tmp_wr_en_raw = contrl.tmp_wr_en_raw;
  assign tmp_clear_en  = contrl.tmp_clear_en;
  assign c_wr_en_raw   = contrl.c_wr_en_raw;
  assign c_clear_en    = contrl.c_clear_en;
  assign acc_wr_en_raw = contrl.acc_wr_en_raw;
  assign acc_clear_en  = contrl.acc_clear_en;

  /////////////////////////
  // P-256 fold unit (P3) //
  /////////////////////////
  // The tail of a fused P-256 multiply (c16..c27: the eight row addends, the L0 merge, the
  // quotient fold, the single conditional +/- p and the write-back) runs in its own unit; only its
  // write-back result takes the place of the MAC result.  Its four tap samples stay at c3/c9/c12/c15
  // and read the *current* cycle's values (not registers):
  //   c9  : the adder output before the shift-out selection, i.e. the new accumulator value
  //   c15 : the ACC update value after the shift-out (acc_no_intg_d, combinational)
  // `mode_serial_i` is tied to 1: P3 runs the serial schedule (28 cycles).  Overlap is P4's switch.
  logic               p256_fold_busy;
  logic [4:0]         p256_fold_cycle;
  logic signed [259:0] p256_fold_f;
  logic               unused_p256_fold;
  logic               unused_p256_fold_wd_valid;
  logic [WLEN-1:0]    unused_p256_fold_wd;
  logic [255:0]       unused_p256_fold_h;
  logic [127:0]       unused_p256_fold_ll;
  logic [129:0]       unused_p256_fold_acc130;
  logic signed [3:0]  unused_p256_fold_k;

  otbn_p256_fold u_otbn_p256_fold (
    .clk_i,
    .rst_ni,

    .start_i      (p256_fold_start_i),
    .abort_i      (sec_wipe_urnd_i),
    .wipe_i       (sec_wipe_urnd_i),
    .mode_serial_i(p256_serial_mode_i),

    .mac_result_pre_so_i(adder_result_blanked),
    .mac_acc_after_so_i (acc_no_intg_d[129:0]),

    .busy_o     (p256_fold_busy),
    .cycle_o    (p256_fold_cycle),
    .f_o        (p256_fold_f),
    .h_o        (unused_p256_fold_h),
    .ll_o       (unused_p256_fold_ll),
    .acc130_o   (unused_p256_fold_acc130),
    .k_o        (unused_p256_fold_k),
    .wd_valid_o (unused_p256_fold_wd_valid),
    .wd_o       (unused_p256_fold_wd)
  );

  // The result only needs the low 256 bits (it is < p < 2^256); the accumulator's top four bits
  // are therefore unused and are folded into the unused net below.
  assign unused_p256_fold = ^{unused_p256_fold_wd_valid, unused_p256_fold_wd, unused_p256_fold_h,
                              unused_p256_fold_ll, unused_p256_fold_acc130, unused_p256_fold_k,
                              p256_fold_f[259:256]};

  //////////////////////
  // Result selection //
  //////////////////////
  // Here the output MUX can be replaced with a simple OR gate because both inputs are exclusively
  // blanked. For regular multiplications the acc_merged is zero because the ACC merging just
  // receives zero inputs. For vectorized multiplications (incl. Montgomery) the
  // adder_result_blanked is blanked. These blankers are exclusively used for the whole duration of
  // an instruction.
  // For a regular multiplication shift_acc only applies to the new value written to the
  // accumulator.
  // P3: on the fold unit's write-back phase a fused P-256 multiply returns its own result instead
  // of the MAC adder output.
  //
  // The write-back phase is the fold unit's last busy cycle (cycle 27 of the serial schedule, the
  // cycle `P256Fold_WB` in the plan's table, overlap would be 21), which is the very cycle this
  // instruction commits its WDR write.  The unit's own wd_valid_o/wd_o are registered, so they
  // would only be valid one cycle later - after retirement.  During phase 21 the unit holds the
  // finished result in f_q (it assigns wd_d = f_q[255:0] out of that same value), so the result is
  // taken from there directly.  The result is < p < 2^256: the low 256 bits are the whole value.
  //
  // Gated by is_p256 as well, so that a stray pulse cannot displace another instruction's result.
  // P4：写回/退休拍随调度走 —— serial（P3）在 c27、overlap（P4 主方案）在 c21。
  logic [4:0] p256_wb_cycle;
  assign p256_wb_cycle = p256_serial_mode_i ? 5'd27 : 5'd21;
  logic p256_fold_wb;
  assign p256_fold_wb = (p256_fold_cycle == p256_wb_cycle) & p256_fold_busy;

  assign operation_result_o = (predec_i.is_p256 & p256_fold_wb) ?
                                  p256_fold_f[255:0] : (acc_merged | adder_result_blanked);
  assign operation_valid_o  = predec_i.operation_valid_raw & predec_i.mac_en;

  // The fold unit's write-back phase has to be exactly the cycle the fused instruction retires:
  // that is the cycle of its single WDR write, and the only cycle the result is taken from the
  // unit.  A mismatch means the two cycle counters drifted apart (e.g. a start impulse at the
  // wrong cycle), which would silently write a wrong result.
  `ifndef SYNTHESIS
  always_ff @(posedge clk_i) begin
    if (predec_i.is_p256 && predec_i.operation_valid_raw && !p256_fold_wb) begin
      $error("P256FoldWbAtRetire: P-256 retires while the fold unit is not in its write-back phase");
    end
  end

  ////////////////////////////////////////////////////////////////////////////////
  // P4 逐拍事件记录（仅仿真；功能路径不受影响）—— 05_P4_打开overlap.md §5.1/§5.2
  ////////////////////////////////////////////////////////////////////////////////
  // 口径：全部取**当拍内部信号**，不从退休 E 反推（§12.3）。fold_we 由「fold 忙 + 相位落在
  // 10…20」推出，并另记一列 f_changed（F 的值真的变了）作为**独立互证**：两者若在某拍不一致，
  // 该拍就会暴露出来，而不是被静默吞掉。
  int          p256_ev_fd;
  logic        p256_ev_open;
  logic [4:0]  p256_ev_phase;      // fold 的语义相位（serial 时 ≥10 减 6）
  logic        p256_ev_micro;      // mac_micro_commit
  logic        p256_ev_fwe;        // fold_we
  logic        p256_ev_wdr;        // WDR 写回（退休拍）
  logic        p256_ev_fchg;       // F 当拍发生变化
  logic [259:0] p256_ev_fprev;
  int          p256_ev_rows;
  int          p256_ev_n_micro, p256_ev_n_row, p256_ev_n_seed, p256_ev_n_merge;
  int          p256_ev_n_quot, p256_ev_n_corr, p256_ev_n_overlap, p256_ev_n_wb, p256_ev_n_err;
  // 重叠周期号：最多 6 个，各自 5 位独立寄存器（不用 string、也不用变址——两者都可能触发
  // 老版 Verilator 的告警，而本流程把告警当错）。未使用时保持 5'd31。
  logic [4:0] p256_ev_ov0, p256_ev_ov1, p256_ev_ov2, p256_ev_ov3, p256_ev_ov4, p256_ev_ov5;

  // 事件记录**总开关**（默认关）：不打印、不写 CSV、不计数 ⇒ 日常回归安静。
  // 取证据时用运行期 plusarg（与 p256_serial 同一套路，**不需要重建** Verilator 模型）：
  //   芯片仿真：bazel test … --test_arg=--verilator-args=+p256_event_trace=1
  //   独立仿真：Votbn_top_sim --load-elf=… +p256_event_trace=1
  logic        p256_ev_en;
  int          p256_ev_arg;
  initial begin
    p256_ev_en = 1'b0;
    if ($value$plusargs("p256_event_trace=%d", p256_ev_arg)) begin
      p256_ev_en = p256_ev_arg[0];
    end
  end

  assign p256_ev_phase = (p256_serial_mode_i && (p256_fold_cycle >= 5'd10)) ? (p256_fold_cycle - 5'd6)
                                                                            : p256_fold_cycle;
  assign p256_ev_micro = predec_i.is_p256 & acc_wr_en;
  assign p256_ev_fwe   = p256_fold_busy & (p256_ev_phase >= 5'd10) & (p256_ev_phase <= 5'd20);
  assign p256_ev_wdr   = predec_i.is_p256 & operation_valid_o & mac_commit_i & p256_fold_busy;
  assign p256_ev_fchg  = (p256_fold_f != p256_ev_fprev);

  initial begin
    p256_ev_fd = 0;
    p256_ev_open = 1'b0;
    if (p256_ev_en) begin
      p256_ev_fd = $fopen("otbn_p256_events.csv", "w");
      p256_ev_open = (p256_ev_fd != 0);
      if (p256_ev_open) begin
        $fwrite(p256_ev_fd, "cycle,mac_micro_commit,fold_we,wdr_we,fold_f_changed,fold_phase\n");
      end else begin
        $error("P256EV: could not open otbn_p256_events.csv");
      end
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      p256_ev_fprev <= '0;
      p256_ev_rows <= 0;
      p256_ev_n_micro <= 0; p256_ev_n_row <= 0; p256_ev_n_seed <= 0; p256_ev_n_merge <= 0;
      p256_ev_n_quot <= 0;  p256_ev_n_corr <= 0; p256_ev_n_overlap <= 0; p256_ev_n_wb <= 0;
      p256_ev_n_err <= 0;
      p256_ev_ov0 <= 5'd31; p256_ev_ov1 <= 5'd31; p256_ev_ov2 <= 5'd31;
      p256_ev_ov3 <= 5'd31; p256_ev_ov4 <= 5'd31; p256_ev_ov5 <= 5'd31;
    end else if (p256_ev_en) begin      // 默认关：整块（计数 + CSV + 打印）都不执行
      p256_ev_fprev <= p256_fold_f;
      if (p256_fold_busy) begin
        p256_ev_rows <= p256_ev_rows + 1;
        if (p256_ev_open) begin
          $fwrite(p256_ev_fd, "%0d,%0d,%0d,%0d,%0d,%0d\n", p256_fold_cycle, p256_ev_micro,
                  p256_ev_fwe, p256_ev_wdr, p256_ev_fchg, p256_ev_phase);
        end
        if (p256_ev_micro) p256_ev_n_micro <= p256_ev_n_micro + 1;
        if (p256_ev_fwe) begin
          if (p256_ev_phase <= 5'd17)      p256_ev_n_row   <= p256_ev_n_row + 1;
          else if (p256_ev_phase == 5'd18) p256_ev_n_merge <= p256_ev_n_merge + 1;
          else if (p256_ev_phase == 5'd19) p256_ev_n_quot  <= p256_ev_n_quot + 1;
          else                             p256_ev_n_corr  <= p256_ev_n_corr + 1;
        end
        if (p256_fold_cycle == 5'd3) p256_ev_n_seed <= p256_ev_n_seed + 1;
        if (p256_ev_micro && p256_ev_fwe) begin
          unique case (p256_ev_n_overlap)
            0: p256_ev_ov0 <= p256_fold_cycle;
            1: p256_ev_ov1 <= p256_fold_cycle;
            2: p256_ev_ov2 <= p256_fold_cycle;
            3: p256_ev_ov3 <= p256_fold_cycle;
            4: p256_ev_ov4 <= p256_fold_cycle;
            5: p256_ev_ov5 <= p256_fold_cycle;
            default: ;   // 超过 6 个重叠周期：计数仍加 1，周期号槽位不再记录
          endcase
          p256_ev_n_overlap <= p256_ev_n_overlap + 1;
        end
        if (p256_ev_wdr) p256_ev_n_wb <= p256_ev_n_wb + 1;
        if (predec_error_o | state_err_o | operation_intg_violation_err_o | sec_wipe_err_o) begin
          p256_ev_n_err <= p256_ev_n_err + 1;
        end
      end
      // 指令结束（写回拍）时打印 9 个计数，并把重叠周期号单独列出（§5.2：只给总数不算证明）。
      // 打印值含**当拍**贡献（计数用非阻塞赋值，当拍尚未落账）。
      if (p256_ev_wdr) begin
        $display("P256EV micro_mul=%0d fold_row=%0d fold_seed=%0d fold_merge=%0d fold_quot=%0d fold_corr=%0d overlap=%0d wb=%0d err=%0d rows=%0d ov_cycles[c0]=%0d,%0d,%0d,%0d,%0d,%0d",
                 p256_ev_n_micro, p256_ev_n_row, p256_ev_n_seed, p256_ev_n_merge, p256_ev_n_quot,
                 p256_ev_n_corr, p256_ev_n_overlap,
                 p256_ev_n_wb + 1, p256_ev_n_err, p256_ev_rows,
                 p256_ev_ov0, p256_ev_ov1, p256_ev_ov2, p256_ev_ov3, p256_ev_ov4, p256_ev_ov5);
        p256_ev_n_micro <= 0; p256_ev_n_row <= 0; p256_ev_n_seed <= 0; p256_ev_n_merge <= 0;
        p256_ev_n_quot <= 0;  p256_ev_n_corr <= 0; p256_ev_n_overlap <= 0; p256_ev_n_wb <= 0;
        p256_ev_n_err <= 0;   p256_ev_rows <= 0;
        p256_ev_ov0 <= 5'd31; p256_ev_ov1 <= 5'd31; p256_ev_ov2 <= 5'd31;
        p256_ev_ov3 <= 5'd31; p256_ev_ov4 <= 5'd31; p256_ev_ov5 <= 5'd31;
      end
    end
  end
  `endif

  /////////////////////
  // Integrity error //
  /////////////////////
  // Propagate integrity error only if a register is used and MAC is enabled
  logic tmp_used;
  logic c_used;
  logic mod_used;
  logic acc_used;
  // TMP is used if multiplier operand a is set to TMP
  assign tmp_used = predec_i.mac_en && !predec_i.mul_op_a_tmp_sel;
  // c is used if its blanker is enabled
  assign c_used = predec_i.mac_en & predec_i.c_add_en;
  // MOD is used if modulo operation is active
  assign mod_used = predec_i.mac_en && predec_i.is_mod;
  // The ACC is used if we do not reset it (regular mul) or require it to merge the current
  // quarter word. P3：P-256 每个累加拍都读 ACC（除非该拍 acc_zero 把它清零）⇒ 必须计入完整性检查，
  // 否则新指令的 ACC 损坏会被漏检。
  assign acc_used = predec_i.mac_en && (predec_i.acc_merger_en || predec_i.acc_add_en ||
                                        (predec_i.is_p256 && !predec_i.acc_zero));

  assign operation_intg_violation_err_o = (tmp_used && |(tmp_intg_err)) ||
                                          (c_used   && |(c_intg_err))   ||
                                          (mod_used && |(mod_intg_err)) ||
                                          (acc_used && |(acc_intg_err));

  //////////////////////
  // Redundancy check //
  //////////////////////
  // SEC_CM: CTRL.REDUN
  assign predec_error_o = expected_predec != predec_i;

  /////////////////////////////////////
  // Register and secure wipe output //
  /////////////////////////////////////
  assign ispr_acc_intg_o = acc_intg_q;

  assign sec_wipe_err_o = sec_wipe_urnd_i & ~sec_wipe_running_i;

  `ASSERT(NoISPRAccWrAndMacEn, ~(ispr_acc_wr_en_i & mac_en_i))

  // Only one QWORD must be overwritten at the same time.
  `ASSERT(AccQwSelOnehot_A,
          predec_i.acc_merger_en |-> $onehot(predec_i.acc_qw_sel),
          clk_i, !rst_ni || predec_error_o || state_err_o)

  // the code below is not meant to be synthesized,
  // but it is intended to be used in simulation
  `ifndef SYNTHESIS
    // Check that the supplied permutation is valid.
    logic [WLEN-1:0] perm_test;
    initial begin : p_perm_check
      perm_test = '0;
      for (int k = 0; k < WLEN; k++) begin
        perm_test[RndCnstBnMacUrndPerm[k]] = 1'b1;
      end
      // All bit positions must be marked with 1.
      `ASSERT_I(PermutationCheck_A, &perm_test)
    end
  `endif

endmodule
