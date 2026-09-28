#!/usr/bin/env python3
"""P3 调度预检：逐句模拟 `otbn_p256_fold.sv` 的 **overlap / serial 两种调度**，与模型逐拍比对。

用途与边界（必须一起读）：
  * 转写的是**改动后**的 .sv：P3 只加了两样东西——`mode_serial_i`（在 start 拍锁存为 mode_q）与
    语义相位 `phase`（row/tail 逻辑按它索引）。采样点（c3/c9/c12/c15）仍按**原始拍号**判定。
  * 判据 ①（P2 回归）：overlap 模式下逐拍 F 必须与 `p2_vectors.json` 的 `fold_F` **逐位相同**
    ——即"P2 已验证的 22 拍调度一字未变"。
  * 判据 ②（P3 新调度）：serial 模式下逐拍 F 必须等于 overlap 轨迹的**重映射**
      serial[c] = overlap[c]      (c ≤ 9)
      serial[c] = overlap[3]      (10 ≤ c ≤ 15，row 全部推迟 ⇒ F 保持 seed)
      serial[c] = overlap[c − 6]  (16 ≤ c ≤ 27)
    且 h/LL/ACC130 的采样拍与值**两种模式完全相同**，k 在 serial 的 c25、wd 在 serial 的 c27。
  * 判据 ③（完成周期固定）：overlap 22 拍（c0…c21）、serial 28 拍（c0…c27），与操作数无关。
  * 本脚本检查"SV 源码语义 vs 模型"，**不是** RTL 仿真结果；判 RTL 的仍是 Verilator 单模块 TB。
  * 不修改 P2 的 `p2_rtl_emul.py`（在 P2 冻结清单里）——只 import 它的常量解析与未改动的数据通路转写。

用法：PYTHONUTF8=1 python3 p3_fold_emul.py [--fuzz N]
"""
import argparse
import importlib.util
import json
import random
from pathlib import Path

HERE = Path(__file__).resolve().parent           # logs_hkem/<run>/rtl
RUN = HERE.parent                                # logs_hkem/<run>
REPO = HERE.parents[2]
UNIT = RUN / "unit"

W = 260
MASKW = (1 << W) - 1
MASK128 = (1 << 128) - 1
MASK130 = (1 << 130) - 1
MASK256 = (1 << 256) - 1

TAIL_SHIFT = 6          # serial：尾部整体后移 6 拍（c10…c21 → c16…c27）


def _load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


p2 = _load("p2_rtl_emul", UNIT / "p2_rtl_emul.py")          # 复用（只读，不改）
m = _load("m", RUN / "model" / "p256_fold_model.py")
mak = _load("make_vectors", UNIT / "make_vectors.py")

sgn = p2.sgn


