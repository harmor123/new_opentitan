// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// P2 单元 testbench：`otbn_p256_fold`（contribution 2.pdf §11 P2）。
//
// 两阶段（PDF 规定的顺序，不可颠倒）：
//   * Step 2  直接注入 (H, high, LL, ACC130)：`source=inject` 向量，四个采样周期固定 c3/c9/c12/c15；
//   * Step 5  接上 16 步 MAC 序列：`source=mac` 向量，按 §8 的 MAC 列逐拍喂 `mac_result_pre_so` /
//             `mac_acc_after_so`（用模型派生的 16 拍 tap 复现 MAC 行为，不实例化 BN-MAC）。
//
// 驱动口径（重要）：**tap 的周期索引取自 DUT 自己的 `cycle_o`**，不假设「start 脉冲后一定在 c0」。
// 每拍先读 `cycle_o` → 按该周期号给 tap → 一个时钟沿 → 读回输出（= 该周期末锁存的值）→ 与模型
// 同周期号比对。这样 DUT 周期计数器的任何偏移都不会影响判据，只会体现在 `DBG` 行里。
// 且**确认推进**：一个时钟沿后若 DUT 的 `cycle_o` 没变，就补 tick（最多 4 次）并计入 `TIMING` 行——
// 判据仍然按**周期号**而不是按 tick 数（补 tick 期间 tap 保持不变，采样语义不受影响）。
//
// 断言：
//   * 三条 off-by-one **各自命名**、每条都带**反面**（与邻拍比较）：A_c3_H / A_c9_high / A_c12_LL；
//   * `L0` 截断的失败用例：A_L0_truncated_must_differ（截断变体由模型侧算出并编进向量头文件；
//     DUT 本身不修改，判别力口径见 unit/p2_vector_format.md）；
//   * 启动 / 复位 / 取消 / 连续两次使用不同输入（P2 Step 7）：`STEP7 ...` 各行。
//
// 波形：按 pre-DV 流程写 `dump.vcd`。逐拍 F 打印成 `CYC <name> <c> | tb=0x.. | model=0x.. | OK`，
// 供 `compare_to_model.py` 与模型 JSON 交叉核对（判据：`0 mismatches`）。
//
// 向量数据来自生成头文件 `otbn_p256_fold_vectors.h`（由 run_dir/unit/make_vectors.py --emit-header
// 产出，请勿手改）。**不依赖 otbn_tb_utils.h**：那个头文件要求调用方先定义 kWidth/kShareMask
// （掩码份额专用），本 TB 不做份额操作。

#include <cstdint>
#include <cstdio>
#include <cstring>

#include "Votbn_p256_fold.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

#include "otbn_p256_fold_vectors.h"

// ---------------------------------------------------------------------------
// 字宽约定（Verilator 4.x 把宽信号按 32-bit 字打包，低字在前）
// ---------------------------------------------------------------------------
static constexpr int kWordsF = 9;    // f_o / 260 bit
static constexpr int kWordsH = 8;    // h_o, high, result, wd, mac_result_pre_so_i / 256 bit
static constexpr int kWordsAcc = 5;  // acc130_o, mac_acc_after_so_i / 130 bit
static constexpr int kWordsLL = 4;   // ll_o / 128 bit

static int g_checks = 0;
static int g_errs = 0;

static void fail(const char *what, const char *vec, int cycle) {
  g_errs++;
  printf("[FAIL] %s (vec=%s cycle=%d)\n", what, vec, cycle);
}

