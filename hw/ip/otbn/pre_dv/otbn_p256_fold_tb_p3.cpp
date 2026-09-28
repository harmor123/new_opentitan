// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// P3 单元 testbench：`otbn_p256_fold` 的 **overlap / serial 双调度**（contribution 2.pdf §11 P3）。
//
// 为什么单独一个 TB：P2 的 `otbn_p256_fold_tb.cpp`（+ 它的 `p2_inject.log`）是 P2 的冻结证据，
// 必须保持可复现 ⇒ 那里只加了一行把 `mode_serial_i` 固定为 0；本 TB 负责 serial 调度与
// "两种模式采样点必须相同" 这两件 P3 新增的事。
//
// 判据（每条都在下面单独打点）：
//   ① overlap 模式的逐拍 F == 向量自带的 `fold_F`（= P2 已验证的轨迹）⇒ P2 调度未退化；
//   ② serial 模式的逐拍 F == 重映射期望：
//        c ≤ 9  : fold[c]（c=3 的 seed）
//        10…15  : fold[3]（row 全部推迟 ⇒ F 保持 seed）
//        16…27  : fold[c − 6]（原 c10…c21 的 8 个 row + merge + fold + corr + WB）
//   ③ 四个采样点 h@c9 / LL@c12 / ACC130@c15 与 k、result 在**两种模式下完全相同**
//      （PDF §11 P3：保持 c0…c15 的 MAC 顺序、c3 seed F、c9 capture high）；
//   ④ 完成周期固定：overlap c21（22 拍）、serial c27（28 拍），逐向量一致；
//   ⑤ serial 下 abort/复位/wipe/连续两次调用（P3 的额外拍数不得是"神秘 stall"）。
//
// 驱动口径与 P2 TB 相同：tap 按 **DUT 自己的 `cycle_o`** 喂；每拍先在低电平 eval 再抬沿
// （见 P2 TB 的 tick() 注释与 unit/otbn_tap_probe 结构分叉实验——那是流程纪律，不是 RTL 语义）。
// 向量数据来自 `otbn_p256_fold_vectors.h`（P2 生成物，不改）。**不依赖 otbn_tb_utils.h**。

#include <cstdint>
#include <cstdio>
#include <cstring>

#include "Votbn_p256_fold.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

#include "otbn_p256_fold_vectors.h"

static constexpr int kWordsF = 9;    // f_o / 260 bit
static constexpr int kWordsH = 8;    // h_o, high, result, wd, mac_result_pre_so_i / 256 bit
static constexpr int kWordsAcc = 5;  // acc130_o, mac_acc_after_so_i / 130 bit
static constexpr int kWordsLL = 4;   // ll_o / 128 bit
static constexpr int kMaxCyc = 28;   // serial 总拍数（overlap 为 22）
static constexpr int kOverlapCompletion = 22;
static constexpr int kSerialCompletion = 28;
static constexpr int kSerialShift = 6;  // 尾部整体后移量

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

// F 是 260-bit signed：向量头按 9 字存（负值符号扩展到 word8）⇒ 只比低 260 位。
static bool eq_f260(const uint32_t *a, const uint32_t *b) {
  for (int i = 0; i < 8; i++) {
    if (a[i] != b[i]) return false;
  }
  return (a[8] & 0xFu) == (b[8] & 0xFu);
}

static bool nz_words(const uint32_t *a, int n) {
  for (int i = 0; i < n; i++) {
    if (a[i]) return true;
  }
  return false;
}

static void wide_hex(const uint32_t *w, int nwords, char *out) {
  uint32_t tmp[kP2Words];
  for (int i = 0; i < kP2Words; i++) tmp[i] = w[i];
  if (kP2Words == 9) tmp[8] &= 0xFu;
  int top = nwords - 1;
  while (top > 0 && tmp[top] == 0) top--;
  char *p = out;
  p += sprintf(p, "0x%x", (unsigned)tmp[top]);
  for (int i = top - 1; i >= 0; i--) p += sprintf(p, "%08x", (unsigned)tmp[i]);
}

// ---------------------------------------------------------------------------
// 时钟（顺序关键：先低电平 eval 传播输入，再抬沿提交）
// ---------------------------------------------------------------------------
static void tick(Votbn_p256_fold *dut, VerilatedVcdC *vcd, VerilatedContext *ctx) {
  dut->clk_i = 0;
  dut->eval();
  vcd->dump(ctx->time());
  ctx->timeInc(1);
  dut->clk_i = 1;
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
  dut->mode_serial_i = 0;
  dut->eval();
  for (int i = 0; i < 4; i++) tick(dut, vcd, ctx);
  dut->rst_ni = 1;
  tick(dut, vcd, ctx);
}

