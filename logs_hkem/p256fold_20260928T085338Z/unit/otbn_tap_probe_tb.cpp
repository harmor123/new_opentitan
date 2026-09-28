// 诊断 TB（配 otbn_tap_probe.sv）：**与 P2 单元 TB 完全相同的 tick 写法与 VCD 流程**，
// 逐拍打印三件事，把「TB 写的 tap 何时被锁存、计数器何时可见 +1」变成可直接核对的事实：
//   ① 本拍写入值 M_k
//   ② clk 上升沿 eval 之后立即读（mid=沿后立刻）
//   ③ clk 回到低电平 eval 之后读（end=整拍末，也就是 P2 TB 读输出的时刻）
// 判定（不需要任何猜测）：
//   * 若 end.cap == M_k 且 end.cnt == k+1 ⇒ 同拍锁存、P2 TB 的对齐口径成立；
//   * 若 end.cap == M_{k-1}（或 end.cnt 不按 +1 走）⇒ 该流程里 flop 更新在整拍末**尚不可见**，
//     P2 TB 的「读回确认推进」就会多送一个沿 ⇒ 必须改驱动口径。

#include <cstdint>
#include <cstdio>
#include <cstring>

#include "Votbn_tap_probe.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

static constexpr int kWords = 8;   // 256 bit / 32

struct Snap {
  uint32_t cap[kWords];
  unsigned cnt, busy;
};

static Snap snap(Votbn_tap_probe *dut) {
  Snap s;
  const uint32_t *c = reinterpret_cast<const uint32_t *>(&dut->cap_o);
  for (int i = 0; i < kWords; i++) s.cap[i] = c[i];
  s.cnt = (unsigned)dut->cnt_o;
  s.busy = (unsigned)dut->busy_o;
  return s;
}

static void put(uint32_t *w, uint32_t lo) {
  for (int i = 0; i < kWords; i++) w[i] = 0;
  w[0] = lo;
}

int main(int argc, char **argv) {
  VerilatedContext *const ctx = new VerilatedContext;
  ctx->commandArgs(argc, argv);
  ctx->traceEverOn(true);

  Votbn_tap_probe *const dut = new Votbn_tap_probe(ctx, "TOP");
  VerilatedVcdC *const vcd = new VerilatedVcdC;
  dut->trace(vcd, 99);
  vcd->open("dump_probe.vcd");

  uint32_t *tap = reinterpret_cast<uint32_t *>(&dut->tap_i);

  dut->clk_i = 0;
  dut->rst_ni = 0;
  dut->start_i = 0;
  put(tap, 0);
  dut->eval();
  for (int i = 0; i < 4; i++) {          // 复位 4 拍（与 P2 TB 一致）
    dut->clk_i = 1; dut->eval(); vcd->dump(ctx->time()); ctx->timeInc(1);
    dut->clk_i = 0; dut->eval(); vcd->dump(ctx->time()); ctx->timeInc(1);
  }
  dut->rst_ni = 1;
  dut->clk_i = 1; dut->eval(); vcd->dump(ctx->time()); ctx->timeInc(1);
  dut->clk_i = 0; dut->eval(); vcd->dump(ctx->time()); ctx->timeInc(1);
  Snap s0 = snap(dut);
  printf("复位释放后: cnt_o=%u busy_o=%u cap_o[0]=0x%08x\n", s0.cnt, s0.busy, (unsigned)s0.cap[0]);

  const uint32_t kBase = 0x0A000000u;    // M_k = kBase + k
  printf("\n k | 写入 M_k | 沿后立刻 cap/cnt | 整拍末 cap/cnt | 整拍末 busy\n");
  for (int k = 0; k < 8; k++) {
    uint32_t m = kBase + (uint32_t)k;
    put(tap, m);
    dut->clk_i = 1;
    dut->eval();
    Snap mid = snap(dut);
    vcd->dump(ctx->time()); ctx->timeInc(1);
    dut->clk_i = 0;
    dut->eval();
    Snap end = snap(dut);
    vcd->dump(ctx->time()); ctx->timeInc(1);
    printf(" %d | 0x%08x | 0x%08x / %u     | 0x%08x / %u    | %u  %s%s\n",
           k, (unsigned)m, (unsigned)mid.cap[0], mid.cnt,
           (unsigned)end.cap[0], end.cnt, end.busy,
           end.cap[0] == m ? "  <= 整拍末=本拍写入" : "",
           end.cap[0] == m - 1 ? "  <= 整拍末=上一拍写入" : "");
  }

  // 同一值连写 3 拍：观察 cnt 每拍是否 +1（区分"计数器没动"与"锁存滞后"）
  printf("\n同值连写 3 拍（M=0x0BADC0DE）: ");
  for (int i = 0; i < 3; i++) {
    put(tap, 0x0BADC0DEu);
    dut->clk_i = 1; dut->eval(); vcd->dump(ctx->time()); ctx->timeInc(1);
    dut->clk_i = 0; dut->eval(); vcd->dump(ctx->time()); ctx->timeInc(1);
    Snap e = snap(dut);
    printf("[cnt=%u cap=0x%08x] ", e.cnt, (unsigned)e.cap[0]);
  }
  printf("\n");

  dut->final();
  vcd->close();
  delete vcd;
  delete dut;
  delete ctx;
  return 0;
}