class Fold:
    """改动后的 otbn_p256_fold.sv 逐句转写（只重写 cpa/step；数据通路复用 P2 的转写）。"""

    def __init__(self, kd, p260, serial=False):
        self.kd = kd
        self.p260 = p260
        self.serial = serial
        self.reset()

    def reset(self):
        self.cycle = 31
        self.busy = False
        self.mode = False            # mode_q：start 拍锁存
        self.f = 0
        self.h = 0
        self.ll = 0
        self.acc130 = 0
        self.k = 0
        self.wd_valid = False
        self.wd = 0

    # 数据通路未改动 ⇒ 直接复用 P2 转写（同一份 h 行向量拼接）
    words = p2.Fold.words
    rows = p2.Fold.rows

    def phase(self, cycle=None, mode=None):
        c = self.cycle if cycle is None else cycle
        mo = self.mode if mode is None else mode
        return (c - TAIL_SHIFT) if (mo and c >= 10) else c

    def cpa(self):
        """与 .sv 的 always_comb（operand mux）对应：一律按 phase 索引。"""
        a, b, sub = self.f & MASKW, 0, 0
        if self.busy:
            c = self.phase()
            if c in (10, 11, 12, 13, 14, 15, 16, 17):
                b, sub = self.rows()[c], 1 if c in (14, 15, 16, 17) else 0
            elif c == 18:
                b = ((self.acc130 << 128) | self.ll) & MASKW
            elif c == 19:
                a = self.f & ((1 << 256) - 1)
                b = self.kd[p2.k4(self.f >> (W - 4))]
            elif c == 20:
                if (self.f >> (W - 1)) & 1:
                    b, sub = self.p260, 0
                else:
                    b, sub = (~self.p260) & MASKW, 1
        return a, b, sub

    def step(self, start=0, abort=0, wipe=0, pre_so=0, acc_after=0):
        """推进一步（组合次态 + 时序）；返回本拍末锁存后的可观测视图。"""
        done = self.cycle if self.busy else 31

        cycle_d, busy_d, mode_d = self.cycle, self.busy, self.mode
        f_d, h_d, ll_d, acc_d, k_d = self.f, self.h, self.ll, self.acc130, self.k
        wd_valid_d, wd_d = False, self.wd
        a, b, sub = self.cpa()
        ext = sgn(a) + sgn(b) + sub

        if start:
            mode_d, cycle_d, busy_d = self.serial, 0, True
            f_d = h_d = ll_d = acc_d = k_d = 0
            wd_valid_d = False
        elif self.busy:
            cycle_d = (self.cycle + 1) & 0x1F
            c = self.cycle
            ph = self.phase()

            # 采样点：原始拍号（与调度模式无关）
            if c == 3:
                f_d = (pre_so & MASK128) << 128
            elif c == 9:
                h_d = pre_so & MASK256
            elif c == 12:
                ll_d = pre_so & MASK128
            elif c == 15:
                acc_d = acc_after & MASK130

            # 行累加与尾部：语义相位
            if 10 <= ph <= 17:
                f_d = ext & MASKW
            elif ph == 18:
                f_d = ext & MASKW
            elif ph == 19:
                k_d = (self.f >> (W - 4)) & 0xF
                f_d = ext & MASKW
            elif ph == 20:
                f_d = (ext & MASKW) if (((self.f >> (W - 1)) & 1) or
                                        not ((ext >> (W - 1)) & 1)) else self.f
            elif ph == 21:
                wd_d, wd_valid_d = self.f & MASK256, (not abort)
                busy_d = False
        else:
            cycle_d = 31

        if abort or wipe:
            f_d = h_d = ll_d = acc_d = k_d = 0
            wd_valid_d = False
            if abort:
                busy_d, cycle_d = False, 31

        self.cycle, self.busy, self.mode = cycle_d, busy_d, mode_d
        self.f, self.h = f_d & MASKW, h_d
        self.ll, self.acc130, self.k = ll_d, acc_d, k_d
        self.wd_valid, self.wd = wd_valid_d, wd_d
        return {"cycle": done, "busy": self.busy, "F": self.f & MASKW, "h": self.h,
                "ll": self.ll, "acc130": self.acc130, "k": self.k, "mode": self.mode,
                "wd_valid": self.wd_valid, "wd": self.wd}