static int tick_advance(Votbn_p256_fold *dut, VerilatedVcdC *vcd, VerilatedContext *ctx,
                        int prev_cyc) {
  int n = 0;
  do {
    tick(dut, vcd, ctx);
    n++;
  } while (n < 4 && dut->busy_o && (int)dut->cycle_o == prev_cyc);
  return n;
}

struct RunObs {
  uint32_t f[kMaxCyc][kP2Words];
  uint32_t h[kP2Words], ll[kP2Words], acc130[kP2Words], wd[kP2Words];
  int k_cap;
  int wd_pulses;
  int last_cycle, cycles_seen;
  int start_retries, extra_ticks, max_cycle_seen;
};

struct DutPtrs {
  uint32_t *pre, *acc_i, *f, *h, *ll, *acc_o, *wd;
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

static void drive_start(Votbn_p256_fold *dut, VerilatedVcdC *vcd, VerilatedContext *ctx,
                        const DutPtrs &p, bool serial) {
  for (int i = 0; i < kWordsH; i++) p.pre[i] = 0;
  for (int i = 0; i < kWordsAcc; i++) p.acc_i[i] = 0;
  dut->abort_i = 0;
  dut->wipe_i = 0;
  dut->mode_serial_i = serial ? 1 : 0;   // 在 start 那一拍被锁存
  dut->start_i = 1;
  tick(dut, vcd, ctx);
  dut->start_i = 0;
}

static int start_dut(Votbn_p256_fold *dut, VerilatedVcdC *vcd, VerilatedContext *ctx,
                     const DutPtrs &p, bool serial) {
  int n = 0;
  for (int attempt = 1; attempt <= 4 && dut->busy_o != 1; attempt++) {
    drive_start(dut, vcd, ctx, p, serial);
    n = attempt;
  }
  return n;
}

// MAC 侧 tap 只在 c0…c15 有意义（与调度模式无关：P3 只在 Fold 侧推迟 row 累加）。
static void drive_taps(const P2Vector &v, int c, const DutPtrs &p) {
  for (int i = 0; i < kWordsH; i++) p.pre[i] = 0;
  for (int i = 0; i < kWordsAcc; i++) p.acc_i[i] = 0;
  if (c < 0 || c >= 16) return;
  if (v.source == 0) {                        // inject：四个采样周期
    if (c == kP2SampleH) {
      for (int i = 0; i < 4; i++) p.pre[i] = v.H[4 + i];   // DUT 取 tap[127:0] 再左移 128
    } else if (c == kP2SampleHigh) {
      for (int i = 0; i < kWordsH; i++) p.pre[i] = v.high[i];
    } else if (c == kP2SampleLL) {
      for (int i = 0; i < kWordsLL; i++) p.pre[i] = v.LL[i];
    }
    if (c == kP2SampleACC) {
      for (int i = 0; i < kWordsAcc; i++) p.acc_i[i] = v.ACC130[i];
    }
  } else {                                    // mac：§8 的 16 拍 tap
    for (int i = 0; i < kWordsH; i++) p.pre[i] = v.pre_so[c][i];
    for (int i = 0; i < kWordsAcc; i++) p.acc_i[i] = v.acc_after[c][i];
  }
}

// 按向量自带的周期号取某拍的模型值（找不到返回 nullptr）——不按下标硬算，避免映射写错。
static const uint32_t *fold_at(const P2Vector &v, int cycle) {
  for (int i = 0; i < v.n_fold; i++) {
    if (v.fold[i].cycle == cycle) return v.fold[i].F;
  }
  return nullptr;
}

// 期望 F 表：overlap 用向量自带轨迹；serial 用 +6 拍重映射。
static void build_expect(const P2Vector &v, bool serial,
                         uint32_t exp[kMaxCyc][kP2Words], bool has[kMaxCyc]) {
  for (int c = 0; c < kMaxCyc; c++) {
    has[c] = false;
    for (int j = 0; j < kP2Words; j++) exp[c][j] = 0;
  }
  const uint32_t *seed = fold_at(v, 3);      // c3 的 seed
  for (int c = 0; c < kMaxCyc; c++) {
    const uint32_t *src = nullptr;
    if (!serial) {
      src = fold_at(v, c);
    } else if (c == 3) {
      src = seed;
    } else if (c > 3 && c <= kP2SampleACC) {
      src = seed;                            // c4…c15：row 全部推迟 ⇒ F 保持 seed
    } else if (c > kP2SampleACC) {
      src = fold_at(v, c - kSerialShift);    // c16…c27 ← 原 c10…c21
    }
    if (src == nullptr) continue;
    has[c] = true;
    for (int j = 0; j < kP2Words; j++) exp[c][j] = src[j];
  }
}

static void run_until(Votbn_p256_fold *dut, VerilatedVcdC *vcd, VerilatedContext *ctx,
                      const P2Vector &v, const DutPtrs &p, RunObs *obs,
                      int stop_at, int n_completion) {
  while (dut->busy_o && obs->cycles_seen < n_completion + 4) {
    int c = (int)dut->cycle_o;
    if (c < 0 || c >= n_completion) {
      fail("cycle_o 超出本模式的拍号范围", v.name, c);
      break;
    }
    if (stop_at >= 0 && c >= stop_at) break;

    drive_taps(v, c, p);
    int n = tick_advance(dut, vcd, ctx, c);
    if (n > 1) obs->extra_ticks += n - 1;

    for (int i = 0; i < kWordsF; i++) obs->f[c][i] = p.f[i];
    for (int i = 0; i < kWordsH; i++) obs->h[i] = p.h[i];
    for (int i = 0; i < kWordsLL; i++) obs->ll[i] = p.ll[i];
    for (int i = 0; i < kWordsAcc; i++) obs->acc130[i] = p.acc_o[i];
    for (int i = 0; i < kWordsH; i++) obs->wd[i] = p.wd[i];
    obs->k_cap = (int)(dut->k_o & 0xF);
    if (dut->wd_valid_o) obs->wd_pulses++;
    obs->last_cycle = c;
    if (c > obs->max_cycle_seen) obs->max_cycle_seen = c;
    obs->cycles_seen++;
  }
}

static void run_vector(Votbn_p256_fold *dut, VerilatedVcdC *vcd, VerilatedContext *ctx,
                       const P2Vector &v, const DutPtrs &p, RunObs *obs, bool serial) {
  const int n_completion = serial ? kSerialCompletion : kOverlapCompletion;
  const char *mode = serial ? "serial" : "overlap";
  char tag[128];
  snprintf(tag, sizeof(tag), "%s#%s", v.name, mode);

  memset(obs, 0, sizeof(*obs));
  obs->start_retries = start_dut(dut, vcd, ctx, p, serial);
  g_checks++;
  if (dut->busy_o != 1) fail("start 后 busy_o 未拉高", tag, 0);

  run_until(dut, vcd, ctx, v, p, obs, /*stop_at=*/-1, n_completion);

  g_checks++;
  if (dut->busy_o) fail("未在有限拍内完成", tag, obs->last_cycle);
  g_checks++;
  if (obs->last_cycle != n_completion - 1) {
    fail(serial ? "完成周期不是 c27（28 拍）" : "完成周期不是 c21（22 拍）",
         tag, obs->last_cycle);
  }

  // 期望 F 表（overlap = 向量轨迹；serial = +6 拍重映射）
  uint32_t exp[kMaxCyc][kP2Words];
  bool has[kMaxCyc];
  build_expect(v, serial, exp, has);
  for (int c = 0; c < n_completion; c++) {
    if (!has[c]) continue;
    g_checks++;
    bool ok = eq_f260(obs->f[c], exp[c]);
    if (!ok) fail("F 与期望不符", tag, c);
    char a[128], b[128];
    wide_hex(obs->f[c], kWordsF, a);
    wide_hex(exp[c], kWordsF, b);
    printf("CYC %s %d | tb=%s | model=%s | %s\n", tag, c, a, b, ok ? "OK" : "DIFF");
  }

  // 四个采样点 + k + 写回（拍号随模式，但值必须相同）
  g_checks++;
  if (serial) {
    // serial：row 未开始前 F 必须一直是 seed（判据②的正面）
    const uint32_t *seed = fold_at(v, 3);
    if (seed != nullptr) {
      for (int c = kP2SampleH; c <= kP2SampleACC; c++) {
        g_checks++;
        if (!eq_f260(obs->f[c], seed)) fail("serial 的 c3…c15 未保持 seed", tag, c);
      }
    }
  }
  if (v.source == 0) {
    g_checks++;
    if (!eq_words(obs->f[3], v.H, kP2Words)) fail("H 采样点（inject）", tag, 3);
  }
  g_checks++;
  if (!eq_words(obs->h, v.high, kWordsH)) fail("high 采样点", tag, kP2SampleHigh);
  g_checks++;
  if (!eq_words(obs->ll, v.LL, kWordsLL)) fail("LL 采样点", tag, kP2SampleLL);
  g_checks++;
  if (!eq_words(obs->acc130, v.ACC130, kWordsAcc)) fail("ACC130 采样点", tag, kP2SampleACC);
  g_checks++;
  if (obs->k_cap != (v.q & 0xF)) fail("k 与模型商不符", tag, serial ? 25 : 19);
  g_checks++;
  if (obs->wd_pulses != 1) fail("wd 写回不是恰好一次", tag, n_completion);
  g_checks++;
  if (!eq_f260(obs->wd, v.result)) fail("wd 与模型 result 不符", tag, n_completion);
}

// ---------------------------------------------------------------------------
int main(int argc, char **argv) {
  VerilatedContext *const ctx = new VerilatedContext;
  ctx->commandArgs(argc, argv);
  ctx->traceEverOn(true);
  Votbn_p256_fold *const dut = new Votbn_p256_fold(ctx, "TOP");

  VerilatedVcdC *const vcd = new VerilatedVcdC;
  dut->trace(vcd, 99);
  vcd->open("dump_p3.vcd");

  const DutPtrs p = bind_ptrs(dut);

  printf("LAYOUT(&ports): pre=%p acc_i=%p f=%p h=%p ll=%p acc_o=%p wd=%p | "
         "mode=%p cyc=%p\n",
         (void *)&dut->mac_result_pre_so_i, (void *)&dut->mac_acc_after_so_i,
         (void *)&dut->f_o, (void *)&dut->h_o, (void *)&dut->ll_o,
         (void *)&dut->acc130_o, (void *)&dut->wd_o,
         (void *)&dut->mode_serial_i, (void *)&dut->cycle_o);

  reset_dut(dut, vcd, ctx);

  printf("P3 Fold Unit TB（双调度）: %d vectors × 2 模式；overlap 完成 c21(22 拍)，"
         "serial 完成 c27(28 拍)\n", kP2NumVectors);

  RunObs obs;
  int n_overlap_done = 0, n_serial_done = 0;
  int comp_overlap = -1, comp_serial = -1;
  int total_start_retries = 0, total_extra_ticks = 0;
  int n_same_samples = 0;

  for (int i = 0; i < kP2NumVectors; i++) {
    const P2Vector &v = kP2Vectors[i];

    // 向量头自检（重映射前提）：轨迹必须覆盖 c3 与 c10…c21 全部 13 个周期
    g_checks++;
    if (v.n_fold != 13) fail("向量 fold 轨迹不是 13 项", v.name, v.n_fold);
    for (int c = 3; c <= 21; c++) {
      if (c > 3 && c < 10) continue;
      g_checks++;
      if (fold_at(v, c) == nullptr) fail("向量 fold 轨迹缺周期", v.name, c);
    }

    RunObs o_ov, o_se;
    run_vector(dut, vcd, ctx, v, p, &o_ov, /*serial=*/false);
    run_vector(dut, vcd, ctx, v, p, &o_se, /*serial=*/true);
    total_start_retries += o_ov.start_retries + o_se.start_retries;
    total_extra_ticks += o_ov.extra_ticks + o_se.extra_ticks;

    n_overlap_done++;
    n_serial_done++;
    if (comp_overlap < 0) comp_overlap = o_ov.last_cycle;
    if (comp_serial < 0) comp_serial = o_se.last_cycle;
    g_checks++;
    if (o_ov.last_cycle != comp_overlap) fail("overlap 完成周期与其它向量不一致", v.name,
                                              o_ov.last_cycle);
    g_checks++;
    if (o_se.last_cycle != comp_serial) fail("serial 完成周期与其它向量不一致", v.name,
                                             o_se.last_cycle);

    // ③ 两种模式的采样结果必须完全相同（PDF §11 P3 的核心要求）
    g_checks++;
    bool same = eq_words(o_ov.h, o_se.h, kWordsH) &&
                eq_words(o_ov.ll, o_se.ll, kWordsLL) &&
                eq_words(o_ov.acc130, o_se.acc130, kWordsAcc) &&
                (o_ov.k_cap == o_se.k_cap) && eq_f260(o_ov.wd, o_se.wd);
    if (!same) fail("两种模式的采样点/wd 不一致", v.name, 0);
    if (same) n_same_samples++;
    g_checks++;
    if (!eq_f260(o_ov.f[3], o_se.f[3])) fail("两模式 seed 不同", v.name, 3);
  }

  printf("VECTORS: %d 向量 × 2 模式（overlap %d 次 / serial %d 次）；"
         "完成周期 overlap=c%d / serial=c%d（各向量一致）\n",
         kP2NumVectors, n_overlap_done, n_serial_done, comp_overlap, comp_serial);
  printf("SAMPLES: 两模式采样点（h/LL/ACC130/k/wd）相同 %d/%d\n", n_same_samples, kP2NumVectors);
  printf("TIMING: start 重试合计 %d 次；补 tick 合计 %d 次\n",
         total_start_retries, total_extra_ticks);

  // ---------------- serial 下的 abort / reset / wipe / 连续两次 ----------------
  // (a) serial 到 c20（相位 14 = 与 P2 的 c14 同一个 row 相位）abort：无写回、暂存清零、busy=0
  {
    const P2Vector &v = kP2Vectors[0];
    memset(&obs, 0, sizeof(obs));
    start_dut(dut, vcd, ctx, p, /*serial=*/true);
    run_until(dut, vcd, ctx, v, p, &obs, /*stop_at=*/20, kSerialCompletion);
    dut->abort_i = 1;
    for (int i = 0; i < 4 && dut->busy_o; i++) tick(dut, vcd, ctx);
    dut->abort_i = 0;
    while (dut->busy_o && obs.cycles_seen < 4 * kSerialCompletion) {
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
      printf("STEP7 abort_mid_run_serial(c20): PASS（无写回、F/h/LL/ACC130 全清、busy=0）\n");
    } else {
      fail("STEP7 abort_mid_run_serial", v.name, 20);
      printf("STEP7 abort_mid_run_serial(c20): FAIL（wd_pulses=%d clean=%d busy=%d）\n",
             obs.wd_pulses, (int)clean, (int)dut->busy_o);
    }
  }
  // (b) serial 到 c10（row 尚未开始）复位两拍：暂存清零、busy=0，且复位后能以 serial 重跑出正确结果
  {
    const P2Vector &v = kP2Vectors[0];
    memset(&obs, 0, sizeof(obs));
    start_dut(dut, vcd, ctx, p, /*serial=*/true);
    run_until(dut, vcd, ctx, v, p, &obs, /*stop_at=*/10, kSerialCompletion);
    dut->rst_ni = 0;
    tick(dut, vcd, ctx);
    tick(dut, vcd, ctx);
    dut->rst_ni = 1;
    tick(dut, vcd, ctx);
    bool clean = !nz_words(p.f, kWordsF) && !nz_words(p.h, kWordsH) &&
                 !nz_words(p.ll, kWordsLL) && !nz_words(p.acc_o, kWordsAcc);
    g_checks++;
    if (clean && dut->busy_o == 0) {
      printf("STEP7 reset_mid_run_serial(c10): PASS（F/h/LL/ACC130 全清、busy=0）\n");
    } else {
      fail("STEP7 reset_mid_run_serial", v.name, 10);
      printf("STEP7 reset_mid_run_serial(c10): FAIL（clean=%d busy=%d）\n",
             (int)clean, (int)dut->busy_o);
    }
    run_vector(dut, vcd, ctx, v, p, &obs, /*serial=*/true);
    g_checks++;
    if (obs.wd_pulses != 1 || !eq_f260(obs.wd, v.result)) {
      fail("serial 复位后重跑结果不符", v.name, kSerialCompletion);
    } else {
      printf("STEP7 reset_then_rerun_serial: PASS\n");
    }
  }
  // (c) 模式切换不留残留：先 serial 跑一次，再 overlap 跑同一条向量，结果都正确
  {
    const P2Vector &v = kP2Vectors[2];
    RunObs a, b;
    run_vector(dut, vcd, ctx, v, p, &a, /*serial=*/true);
    run_vector(dut, vcd, ctx, v, p, &b, /*serial=*/false);
    g_checks++;
    if (a.wd_pulses != 1 || b.wd_pulses != 1 ||
        !eq_f260(a.wd, v.result) || !eq_f260(b.wd, v.result)) {
      fail("serial→overlap 切换后结果不符", v.name, 0);
    } else {
      printf("STEP7 mode_switch_no_stale: PASS（serial 一次 + overlap 一次，结果都对）\n");
    }
  }

  printf("PASS - %d errors / %d checks\n", g_errs, g_checks);
  printf("Test %s all %d vectors (dual-schedule)\n", g_errs ? "***FAILED***" : "***PASSED***",
         kP2NumVectors);

  vcd->close();
  delete vcd;
  delete dut;
  delete ctx;
  return g_errs ? 1 : 0;
}
