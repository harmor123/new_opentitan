#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""P7 时钟扫描的合并与自证（两批：6–8 ns 与 11–18 ns），出 `ppa/sweep_all_merged.csv` 与 `ppa/sweep_fmax.csv`。

**自证（不成立即拒绝写 ✗）**：
  1. 同一份网表下 **slack 对周期斜率 = 1.000**（|Δslack/Δperiod − 1| < 1e-3，逐设计）⇒ 单点推算式
     `Fmax = 1/(P + |slack|)` 与扫描**等价** ✓（这条是结论，不是口号）；
  2. **临界路径时延 = 周期 − slack** 逐点恒定（±1e-3）⇒ 可达时钟 = 1/时延 ✓；
  3. 每个设计**正/负两侧都有点** ✓（PDF §17 要"正/负 slack 修正后记录可达时钟"）；
  4. 可达时钟与 §8.12 表（= 1/(8+|wns|)，取含 Step 5 预译码的档）**逐设计一致**（±0.1 MHz）✓。

用法：python3 logs_hkem/p256fold_20260928T085338Z/rtl/p7_sweep_docs.py [--check]
"""
import argparse
import csv
import pathlib
import sys

for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

REPO = pathlib.Path(__file__).resolve().parents[3]
RUN = REPO / "logs_hkem/p256fold_20260928T085338Z"
PPA, REP = RUN / "ppa", RUN / "reports"
LO = PPA / "sweep_all.csv"
HI = PPA / "raw/sweep_hi/sweep_all.csv"
DESIGNS = ("A0", "A1", "B0", "L1")


def load(p, tag):
    rows = list(csv.DictReader(p.open(encoding="utf-8")))
    out = []
    for r in rows:
        if not r.get("design"):
            continue
        out.append({"design": r["design"], "period": float(r["period_ns"]), "slack": float(r["slack_ns"]),
                    "sp": r.get("startpoint", ""), "ep": r.get("endpoint", ""), "batch": tag})
    assert out, "空：%s" % p
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    allr = load(LO, "lo(6-8ns)") + load(HI, "hi(11-18ns)")
    by = {d: sorted([r for r in allr if r["design"] == d], key=lambda r: r["period"]) for d in DESIGNS}
    for d in DESIGNS:
        assert len(by[d]) >= 8, (d, len(by[d]))
        # ① 斜率 = 1.000（相邻点）
        for a, b in zip(by[d], by[d][1:]):
            slope = (b["slack"] - a["slack"]) / (b["period"] - a["period"])
            assert abs(slope - 1.0) < 1e-3, ("斜率 != 1", d, a, b, slope)
        # ② 时延恒定
        delay = [r["period"] - r["slack"] for r in by[d]]
        assert max(delay) - min(delay) < 2e-3, (d, delay)
        # ③ 正/负两侧都有
        assert any(r["slack"] < 0 for r in by[d]) and any(r["slack"] > 0 for r in by[d]), ("缺一侧", d)

    # ④ 与 §8.12 的单点 Fmax 一致（取含 Step 5 预译码的档）
    KEY = {"B0": "B0", "A0": "A0_pred", "A1": "A1_pred", "L1": "L1_pred"}
    import re
    sta = {}
    for d, k in KEY.items():
        t = (REP / ("p7_sta_%s.md" % k)).read_text(encoding="utf-8", errors="replace")
        sta[d] = float(re.search(r"overall\*\*：\d+ 条，最差 slack \*\*(-?[\d.]+) ns\*\*", t).group(1))
    single = {d: 1e3 / (8.0 + abs(sta[d])) for d in DESIGNS}

    merged, fmax = [], []
    for d in DESIGNS:
        delay = by[d][0]["period"] - by[d][0]["slack"]
        sweep_f = 1e3 / delay
        assert abs(sweep_f - single[d]) < 0.1, ("与单点公式不一致", d, sweep_f, single[d])
        neg = max([r for r in by[d] if r["slack"] < 0], key=lambda r: r["period"])
        pos = min([r for r in by[d] if r["slack"] > 0], key=lambda r: r["period"])
        fmax.append({"design": d, "source_tag": "measured",
                     "critical_path_delay_ns": round(delay, 4), "fmax_mhz": round(sweep_f, 1),
                     "neg_point_ns": neg["period"], "neg_slack_ns": neg["slack"],
                     "pos_point_ns": pos["period"], "pos_slack_ns": pos["slack"],
                     "zero_crossing_bracket_ns": "(%g, %g)" % (neg["period"], pos["period"]),
                     "slope_dslack_dperiod": 1.0,
                     "note": "同一份网表（8 ns 的 ABC 单趟映射）下扫描 ⇒ 等价于单点公式 1/(8+|wns|) ✓；"
                             "不冒充「每周期重映射」✗"})
        for r in by[d]:
            merged.append({"design": d, "source_tag": "measured", "batch": r["batch"],
                           "period_ns": r["period"], "slack_ns": r["slack"],
                           "delay_ns": round(r["period"] - r["slack"], 4),
                           "fmax_of_point_mhz": round(1e3 / r["period"], 1) if r["period"] > 0 else 0,
                           "startpoint": r["sp"], "endpoint": r["ep"]})

    if not args.check:
        with (PPA / "sweep_all_merged.csv").open("w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=list(merged[0].keys()))
            w.writeheader()
            w.writerows(merged)
        with (PPA / "sweep_fmax.csv").open("w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=list(fmax[0].keys()))
            w.writeheader()
            w.writerows(fmax)
        print("[写] %s（%d 行）、%s（%d 行）" % (PPA / "sweep_all_merged.csv", len(merged),
                                              PPA / "sweep_fmax.csv", len(fmax)))
    print("design  时延(ns)  可达时钟(MHz)  负点(ns,slack)   正点(ns,slack)   单点公式")
    for d, r in zip(DESIGNS, fmax):
        print("  %-4s %8.4f  %10.1f     (%g, %+.4f)  (%g, %+.4f)   %.1f MHz ✓"
              % (d, r["critical_path_delay_ns"], r["fmax_mhz"], r["neg_point_ns"], r["neg_slack_ns"],
                 r["pos_point_ns"], r["pos_slack_ns"], single[d]))
    print("OK" + (" (check only)" if args.check else ""))


if __name__ == "__main__":
    main()
