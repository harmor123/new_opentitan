// 诊断 TB（配 otbn_tap_probe.sv 三条路径）：与 P2 单元 TB **完全相同的 tick 写法与 VCD 流程**。
// 逐拍写 tap 低 128 位 = 0x0D000000+k，整拍末读三条路径的锁存值 + 计数器，直接判定：
//   哪条结构「同拍」、哪条「晚一拍」⇒ fold unit 的 c3 采样晚一拍由哪种结构造成（事实，不推断）。

#include <cstdint>
#include <cstdio>
#include <cstring>

#include "Votbn_tap_probe.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

static constexpr int kWords = 8;   // 256 bit / 32

static void tick(Votbn_tap_probe *dut, VerilatedVcdC *vcd, VerilatedContext *ctx) {
  dut->clk_i = 1;
  dut->eval();
  vcd->dump(ctx->time());
  ctx->timeInc(1);
  dut->clk_i = 0;
  dut->eval();
  vcd->dump(ctx->time());
  ctx->timeInc(1);
}

static void put(uint32_t *w, uint32_t lo) {
  for (int i = 0; i < kWords; i++) w[i] = 0;
  w[0] = lo;
}

static uint32_t word4(const uint32_t *w) { return w[4]; }

int main(int argc, char **argv) {
  VerilatedContext *const ctx = new VerilatedContext;
  ctx->commandArgs(argc, argv);
  ctx->traceEverOn(true);

  Votbn_tap_probe *const dut = new Votbn_tap_probe(ctx, "TOP");
  VerilatedVcdC *const vcd = new VerilatedVcdC;
  dut->trace(vcd, 99);
  vcd->open("dump_probe.vcd");

  uint32_t *tap = reinterpret_cast<uint32_t *>(&dut->tap_i);
  const uint32_t *cap_d = reinterpret_cast<const uint32_t *>(&dut->cap_direct_o);
  const uint32_t *cap_c = reinterpret_cast<const uint32_t *>(&dut->cap_comb_o);
  const uint32_t *cap_c2 = reinterpret_cast<const uint32_t *>(&dut->cap_comb2_o);

  dut->clk_i = 0;
  dut->rst_ni = 0;
  dut->start_i = 0;
  put(tap, 0);
  dut->eval();
  for (int i = 0; i < 4; i++) tick(dut, vcd, ctx);
  dut->rst_ni = 1;
  tick(dut, vcd, ctx);

  const uint32_t kBase = 0x0D000000u;      // 标记 = kBase + k（k = TB 认为的第几拍）
  printf("结构分叉实验：每拍写 mark=0x0D000000+k，整拍末读三条路径\n");
  printf(" k | 写入       | cnt | 路径1 直连       | 路径2 经always_comb | 路径3 +断言块\n");
  int stale_d = 0, stale_c = 0, stale_c2 = 0, n = 0;
  for (int k = 0; k < 8; k++) {
    uint32_t m = kBase + (uint32_t)k;
    put(tap, m);
    tick(dut, vcd, ctx);
    uint32_t vd = word4(cap_d), vc = word4(cap_c), vc2 = word4(cap_c2);
    printf(" %d | 0x%08x | %3u | 0x%08x %-6s | 0x%08x %-6s    | 0x%08x %-6s\n",
           k, (unsigned)m, (unsigned)dut->cnt_o,
           (unsigned)vd, vd == m ? "同拍" : (vd == m - 1 ? "晚1拍" : "其它"),
           (unsigned)vc, vc == m ? "同拍" : (vc == m - 1 ? "晚1拍" : "其它"),
           (unsigned)vc2, vc2 == m ? "同拍" : (vc2 == m - 1 ? "晚1拍" : "其它"));
    if (k > 0) {
      n++;
      if (vd == m - 1) stale_d++;
      if (vc == m - 1) stale_c++;
      if (vc2 == m - 1) stale_c2++;
    }
  }
  printf("判定（k=1..7 共 %d 拍）：路径1 晚1拍 %d 次；路径2 晚1拍 %d 次；路径3 晚1拍 %d 次\n",
         n, stale_d, stale_c, stale_c2);
  printf("结论（事实）: %s\n",
         stale_c == 0 && stale_c2 == 0
             ? "always_comb 结构**不**造成晚一拍 ⇒ 需继续分叉（其它结构差异）"
             : (stale_d == 0 ? "只有经 always_comb 的路径晚一拍 ⇒ 根因=always_comb 中间变量"
                             : "三条路径都晚一拍 ⇒ 与 always_comb 无关"));

  dut->final();
  vcd->close();
  delete vcd;
  delete dut;
  delete ctx;
  return 0;
}