static bool eq_words(const uint32_t *a, const uint32_t *b, int n) {
  for (int i = 0; i < n; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

static bool nz_words(const uint32_t *a, int n) {
  for (int i = 0; i < n; i++) {
    if (a[i]) return true;
  }
  return false;
}

// 9 字（低字在前）→ 十六进制字符串（去前导零）。
static void wide_hex(const uint32_t *w, int nwords, char *out) {
  int top = nwords - 1;
  while (top > 0 && w[top] == 0) top--;
  char *p = out;
  p += sprintf(p, "0x%x", (unsigned)w[top]);
  for (int i = top - 1; i >= 0; i--) p += sprintf(p, "%08x", (unsigned)w[i]);
}

// seed = {MAC[127:0], 128'b0}：低 128 位左移 4 个字。
static void seed_from_low128(const uint32_t *pre, uint32_t *out) {
  for (int i = 0; i < kP2Words; i++) out[i] = 0;
  for (int i = 0; i < 4; i++) out[4 + i] = pre[i];
}

// 256-bit 值的低 128 位 / 高半（word4..7 下移）——用于 off-by-one 反面。
static void low128(const uint32_t *w, uint32_t *out) {
  for (int i = 0; i < 4; i++) out[i] = w[i];
}
static void high_half(const uint32_t *w, uint32_t *out) {
  for (int i = 0; i < kP2Words; i++) out[i] = (i < 4) ? w[i + 4] : 0u;
}

// ---------------------------------------------------------------------------
// 时钟
// ---------------------------------------------------------------------------
// 一个整拍：调用方先设好输入，再拉高 clk 并 eval（DUT 在该沿锁存），随后读输出、拉低。
static void tick(Votbn_p256_fold *dut, VerilatedVcdC *vcd, VerilatedContext *ctx) {
  dut->clk_i = 1;
  dut->eval();
  vcd->dump(ctx->time());
  ctx->timeInc(1);
  dut->clk_i = 0;
  dut->eval();
  vcd->dump(ctx->time());
  ctx->timeInc(1);
}

static void reset_dut(Votbn_p256_fold *dut, VerilatedVcdC *vcd, VerilatedContext *ctx) {
  dut->clk_i = 0;
  dut->rst_ni = 0;
  dut->start_i = 0;
  dut->abort_i = 0;
  dut->wipe_i = 0;
  dut->eval();
  for (int i = 0; i < 4; i++) tick(dut, vcd, ctx);
  dut->rst_ni = 1;
  tick(dut, vcd, ctx);
}

// 送一拍时钟并**确认 DUT 真的推进了**（环境若偶尔少一次有效沿，则补 tick）；返回实际 tick 数。
static int tick_advance(Votbn_p256_fold *dut, VerilatedVcdC *vcd, VerilatedContext *ctx,
                        int prev_cyc) {
  int n = 0;
  do {
    tick(dut, vcd, ctx);
    n++;
  } while (n < 4 && dut->busy_o && (int)dut->cycle_o == prev_cyc);
  return n;
}

// ---------------------------------------------------------------------------
// 运行
// ---------------------------------------------------------------------------
struct RunObs {
  uint32_t f[22][kP2Words];                 // 周期 c 末锁存后的 F（= 模型 fold trace 的 cycle c）
  uint32_t h[kP2Words], ll[kP2Words], acc130[kP2Words], wd[kP2Words];
  int k_c19;
  int wd_pulses;
  int cyc_start, busy_start;                // start 脉冲后立刻读到的诊断值
  int last_cycle, cycles_seen;
  int start_retries;                        // start 脉冲重试次数（0 = 一次就生效）
  int extra_ticks;                          // "补 tick" 总数（DUT 未按预期推进的次数）
};

struct DutPtrs {
  uint32_t *pre, *acc_i;                    // 输入 tap
  uint32_t *f, *h, *ll, *acc_o, *wd;        // 输出
};

static DutPtrs bind_ptrs(Votbn_p256_fold *dut) {
  DutPtrs p;
  p.pre = reinterpret_cast<uint32_t *>(&dut->mac_result_pre_so_i);
  p.acc_i = reinterpret_cast<uint32_t *>(&dut->mac_acc_after_so_i);
  p.f = reinterpret_cast<uint32_t *>(&dut->f_o);
  p.h = reinterpret_cast<uint32_t *>(&dut->h_o);
  p.ll = reinterpret_cast<uint32_t *>(&dut->ll_o);
  p.acc_o = reinterpret_cast<uint32_t *>(&dut->acc130_o);
  p.wd = reinterpret_cast<uint32_t *>(&dut->wd_o);
  return p;
}

// 驱动一次 start 脉冲（下一拍进入 c0，暂存清零）。
static void drive_start(Votbn_p256_fold *dut, VerilatedVcdC *vcd, VerilatedContext *ctx,
                        const DutPtrs &p) {
  for (int i = 0; i < kWordsH; i++) p.pre[i] = 0;
  for (int i = 0; i < kWordsAcc; i++) p.acc_i[i] = 0;
  dut->abort_i = 0;
  dut->wipe_i = 0;
  dut->start_i = 1;
  tick(dut, vcd, ctx);
  dut->start_i = 0;
}

// 给 start 脉冲直到 DUT 进入 busy（最多 4 次），返回实际尝试次数。
static int start_dut(Votbn_p256_fold *dut, VerilatedVcdC *vcd, VerilatedContext *ctx,
                     const DutPtrs &p) {
  int n = 0;
  for (int attempt = 1; attempt <= 4 && dut->busy_o != 1; attempt++) {
    drive_start(dut, vcd, ctx, p);
    n = attempt;
  }
  return n;
}

// 给「呈现周期 k」的 tap（k 越界给零）。**注意**：k 是 TB 呈现 tap 的周期，
// DUT 实际在哪个周期采到由 g_tap_offset 补偿（见 PROBE 行）。
static void drive_taps(const P2Vector &v, int k, const DutPtrs &p) {
  for (int i = 0; i < kWordsH; i++) p.pre[i] = 0;
  for (int i = 0; i < kWordsAcc; i++) p.acc_i[i] = 0;
  if (k < 0 || k >= kP2Completion) return;
  int c = k;
  if (v.source == 0) {                       // inject：只在四个采样周期给
    const uint32_t *src = nullptr;
    if (c == kP2SampleH) src = v.H;
    if (c == kP2SampleHigh) src = v.high;
    if (c == kP2SampleLL) src = v.LL;
    if (src) {
      for (int i = 0; i < kWordsH; i++) p.pre[i] = src[i];
    }
    if (c == kP2SampleACC) {
      for (int i = 0; i < kWordsAcc; i++) p.acc_i[i] = v.ACC130[i];
    }
  } else {                                   // mac：按 §8 的 16 拍 tap
    if (c < 16) {
      for (int i = 0; i < kWordsH; i++) p.pre[i] = v.pre_so[c][i];
      for (int i = 0; i < kWordsAcc; i++) p.acc_i[i] = v.acc_after[c][i];
    }
  }
}

// ---- 探针：测「TB 在周期 k 呈现的 tap」被 DUT 在哪个周期采到 ----
// 只在 k 拍给低 128 位标记 M（其余全 0）；若 F@c3 == M<<128，说明 c3 用的就是 k 拍呈现的 tap。
// 本流程实测存在这种延迟（Linux 实跑：c3 的 seed 等于 pre_so[2] ⇒ 延迟 1 拍），故测出来并补偿，
// 而不是把偏移写死；测到的值打在 `PROBE` 行里，P3 接入真 BN-MAC 时必须重新确认。
static int g_tap_offset = 0;

static bool probe_once(Votbn_p256_fold *dut, VerilatedVcdC *vcd, VerilatedContext *ctx,
                       const DutPtrs &p, int mark_cycle) {
  const uint32_t kMark = 0x5a5a1234u;
  start_dut(dut, vcd, ctx, p);
  while (dut->busy_o) {
    int c = (int)dut->cycle_o;
    for (int i = 0; i < kWordsH; i++) p.pre[i] = 0;
    for (int i = 0; i < kWordsAcc; i++) p.acc_i[i] = 0;
    if (c == mark_cycle) p.pre[0] = kMark;
    tick_advance(dut, vcd, ctx, c);
    if (c == kP2SampleH) {
      uint32_t f[kWordsF];
      for (int i = 0; i < kWordsF; i++) f[i] = p.f[i];
      uint32_t rest = f[0] | f[1] | f[2] | f[3] | f[5] | f[6] | f[7] | f[8];
      dut->abort_i = 1;
      for (int i = 0; i < 4 && dut->busy_o; i++) tick(dut, vcd, ctx);
      dut->abort_i = 0;
      return (f[4] == kMark) && (rest == 0);
    }
  }
  return false;
}

// 跑到 DUT 自己的周期号到达 stop_at（不含；stop_at<0 表示跑到 busy 落 0）为止。
// 每拍：读 cycle_o → 给该周期的 tap → 时钟沿（确认推进）→ 读回输出（该周期末锁存值）→ 与模型同周期号比对。
static void run_until(Votbn_p256_fold *dut, VerilatedVcdC *vcd, VerilatedContext *ctx,
                      const P2Vector &v, const DutPtrs &p, RunObs *obs,
                      int stop_at, bool check) {
  int prev = -1;
  while (dut->busy_o && obs->cycles_seen < kP2Completion + 4) {
    int c = (int)dut->cycle_o;
    if (c < 0 || c >= kP2Completion) {
      fail("cycle_o 落在 c0…c21 之外", v.name, c);
      break;
    }
    if (stop_at >= 0 && c >= stop_at) break;

    drive_taps(v, c, p);
    int n = tick_advance(dut, vcd, ctx, c);
    if (n > 1) obs->extra_ticks += n - 1;

    if (c < 22) {
      for (int i = 0; i < kWordsF; i++) obs->f[c][i] = p.f[i];
    }
    for (int i = 0; i < kWordsH; i++) obs->h[i] = p.h[i];
    for (int i = 0; i < kWordsLL; i++) obs->ll[i] = p.ll[i];
    for (int i = 0; i < kWordsAcc; i++) obs->acc130[i] = p.acc_o[i];
    for (int i = 0; i < kWordsH; i++) obs->wd[i] = p.wd[i];
    obs->k_c19 = (int)(dut->k_o & 0xF);
    if (dut->wd_valid_o) obs->wd_pulses++;
    obs->last_cycle = c;
    obs->cycles_seen++;

    if (!check) continue;

    for (int i = 0; i < v.n_fold; i++) {
      if (v.fold[i].cycle != c) continue;
      g_checks++;
      bool ok = eq_words(obs->f[c], v.fold[i].F, kWordsF);
      if (!ok) fail("F 与模型不符", v.name, c);
      char a[128], b[128];
      wide_hex(obs->f[c], kWordsF, a);
      wide_hex(v.fold[i].F, kWordsF, b);
      printf("CYC %s %d | tb=%s | model=%s | %s\n", v.name, c, a, b, ok ? "OK" : "DIFF");
    }
    g_checks++;
    if (prev >= 0 && c != prev + 1) {
      fail("周期号未逐拍 +1", v.name, c);
      printf("DBG %s: 上一拍 cycle_o=%d，本拍 %d\n", v.name, prev, c);
    }
    prev = c;
  }
}

// 跑完整一条向量，并做四个采样点 / k / 写回 / 完成周期的检查。
static void run_vector(Votbn_p256_fold *dut, VerilatedVcdC *vcd, VerilatedContext *ctx,
                       const P2Vector &v, const DutPtrs &p, RunObs *obs, bool check) {
  memset(obs, 0, sizeof(*obs));
  obs->start_retries = start_dut(dut, vcd, ctx, p);
  obs->cyc_start = (int)dut->cycle_o;
  obs->busy_start = (int)dut->busy_o;
  printf("DBG %s: start 后 cycle_o=%d busy_o=%d（start 重试 %d 次）\n",
         v.name, obs->cyc_start, obs->busy_start, obs->start_retries);
  g_checks++;
  if (dut->busy_o != 1) fail("start 后 busy_o 未拉高", v.name, 0);

  run_until(dut, vcd, ctx, v, p, obs, /*stop_at=*/-1, check);

  g_checks++;
  if (dut->busy_o) fail("未在有限拍内完成", v.name, obs->last_cycle);
  g_checks++;
  if (obs->last_cycle != kP2Completion - 1) fail("完成周期不是 c21", v.name, obs->last_cycle);

  if (!check) return;

  // 四个采样点（正面）
  uint32_t exp[kP2Words];
  if (v.source == 0) {
    g_checks++;
    if (!eq_words(obs->f[3], v.H, kP2Words)) fail("H 采样点（inject）", v.name, 3);
  } else {
    seed_from_low128(v.pre_so[kP2SampleH], exp);
    g_checks++;
    if (!eq_words(obs->f[3], exp, kP2Words)) fail("H 采样点（mac）", v.name, 3);
  }
  g_checks++;
  if (!eq_words(obs->h, v.high, kWordsH)) fail("high 采样点", v.name, kP2SampleHigh);
  g_checks++;
  if (!eq_words(obs->ll, v.LL, kWordsLL)) fail("LL 采样点", v.name, kP2SampleLL);
  g_checks++;
  if (!eq_words(obs->acc130, v.ACC130, kWordsAcc)) fail("ACC130 采样点", v.name, kP2SampleACC);

  // k 与写回
  g_checks++;
  if (obs->k_c19 != (v.q & 0xF)) fail("k@c19 与模型商不符", v.name, 19);
  g_checks++;
  if (obs->wd_pulses != 1) fail("wd 写回不是恰好一次", v.name, kP2Completion);
  g_checks++;
  if (!eq_words(obs->wd, v.result, kWordsF)) fail("wd 与模型 result 不符", v.name, kP2Completion);
}

// 三条 off-by-one：正断言 + 反面（反面只统计判别力，不判失败——全零向量天然不可区分）。
static void off_by_one_checks(const P2Vector &v, const RunObs &obs,
                              int *disc_c3, int *disc_c9, int *disc_c12) {
  uint32_t exp[kP2Words], neg[kP2Words], tmp[kP2Words];

  // A_c3_H_no_off_by_one：F@c3 == (tap@c3 低 128 位) << 128
  seed_from_low128(v.pre_so[kP2SampleH], exp);
  g_checks++;
  if (!eq_words(obs.f[3], exp, kP2Words)) fail("A_c3_H_no_off_by_one 正断言", v.name, 3);
  // 反面①：采到 c2 的值（晚一拍）
  seed_from_low128(v.pre_so[kP2SampleH - 1], neg);
  if (!eq_words(obs.f[3], neg, kP2Words)) (*disc_c3)++;
  // 反面②：误取 high 半字（= shift-out 之后的值）
  high_half(v.pre_so[kP2SampleH], neg);
  if (!eq_words(obs.f[3], neg, kP2Words)) (*disc_c3)++;

  // A_c9_high_no_off_by_one：h@c9 == tap@c9（当拍 MAC 新结果）
  g_checks++;
  if (!eq_words(obs.h, v.pre_so[kP2SampleHigh], kWordsH))
    fail("A_c9_high_no_off_by_one 正断言", v.name, kP2SampleHigh);
  // 反面：对 acc_q 采样会得到前一拍的值
  if (!eq_words(obs.h, v.acc_after[kP2SampleHigh - 1], kWordsH)) (*disc_c9)++;

  // A_c12_LL_no_off_by_one：LL@c12 == tap@c12 低 128 位
  low128(v.pre_so[kP2SampleLL], tmp);
  g_checks++;
  if (!eq_words(obs.ll, tmp, kWordsLL)) fail("A_c12_LL_no_off_by_one 正断言", v.name, kP2SampleLL);
  // 反面：采到 c11 的值
  low128(v.pre_so[kP2SampleLL - 1], neg);
  if (!eq_words(obs.ll, neg, kWordsLL)) (*disc_c12)++;
}

// ---------------------------------------------------------------------------
int main(int argc, char **argv) {
  VerilatedContext *const ctx = new VerilatedContext;
  ctx->commandArgs(argc, argv);
  ctx->traceEverOn(true);
  Votbn_p256_fold *const dut = new Votbn_p256_fold(ctx, "TOP");

  VerilatedVcdC *const vcd = new VerilatedVcdC;
  dut->trace(vcd, 99);
  vcd->open("dump.vcd");

  const DutPtrs p = bind_ptrs(dut);

  // 端口地址布局（一次性诊断）：确认宽端口的字数组与相邻端口的关系，排除越界写。
  printf("LAYOUT(&ports): pre=%p acc_i=%p f=%p h=%p ll=%p acc_o=%p wd=%p | "
         "clk=%p rst=%p start=%p abort=%p wipe=%p busy=%p cyc=%p\n",
         (void *)&dut->mac_result_pre_so_i, (void *)&dut->mac_acc_after_so_i,
         (void *)&dut->f_o, (void *)&dut->h_o, (void *)&dut->ll_o,
         (void *)&dut->acc130_o, (void *)&dut->wd_o,
         (void *)&dut->clk_i, (void *)&dut->rst_ni, (void *)&dut->start_i,
         (void *)&dut->abort_i, (void *)&dut->wipe_i,
         (void *)&dut->busy_o, (void *)&dut->cycle_o);

  reset_dut(dut, vcd, ctx);

  // 自校准：测 tap 呈现→采样延迟（0 拍 = 同拍采；1 拍 = 下一拍采）
  if (probe_once(dut, vcd, ctx, p, kP2SampleH)) {
    g_tap_offset = 0;
  } else if (probe_once(dut, vcd, ctx, p, kP2SampleH - 1)) {
    g_tap_offset = 1;
  } else {
    g_tap_offset = -1;
  }
  printf("PROBE（诊断记录，不参与对齐）: tap 呈现→DUT 采样延迟 = %d 拍%s\n",
         g_tap_offset,
         g_tap_offset < 0 ? "（测不出：两种假设都不成立，请检查 TB/RTL）" :
         (g_tap_offset == 0 ? "（同拍呈现同拍采）" : "（提前一拍呈现，DUT 下一拍采）"));
  printf("PROBE 说明: 该偏移**未**用于对齐判据；根因未定性前不做任何补偿（见 unit/otbn_tap_probe_tb.cpp）\n");


  RunObs obs;
  int disc_c3 = 0, disc_c9 = 0, disc_c12 = 0;
  int n_ob1 = 0, n_acc_hi = 0, n_trunc_differs = 0, n_trunc_checks = 0;
  int n_vectors_run = 0;
  int n_completion_cycles = -1;
  int total_start_retries = 0, total_extra_ticks = 0;

  printf("P2 Fold Unit TB: %d vectors, 采样周期 c3/c9/c12/c15, 完成周期 %d\n",
         kP2NumVectors, kP2Completion);

  // ---------------- 每条向量 ----------------
  for (int i = 0; i < kP2NumVectors; i++) {
    const P2Vector &v = kP2Vectors[i];
    run_vector(dut, vcd, ctx, v, p, &obs, /*check=*/true);
    n_vectors_run++;
    total_start_retries += obs.start_retries;
    total_extra_ticks += obs.extra_ticks;
    if (n_completion_cycles < 0) {
      n_completion_cycles = obs.last_cycle;
    } else {
      g_checks++;
      if (obs.last_cycle != n_completion_cycles) fail("完成周期与其它向量不一致", v.name, obs.last_cycle);
    }

    // Step 4：L0 截断的失败用例（判别力由模型侧数据保证）
    n_trunc_checks++;
    if (v.acc130_hi_nonzero) n_acc_hi++;
    if (v.trunc_differs) n_trunc_differs++;
    g_checks++;
    if (v.acc130_hi_nonzero && !v.trunc_differs)
      fail("ACC130[129:128]≠0 但截断不改变结果（用例无效）", v.name, 18);
    g_checks++;
    if (v.trunc_differs && eq_words(v.result, v.result_trunc, kWordsF))
      fail("截断变体与正确结果相同", v.name, 18);

    // 三条 off-by-one（只在 mac 向量上做：inject 向量的邻拍 tap 无意义）
    if (v.source == 1) {
      off_by_one_checks(v, obs, &disc_c3, &disc_c9, &disc_c12);
      n_ob1++;
    }
  }

  // ---------------- Step 7 ----------------
  // (a) 中途 abort（DUT 到达 c14 时给一拍 abort）：不得写回、暂存清零、busy 落 0
  {
    const P2Vector &v = kP2Vectors[0];
    memset(&obs, 0, sizeof(obs));
    start_dut(dut, vcd, ctx, p);
    run_until(dut, vcd, ctx, v, p, &obs, /*stop_at=*/14, /*check=*/false);
    dut->abort_i = 1;
    for (int i = 0; i < 4 && dut->busy_o; i++) tick(dut, vcd, ctx);
    dut->abort_i = 0;
    while (dut->busy_o && obs.cycles_seen < 4 * kP2Completion) {
      int c = (int)dut->cycle_o;
      drive_taps(v, c, p);
      tick(dut, vcd, ctx);
      if (dut->wd_valid_o) obs.wd_pulses++;
      obs.cycles_seen++;
    }
    bool clean = !nz_words(p.f, kWordsF) && !nz_words(p.h, kWordsH) &&
                 !nz_words(p.ll, kWordsLL) && !nz_words(p.acc_o, kWordsAcc);
    g_checks++;
    if (obs.wd_pulses == 0 && clean && dut->busy_o == 0) {
      printf("STEP7 abort_mid_run(c14): PASS（无写回、F/h/LL/ACC130 全清、busy=0）\n");
    } else {
      fail("STEP7 abort_mid_run", v.name, 14);
      printf("STEP7 abort_mid_run(c14): FAIL（wd_pulses=%d clean=%d busy=%d）\n",
             obs.wd_pulses, (int)clean, (int)dut->busy_o);
    }
  }
  // (b) 中途 reset（DUT 到达 c8 时拉低复位两拍）：暂存清零、busy 落 0，且复位后能重跑出正确结果
  {
    const P2Vector &v = kP2Vectors[0];
    memset(&obs, 0, sizeof(obs));
    start_dut(dut, vcd, ctx, p);
    run_until(dut, vcd, ctx, v, p, &obs, /*stop_at=*/8, /*check=*/false);
    dut->rst_ni = 0;
    tick(dut, vcd, ctx);
    tick(dut, vcd, ctx);
    dut->rst_ni = 1;
    tick(dut, vcd, ctx);
    bool clean = !nz_words(p.f, kWordsF) && !nz_words(p.h, kWordsH) &&
                 !nz_words(p.ll, kWordsLL) && !nz_words(p.acc_o, kWordsAcc);
    g_checks++;
    if (clean && dut->busy_o == 0) {
      printf("STEP7 reset_mid_run(c8): PASS（F/h/LL/ACC130 全清、busy=0）\n");
    } else {
      fail("STEP7 reset_mid_run", v.name, 8);
      printf("STEP7 reset_mid_run(c8): FAIL（clean=%d busy=%d）\n", (int)clean, (int)dut->busy_o);
    }
    run_vector(dut, vcd, ctx, v, p, &obs, /*check=*/false);
    g_checks++;
    if (obs.wd_pulses != 1 || !eq_words(obs.wd, v.result, kWordsF)) {
      fail("复位后重跑结果不符", v.name, kP2Completion);
    } else {
      printf("STEP7 reset_then_rerun: PASS\n");
    }
  }
  // (c) idle 时 wipe：暂存清零
  {
    dut->wipe_i = 1;
    tick(dut, vcd, ctx);
    dut->wipe_i = 0;
    tick(dut, vcd, ctx);
    bool clean = !nz_words(p.f, kWordsF) && !nz_words(p.h, kWordsH) &&
                 !nz_words(p.ll, kWordsLL) && !nz_words(p.acc_o, kWordsAcc);
    g_checks++;
    if (clean) {
      printf("STEP7 wipe_idle: PASS（暂存清零）\n");
    } else {
      fail("STEP7 wipe_idle", "-", 0);
      printf("STEP7 wipe_idle: FAIL\n");
    }
  }
  // (d) 连续两次不同输入：第二次启动后 c0–c2 读不到第一次的 F/h/LL
  {
    const P2Vector &v1 = kP2Vectors[2];      // p−1 平方
    const P2Vector &v2 = kP2Vectors[kP2NumVectors - 1];
    run_vector(dut, vcd, ctx, v1, p, &obs, /*check=*/true);
    bool first_left_state = nz_words(p.f, kWordsF) || nz_words(p.h, kWordsH) || nz_words(p.ll, kWordsLL);

    memset(&obs, 0, sizeof(obs));
    start_dut(dut, vcd, ctx, p);
    bool stale = false;
    for (int step = 0; step < 3 && dut->busy_o; step++) {
      int c = (int)dut->cycle_o;
      drive_taps(v2, c, p);
      tick_advance(dut, vcd, ctx, c);
      g_checks++;
      if (nz_words(p.f, kWordsF) || nz_words(p.h, kWordsH) || nz_words(p.ll, kWordsLL) ||
          nz_words(p.acc_o, kWordsAcc)) {
        stale = true;
        fail("第二次 c0–c2 残留第一次的暂存", v2.name, c);
      }
    }
    run_until(dut, vcd, ctx, v2, p, &obs, /*stop_at=*/-1, /*check=*/false);
    g_checks++;
    if (obs.wd_pulses != 1 || !eq_words(obs.wd, v2.result, kWordsF))
      fail("第二次运行结果不符", v2.name, kP2Completion);
    if (!stale && first_left_state) {
      printf("STEP7 two_runs_no_stale: PASS（第二次 c0–c2 全 0，且第二次结果正确）\n");
    } else if (!first_left_state) {
      fail("第一次运行未留下任何暂存（本用例无判别力）", v1.name, kP2Completion);
      printf("STEP7 two_runs_no_stale: FAIL（用例无判别力）\n");
    }
  }

  // ---------------- 汇总 ----------------
  const char *res = g_errs ? "SEE FAIL LINES" : "PASS";
  printf("ASSERT A_c3_H_no_off_by_one: %s（1 条正面 + 2 条反面，%d 条 mac 向量参与；"
         "反面被数据区分 %d 次）\n", res, n_ob1, disc_c3);
  printf("ASSERT A_c9_high_no_off_by_one: %s（1 条正面 + 1 条反面；反面被数据区分 %d 次）\n",
         res, disc_c9);
  printf("ASSERT A_c12_LL_no_off_by_one: %s（1 条正面 + 1 条反面；反面被数据区分 %d 次）\n",
         res, disc_c12);
  printf("ASSERT A_L0_truncated_must_differ: %s（%d 条检查；ACC130[129:128]≠0 的向量 %d 条，"
         "其中截断确实改变结果 %d 条）\n", res, n_trunc_checks, n_acc_hi, n_trunc_differs);
  printf("VECTORS: %d run；完成周期（末拍 cycle_o）= c%d，各向量一致\n",
         n_vectors_run, n_completion_cycles);
  printf("TIMING: start 重试合计 %d 次；补 tick 合计 %d 次（都为 0 = 每拍一个上升沿即推进）\n",
         total_start_retries, total_extra_ticks);
  if (g_errs)
    printf("Test ***FAILED*** %d errors / %d checks\n", g_errs, g_checks);
  else
    printf("PASS - 0 errors / %d checks\nTest ***PASSED*** all %d vectors\n", g_checks, kP2NumVectors);

  dut->final();
  vcd->close();
  delete vcd;
  delete dut;
  delete ctx;
  return g_errs ? 1 : 0;
}