def run_vector(vec, kd, p260, serial, verbose=False):
    """跑一条向量（指定模式），返回 (逐拍视图, 错误列表)。"""
    dut = Fold(kd, p260, serial=serial)
    H = int(vec["H"], 16)
    high = int(vec["high"], 16)
    ll = int(vec["LL"], 16)
    acc130 = int(vec["ACC130"], 16)
    n_cycles = 28 if serial else 22
    obs = {}
    errs = []
    dut.step(start=1)
    for c in range(n_cycles):
        if vec["source"] == "mac":
            if c < 16:
                p_so, a_so = int(vec["mac_taps"]["pre_so"][c], 16), \
                             int(vec["mac_taps"]["acc_after"][c], 16)
            else:
                p_so, a_so = 0, 0
        else:  # inject
            p_so = {3: H >> 128, 9: high, 12: ll}.get(c, 0)
            a_so = acc130 if c == 15 else 0
        o = dut.step(pre_so=p_so, acc_after=a_so)
        assert o["cycle"] == c, (o["cycle"], c)
        obs[c] = o

    # 采样点：两种模式必须完全相同（PDF §11 P3：保持 c3/c9/c12/c15）
    if obs[3]["F"] != H:
        errs.append("H seed: F@c3 != H")
    if obs[9]["h"] != high:
        errs.append("high capture: h@c9 != high")
    if obs[12]["ll"] != ll:
        errs.append("LL capture: LL@c12 != LL")
    if obs[15]["acc130"] != acc130:
        errs.append("ACC130 capture: @c15 != ACC130")

    # 逐拍 F：overlap 用向量自带轨迹；serial 用重映射
    fold = {int(k): int(v, 16) & MASKW for k, v in vec["fold_F"].items()}
    if serial:
        expect = {}
        for c in range(3, 28):
            if c <= 9:
                expect[c] = fold[3]
            elif c <= 15:
                expect[c] = fold[3]                      # row 推迟 ⇒ F 保持 seed
            else:
                expect[c] = fold[c - TAIL_SHIFT]
    else:
        expect = dict(fold)
    rows = []
    for c in sorted(expect):
        got, want = obs[c]["F"], expect[c]
        rows.append((c, got, want, got == want))
        if got != want:
            errs.append("F mismatch @c%d(serial=%d): rtl 0x%x model 0x%x"
                        % (c, serial, got, want))

    # k 与写回（拍号随模式：overlap c19/c21，serial c25/c27）
    k_cycle, wb_cycle = (25, 27) if serial else (19, 21)
    if obs[k_cycle]["k"] != (vec["q"] & 0xF):
        errs.append("k@c%d != q" % k_cycle)
    if not obs[wb_cycle]["wd_valid"] or obs[wb_cycle]["wd"] != int(vec["result"], 16):
        errs.append("wd@c%d != result" % wb_cycle)

    # 完成周期固定（22 / 28）+ 只有 WB 相位退出 busy（无早退）
    if dut.busy or dut.cycle != n_cycles:
        errs.append("completion: cycle=%d busy=%d（应 c%d 且 busy=0）"
                    % (dut.cycle, dut.busy, n_cycles))
    dut.step()
    if dut.cycle != 31 or dut.busy:
        errs.append("idle: cycle=%d（应为 31）" % dut.cycle)
    return rows, errs


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--vectors", type=Path, default=UNIT / "p2_vectors.json")
    ap.add_argument("--rtl", type=Path,
                    default=REPO / "hw/ip/otbn/rtl/otbn_p256_fold.sv")
    ap.add_argument("--fuzz", type=int, default=0)
    ap.add_argument("--verbose", action="store_true")
    args = ap.parse_args()

    kd = p2.parse_kd(args.rtl)
    case_bad = p2.check_unique_case(args.rtl)
    if case_bad:
        for (line, why) in case_bad:
            print("unique case 检查 FAIL: 行 %s: %s" % (line, why))
        raise SystemExit(1)
    print("unique case 检查: OK（各块标签唯一、default 唯一）")
    p260 = p2.parse_p260(args.rtl)
    assert p260 == m.P, "SV 的 P260 与模型 P 不一致"
    assert kd == {k: (k * m.D) & MASKW for k in range(-4, 8)}, "KD LUT 与模型 k·d 不一致"
    print("KD LUT 自检: OK（12 项 == 模型 k·d，P260 == 模型 P）")

    doc = json.loads(args.vectors.read_text(encoding="utf-8"))
    total_err = 0
    n_serial_hold = 0
    for vec in doc["vectors"]:
        for serial in (False, True):
            rows, errs = run_vector(vec, kd, p260, serial, args.verbose)
            total_err += len(errs)
            if serial and not errs:
                # 判据 ② 的核心读数：c10…c15 的 F 必须与 c3 的 seed 相同（row 全推迟）
                n_serial_hold += 1
            print("%-24s %-8s 拍数=%-2d %s" % (vec["name"], "serial" if serial else "overlap",
                                               len(rows),
                                               "OK" if not errs else "FAIL: " + "; ".join(errs)))
    print("vectors: %d × 2 模式 = %d 次；mismatches: %d；serial 模式全过: %d"
          % (len(doc["vectors"]), 2 * len(doc["vectors"]), total_err, n_serial_hold))

    if args.fuzz:
        rng = random.Random(0x5EED)
        fuzz_err = 0
        for i in range(args.fuzz):
            a, b = rng.randrange(mak.P), rng.randrange(mak.P)
            vec = mak.build_mac(a, b, "fuzz_%04d" % i, "fuzz")
            for serial in (False, True):
                _, errs = run_vector(vec, kd, p260, serial)
                if errs:
                    fuzz_err += len(errs)
                    print("fuzz %d (serial=%d) FAIL: %s" % (i, serial, "; ".join(errs)))
        print("fuzz: %d 条随机 (a,b) × 2 模式，mismatches: %d" % (args.fuzz, fuzz_err))
        total_err += fuzz_err

    print("rtl sha256(LF 归一化，等于 git blob): %s" % p2.file_sha256_lf(args.rtl))
    raise SystemExit(1 if total_err else 0)


if __name__ == "__main__":
    main()
