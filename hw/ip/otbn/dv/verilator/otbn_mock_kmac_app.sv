// KMAC co-sim mock for OTBN RTL co-simulation.

module otbn_mock_kmac_app
  import kmac_pkg::*;
(
  input  logic     clk_i,
  input  logic     rst_ni,
  input  app_req_t app_req_i,
  output app_rsp_t app_rsp_o
);

  localparam logic [DynAppDigestW-1:0] FixedDigest [8] = '{
    64'hDEAD_BEEF_0000_0001,
    64'hDEAD_BEEF_0000_0002,
    64'hDEAD_BEEF_0000_0003,
    64'hDEAD_BEEF_0000_0004,
    64'hDEAD_BEEF_0000_0005,
    64'hDEAD_BEEF_0000_0006,
    64'hDEAD_BEEF_0000_0007,
    64'hDEAD_BEEF_0000_0008
  };
  localparam int KECCAK_DELAY = 96;

  typedef enum logic [2:0] {
    MockStIdle, MockStWaitMsg, MockStSending, MockStProcessing,
    MockStResponding, MockStRspGap, MockStWaitDone, MockStFinishing
  } state_e;
  state_e state_q, state_d;

  typedef logic [2:0] beat_idx_t;
  beat_idx_t beat_cnt_q, beat_cnt_d;
  logic [7:0] delay_cnt_q, delay_cnt_d;

  app_rsp_t app_rsp_d;
  always_comb begin
    app_rsp_d = APP_RSP_DEFAULT;
    state_d = state_q;
    beat_cnt_d = beat_cnt_q;
    delay_cnt_d = delay_cnt_q;

    unique case (state_q)
      MockStIdle: begin
        if (app_req_i.req_valid && app_req_i.req_last == 1'b0) begin
          app_rsp_d.req_ready = 1'b1;
          state_d = MockStWaitMsg;
        end
      end
      MockStWaitMsg: begin
        if (app_req_i.req_valid) begin
          app_rsp_d.req_ready = 1'b1;
          if (app_req_i.req_last) begin
            delay_cnt_d = KECCAK_DELAY[7:0];
            state_d = MockStProcessing;
          end else
            state_d = MockStSending;
        end
      end
      MockStSending: begin
        if (app_req_i.req_valid) begin
          app_rsp_d.req_ready = 1'b1;
          if (app_req_i.req_last) begin
            delay_cnt_d = KECCAK_DELAY[7:0];
            state_d = MockStProcessing;
          end
        end
      end
      MockStProcessing: begin
        if (app_req_i.req_valid && app_req_i.req_last) begin
          app_rsp_d.req_ready = 1'b1;
          state_d = MockStFinishing;
        end else if (delay_cnt_q > 0) begin
          delay_cnt_d = delay_cnt_q - 1;
        end else begin
          beat_cnt_d = 0;
          state_d = MockStResponding;
        end
      end
      MockStResponding: begin
        app_rsp_d.rsp_valid = 1'b1;
        app_rsp_d.digest_s0[DynAppDigestW-1:0] = FixedDigest[beat_cnt_q];
        app_rsp_d.digest_s1[DynAppDigestW-1:0] = FixedDigest[beat_cnt_q];
        if (app_req_i.req_valid && app_req_i.req_last) begin
          app_rsp_d.req_ready = 1'b1;
          app_rsp_d.rsp_valid = 1'b0;
          state_d = MockStFinishing;
        end else if (app_req_i.rsp_ready) begin
          beat_cnt_d = beat_cnt_q + 1;
          state_d = MockStRspGap;
        end
      end
      MockStRspGap: begin
        state_d = MockStResponding;
      end
      MockStWaitDone: begin
        if (app_req_i.req_valid && app_req_i.req_last) begin
          app_rsp_d.req_ready = 1'b1;
          state_d = MockStFinishing;
        end
      end
      MockStFinishing: begin
        app_rsp_d.rsp_valid  = 1'b1;
        app_rsp_d.rsp_finish = 1'b1;
        if (app_req_i.rsp_ready)
          state_d = MockStIdle;
      end
      default: state_d = MockStIdle;
    endcase

    if (!rst_ni) begin
      state_d    = MockStIdle;
      beat_cnt_d = 0;
      delay_cnt_d = 0;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q    <= MockStIdle;
      beat_cnt_q <= '0;
      delay_cnt_q <= '0;
    end else begin
      state_q    <= state_d;
      beat_cnt_q <= beat_cnt_d;
      delay_cnt_q <= delay_cnt_d;
    end
  end

  assign app_rsp_o = app_rsp_d;

endmodule
