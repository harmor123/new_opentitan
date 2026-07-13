// otbn_kmac standalone testbench — Verilator 5.x
//   1 is replaced by run_tb.sh: 0=DV, 1=SCA
module tb;
  import otbn_pkg::*;
  logic clk=0, rst_n=0;
  logic [UrndLen-1:0] urnd;
  assign urnd = dom_prng_out[UrndLen-1:0];
  logic sw=0, sr=0, cw=0, ms=0, sbw=0, iw=0;
  logic [31:0] cwd='0, crd, ifs, st, ird, erd;
  logic sow=0,s1w=0,sowp=0,s1wp=0,sord=0,s1rd=0;
  logic [ExtWLEN-1:0] sowd='0,s1wd='0,sordat,s1rdat;
  logic dval=0,daux=0,dadv, ke;
  logic [KmacDomWidth-1:0] ddat='0;

  // Minimal self-seeding 800b Trivium for DOM masking (EnMasking=1)
  logic [2:0] dom_seed_cnt=0;
  logic dom_seed_en=0, dom_seed_done=0;
  always @(posedge clk) begin
    if(!rst_n) begin dom_seed_cnt<=0; dom_seed_en<=0; end
    else if(dom_seed_cnt<4) begin dom_seed_cnt<=dom_seed_cnt+1; dom_seed_en<=(dom_seed_cnt==2); end
    else dom_seed_en<=0;
  end
  logic [KmacDomWidth-1:0] dom_prng_out;
  prim_trivium #(
    .BiviumVariant(1), .OutputWidth(KmacDomWidth),
    .StrictLockupProtection(1), .SeedType(prim_trivium_pkg::SeedTypeStatePartial),
    .PartialSeedWidth(32)
  ) u_dom_trivium (
    .clk_i(clk), .rst_ni(rst_n), .en_i(dadv), .allow_lockup_i(0),
    .seed_en_i(dom_seed_en), .seed_done_o(dom_seed_done),
    .seed_req_o(), .seed_ack_i(1), .seed_key_i('0), .seed_iv_i('0),
    .seed_state_full_i('0), .seed_state_partial_i(32'hDEAD_BEEF),
    .key_o(dom_prng_out), .err_o()
  );
  always @(posedge clk) begin
    if(!rst_n) dval<=0;
    else if(dom_seed_done) dval<=1;
  end
  always @(posedge clk) if(dadv) ddat<=dom_prng_out;

  otbn_kmac #(.EnMasking(1)) dut(
    .clk_i(clk), .rst_ni(rst_n), .urnd_data_i(urnd),
    .sec_wipe_kmac_i(sw), .sec_wipe_running_i(sr),
    .ispr_kmac_ctrl_wr_i(cw), .ispr_kmac_ctrl_wdata_i(cwd),
    .ispr_kmac_msg_send_wr_i(ms), .ispr_kmac_byte_strobe_wr_i(sbw), .ispr_kmac_intr_wr_i(iw),
    .ispr_kmac_ctrl_rdata_o(crd), .ispr_kmac_if_status_rdata_o(ifs),
    .ispr_kmac_status_rdata_o(st), .ispr_kmac_intr_rdata_o(ird), .ispr_kmac_error_rdata_o(erd),
    .ispr_kmac_data_s0_wr_i(sow), .sec_wipe_kmac_data_s0_i(sowp), .ispr_kmac_data_s0_wdata_i(sowd),
    .ispr_kmac_data_s1_wr_i(s1w), .sec_wipe_kmac_data_s1_i(s1wp), .ispr_kmac_data_s1_wdata_i(s1wd),
    .ispr_kmac_data_s0_rd_i(sord), .ispr_kmac_data_s1_rd_i(s1rd),
    .ispr_kmac_data_s0_rdata_o(sordat), .ispr_kmac_data_s1_rdata_o(s1rdat),
    .kmac_dom_rand_valid_i(dval), .kmac_dom_rand_data_i(ddat),
    .kmac_dom_rand_aux_i(daux), .kmac_dom_rand_advance_o(dadv), .kmac_state_err_o(ke)
  );

  always #5 clk = ~clk;
  task wclk(int n=1); repeat(n) @(posedge clk); endtask
  function [63:0] rde(input [ExtWLEN-1:0] r); return {r[70:39], r[31:0]}; endfunction
  task cwr(input [31:0] d); cwd=d; cw=1; wclk; cw=0; endtask
  task wswr(input [WLEN-1:0] s0,s1);
    sowd='0; s1wd='0;
    for(int i=0;i<BaseWordsPerWLEN;i++) begin sowd[i*39+:32]=s0[i*32+:32]; s1wd[i*39+:32]=s1[i*32+:32]; end
    sow=1;s1w=1; wclk; sow=0;s1w=0;
  endtask
  task msend(); ms=1; wclk; ms=0; endtask
  task wrdy(); while(!ifs[0]) @(posedge clk); endtask
  task wdv(); while(!ifs[3]) @(posedge clk); endtask
  task rdword(output logic [63:0] w); sord=1;wclk;sord=0; s1rd=1;wclk;s1rd=0; w=rde(sordat)^rde(s1rdat); endtask

  int fail=0;
  `include "kat_expected.svh"

  // Generic test runner: returns digest words in got[]
  task run(int mode,int strength,int dw,logic[7:0] m[256],int ml,output logic[63:0] got[32],output int gn);
    logic [WLEN-1:0] s0wrd,s1wrd; logic [31:0] sb; int b; logic [63:0] w;
    cwr({26'h0,2'(mode),3'(strength),1'b1}); cwr(32'h1D); wrdy();
    b=0; gn=0;
    while(b<ml) begin
      wrdy(); s0wrd='0; s1wrd='0; sb='0;
      for(int j=0;j<32&&b<ml;j++) begin s0wrd[j*8+:8]=m[b]; sb[j]=1; b++; end
      cwd=sb; sbw=1; wclk; sbw=0; wswr(s0wrd,s1wrd); msend(); wclk;
    end
    cwr(32'h2E);
    for(int i=0;i<dw;i++) begin wdv(); rdword(w); got[i]=w; gn++; end
    cwr(32'h16);
  endtask

  // SHA3 checker (compare got[gn] vs kat[N])
  task chk4(input logic[63:0] got[32], int gn, input logic[63:0] kat[4], string nm);
    for(int i=0;i<4;i++) if(got[i]!=kat[i]) begin
      $display("[FAIL] %s w[%0d] got=0x%016x exp=0x%016x",nm,i,got[i],kat[i]); fail++; return; end
    $display("[PASS] %s",nm);
  endtask
  task chk8(input logic[63:0] got[32], int gn, input logic[63:0] kat[8], string nm);
    for(int i=0;i<8;i++) if(got[i]!=kat[i]) begin
      $display("[FAIL] %s w[%0d] got=0x%016x exp=0x%016x",nm,i,got[i],kat[i]); fail++; return; end
    $display("[PASS] %s",nm);
  endtask
  task chk32(input logic[63:0] got[32], int gn, input logic[63:0] kat[32], string nm);
    if(gn!=32) begin $display("[FAIL] %s cnt=%0d",nm,gn); fail++; return; end
    for(int i=0;i<32;i++) if(got[i]!=kat[i]) begin
      $display("[FAIL] %s w[%0d] got=0x%016x exp=0x%016x",nm,i,got[i],kat[i]); fail++; return; end
    $display("[PASS] %s",nm);
  endtask
  task chkN(input logic[63:0] got[32], int gn, input logic[63:0] kat[24], int kw, string nm);
    if(gn!=kw) begin $display("[FAIL] %s cnt=%0d exp=%0d",nm,gn,kw); fail++; return; end
    for(int i=0;i<kw;i++) if(got[i]!=kat[i]) begin
      $display("[FAIL] %s w[%0d] got=0x%016x exp=0x%016x",nm,i,got[i],kat[i]); fail++; return; end
    $display("[PASS] %s",nm);
  endtask
  task chk4o(input logic[63:0] got[32], int gn, input logic[63:0] kat[4], int off, string nm);
    if(gn<off+4) begin $display("[FAIL] %s cnt=%0d",nm,gn); fail++; return; end
    for(int i=0;i<4;i++) if(got[off+i]!=kat[i]) begin
      $display("[FAIL] %s w[%0d] got=0x%016x exp=0x%016x",nm,i,got[off+i],kat[i]); fail++; return; end
    $display("[PASS] %s",nm);
  endtask

  initial begin
    rst_n=0; wclk(8); rst_n=1; wclk;
    $display("=== otbn_kmac testbench (Verilator 5.x) ===");
    begin logic[63:0]g[32],w;int gn;logic[7:0]m[256];
      // 1: SHA3-256("")
      run(0,2,4,m,0,g,gn); chk4(g,gn,kat_SHA3_256_EMPTY,"SHA3-256(\"\")");
      // 2: SHA3-256("what do ")
      m[0]=8'h77;m[1]=8'h68;m[2]=8'h61;m[3]=8'h74;m[4]=8'h20;m[5]=8'h64;m[6]=8'h6f;m[7]=8'h20;
      run(0,2,4,m,8,g,gn); chk4(g,gn,kat_SHA3_256_MSG,"SHA3-256(what do )");
      // 3: SHA3-256 128B pad=1
      for(int i=0;i<128;i++)m[i]=0;
      run(0,2,4,m,128,g,gn); chk4(g,gn,kat_SHA3_256_128B_PAD1,"SHA3-256(128B pad=1)");
      // 4: SHA3-256 136B rate-full
      for(int i=0;i<17;i++) begin m[i*8+0]=8'h72;m[i*8+1]=8'h61;m[i*8+2]=8'h74;m[i*8+3]=8'h65;
        m[i*8+4]=8'h31;m[i*8+5]=8'h33;m[i*8+6]=8'h36;m[i*8+7]=8'h21; end
      run(0,2,4,m,136,g,gn); chk4(g,gn,kat_SHA3_256_136B,"SHA3-256(136B rate-full)");
      // 5: SHA3-512("")
      for(int i=0;i<256;i++)m[i]=0;
      run(0,4,8,m,0,g,gn); chk8(g,gn,kat_SHA3_512_EMPTY,"SHA3-512(\"\")");
      // 6: SHA3-512 64B pad=1
      for(int i=0;i<64;i++)m[i]=0;
      run(0,4,8,m,64,g,gn); chk8(g,gn,kat_SHA3_512_64B_PAD1,"SHA3-512(64B pad=1)");
      // 7: SHAKE128 empty
      run(2,0,4,m,0,g,gn); chk4(g,gn,kat_SHAKE128_EMPTY,"SHAKE128(\"\")");
      // 8: SHAKE256 empty
      run(2,2,4,m,0,g,gn); chk4(g,gn,kat_SHAKE256_EMPTY,"SHAKE256(\"\")");
      // 9: SHAKE256 "what do "
      m[0]=8'h77;m[1]=8'h68;m[2]=8'h61;m[3]=8'h74;m[4]=8'h20;m[5]=8'h64;m[6]=8'h6f;m[7]=8'h20;
      run(2,2,4,m,8,g,gn); chk4(g,gn,kat_SHAKE256_MSG,"SHAKE256(\"what do \")");
      // 10: SHAKE128 168B→64B
      for(int i=0;i<168;i++)m[i]=0;
      run(2,0,8,m,168,g,gn); chk8(g,gn,kat_SHAKE128_168B_TO_64B,"SHAKE128(168B,64B)");
      // 11: SHAKE128 34B→32B
      for(int i=0;i<34;i++)m[i]=0;
      run(2,0,4,m,34,g,gn); chk4(g,gn,kat_SHAKE128_34B_TO_32B,"SHAKE128(34B,32B)");
      // 12: SHAKE128 33B→32B (partial tail)
      for(int i=0;i<33;i++)m[i]=0;
      run(2,0,4,m,33,g,gn); chk4(g,gn,kat_SHAKE128_33B,"SHAKE128(33B,32B)");
      // 13: SHAKE128 35B→32B (partial tail)
      for(int i=0;i<35;i++)m[i]=0;
      run(2,0,4,m,35,g,gn); chk4(g,gn,kat_SHAKE128_35B,"SHAKE128(35B,32B)");
      // 14: SHAKE128 127B→32B (partial tail)
      for(int i=0;i<127;i++)m[i]=0;
      run(2,0,4,m,127,g,gn); chk4(g,gn,kat_SHAKE128_127B,"SHAKE128(127B,32B)");
      // 15: SHAKE128 168B rate-cross: squeeze 256B > 168B rate
      // 15: SHAKE128 256B "what do " → 6×32B (rate=21w, 6th batch crosses, auto-RUN)
      for(int i=0;i<32;i++) begin m[i*8+0]=8'h77;m[i*8+1]=8'h68;m[i*8+2]=8'h61;m[i*8+3]=8'h74;
        m[i*8+4]=8'h20;m[i*8+5]=8'h64;m[i*8+6]=8'h6f;m[i*8+7]=8'h20; end
      run(2,0,21,m,256,g,gn);  // squeeze first 21 words (rate=21)
      cwr(32'h31); while(!st[2]) @(posedge clk);  // RUN: rate exhausted
      for(int i=0;i<3;i++) begin wdv(); rdword(w); g[gn]=w; gn++; end  // 3 more = 24 total
      cwr(32'h16);
      chkN(g,gn,kat_SHAKE128_RC,24,"SHAKE128 rate-cross");
      // ── Additional smoke test cases ──
      // 16: SHA3-512 "what do "
      m[0]=8'h77;m[1]=8'h68;m[2]=8'h61;m[3]=8'h74;m[4]=8'h20;m[5]=8'h64;m[6]=8'h6f;m[7]=8'h20;
      run(0,4,8,m,8,g,gn); chk8(g,gn,kat_SHA3_512_MSG,"SHA3-512(what do )");
      // 17-22: SHA3-256 edge cases
      for(int i=0;i<32;i++)m[i]=0;
      run(0,2,4,m,32,g,gn); chk4(g,gn,kat_SHA3_256_32B,"SHA3-256(32B)");
      for(int i=0;i<32;i++)m[i]=0; m[32]=1;
      run(0,2,4,m,33,g,gn); chk4(g,gn,kat_SHA3_256_33B,"SHA3-256(33B)");
      for(int i=0;i<32;i++)m[i]=0; m[32]=1; m[33]=2; m[34]=3;
      run(0,2,4,m,35,g,gn); chk4(g,gn,kat_SHA3_256_35B,"SHA3-256(35B)");
      for(int i=0;i<64;i++)m[i]=0;
      run(0,2,4,m,64,g,gn); chk4(g,gn,kat_SHA3_256_64B,"SHA3-256(64B)");
      for(int i=0;i<127;i++)m[i]=0;
      run(0,2,4,m,127,g,gn); chk4(g,gn,kat_SHA3_256_127B,"SHA3-256(127B)");
      for(int i=0;i<32;i++) begin m[i*8+0]=8'h77;m[i*8+1]=8'h68;m[i*8+2]=8'h61;m[i*8+3]=8'h74;
        m[i*8+4]=8'h20;m[i*8+5]=8'h64;m[i*8+6]=8'h6f;m[i*8+7]=8'h20; end
      run(0,2,4,m,256,g,gn); chk4(g,gn,kat_SHA3_256_2048B,"SHA3-256(2048B)");
      // 23: SHA3-256 137B (136B rate+"!"+1 extra byte=0xFF, partial last word)
      for(int i=0;i<17;i++) begin m[i*8+0]=8'h72;m[i*8+1]=8'h61;m[i*8+2]=8'h74;m[i*8+3]=8'h65;
        m[i*8+4]=8'h31;m[i*8+5]=8'h33;m[i*8+6]=8'h36;m[i*8+7]=8'h21; end
      m[136]=8'hFF;
      run(0,2,4,m,137,g,gn); chk4(g,gn,kat_SHA3_256_136B_PLUS1,"SHA3-256(136B+1)");
      // 24: SHAKE128 "what do "
      m[0]=8'h77;m[1]=8'h68;m[2]=8'h61;m[3]=8'h74;m[4]=8'h20;m[5]=8'h64;m[6]=8'h6f;m[7]=8'h20;
      run(2,0,4,m,8,g,gn); chk4(g,gn,kat_SHAKE128_MSG,"SHAKE128(what do )");
      // 25: SHAKE128 64B RUN (2×32B squeeze with auto-RUN in HW _ensure_digest)
      run(2,0,8,m,8,g,gn); chk4(g,gn,kat_SHAKE128_64B_RUN_B1,"SHAKE128(8B->64B) b1");
      chk4o(g,gn,kat_SHAKE128_64B_RUN_B2,4,"SHAKE128(8B->64B) b2");
      // 26-27: SHAKE large messages
      for(int i=0;i<512;i++) begin m[i*8+0]=8'h77;m[i*8+1]=8'h68;m[i*8+2]=8'h61;m[i*8+3]=8'h74;
        m[i*8+4]=8'h20;m[i*8+5]=8'h64;m[i*8+6]=8'h6f;m[i*8+7]=8'h20; end
      run(2,0,4,m,4096,g,gn); chk4(g,gn,kat_SHAKE128_4096B,"SHAKE128(4096B)");
      run(2,2,4,m,4096,g,gn); chk4(g,gn,kat_SHAKE256_4096B,"SHAKE256(4096B)");
      // 28-31: Pad edge cases
      for(int i=0;i<160;i++)m[i]=0;
      run(2,0,4,m,160,g,gn); chk4(g,gn,kat_SHAKE128_160B_PAD1,"SHAKE128(160B pad=1)");
      for(int i=0;i<128;i++)m[i]=0;
      run(2,2,4,m,128,g,gn); chk4(g,gn,kat_SHAKE256_128B_PAD1,"SHAKE256(128B pad=1)");
      for(int i=0;i<120;i++)m[i]=0;
      run(0,2,4,m,120,g,gn); chk4(g,gn,kat_SHA3_256_120B_PAD2,"SHA3-256(120B pad=2)");
      for(int i=0;i<56;i++)m[i]=0;
      run(0,4,8,m,56,g,gn); chk8(g,gn,kat_SHA3_512_56B_PAD2,"SHA3-512(56B pad=2)");
    end
    $display("=== %s ===", fail?"FAIL":"ALL 31 TESTS PASSED"); $finish;
  end
endmodule
