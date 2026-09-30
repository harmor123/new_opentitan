#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""逐行对照两版的 ISS 剖面 JSON（默认 ver1_1 vs ver1_2）。

判据（ver1_2 的 ML-KEM/HKDF 内核与 ver1_1 **逐字节相同** ⇒ 应当逐行相同）：
  · rows：按 `phase` 配对，比较全部数值字段（含 `insn_histo` 与 `calls` 的每个键）
  · apps：每个 op 的 cycles/insn/exec_insn/iss_cycles/stalls
  · closure：每个 op 的 sum/app/residual/residual_pct
任何一处不同都要打出来 —— 不同就说明派生/环境有问题，不许放过。

用法：python3 p5_cmp_profiling.py [--a ver1_1] [--b ver1_2]
"""
import argparse
import json
import pathlib
import sys

REPO = pathlib.Path(__file__).resolve().parents[3]
NUM_FIELDS = ["cycles", "prof_cycles", "ctrl_cycles", "insn", "stalls",
              "text", "data", "bss", "image", "mulqacc",
              "prof_err_bits", "ctrl_err_bits", "prof_ecall", "closure"]
APP_FIELDS = ["cycles", "insn", "exec_insn", "iss_cycles", "stalls"]
CLOSURE_FIELDS = ["sum", "app", "residual", "residual_pct"]


def load(ver):
    p = REPO / ("logs_hkem/%s_profiling/re_%s.json" % (ver, ver))
    if not p.exists():
        sys.exit("找不到 %s（先跑 harness 并提交产物）" % p)
    return json.loads(p.read_text(encoding="utf-8"))


def rows_by_phase(d):
    return {r["phase"]: r for r in d["rows"]}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--a", default="ver1_1")
    ap.add_argument("--b", default="ver1_2")
    args = ap.parse_args()
    A, B = load(args.a), load(args.b)
    ra, rb = rows_by_phase(A), rows_by_phase(B)
    bad = []

    print("== rows（%d vs %d）" % (len(ra), len(rb)))
    if set(ra) != set(rb):
        print("  仅 %s 有：%s" % (args.a, sorted(set(ra) - set(rb))))
        print("  仅 %s 有：%s" % (args.b, sorted(set(rb) - set(ra))))
        bad.append("阶段集合不同")
    n_same = 0
    for ph in sorted(set(ra) & set(rb)):
        diff = []
        for f in NUM_FIELDS + ["fips", "evidence", "halt_warn"]:
            if ra[ph].get(f) != rb[ph].get(f):
                diff.append("%s: %r → %r" % (f, ra[ph].get(f), rb[ph].get(f)))
        for f in ["insn_histo", "calls"]:
            ka, kb = ra[ph].get(f) or {}, rb[ph].get(f) or {}
            for k in sorted(set(ka) | set(kb)):
                if ka.get(k, 0) != kb.get(k, 0):
                    diff.append("%s[%s]: %r → %r" % (f, k, ka.get(k, 0), kb.get(k, 0)))
        if diff:
            print("  [DIFF] %-34s" % ph)
            for x in diff:
                print("         " + x)
            bad.append(ph)
        else:
            n_same += 1
    print("  逐行相同：%d/%d" % (n_same, len(ra)))

    print("== apps")
    for op in sorted(A["apps"][args.a]):
        x, y = A["apps"][args.a][op], B["apps"][args.b][op]
        d = ["%s: %r → %r" % (f, x.get(f), y.get(f)) for f in APP_FIELDS
             if x.get(f) != y.get(f)]
        print("  %-6s %s" % (op, "同" if not d else "DIFF " + "; ".join(d)))
        if d:
            bad.append("apps." + op)

    print("== closure（Σ / app / 残差）")
    for op in sorted(A["closure"][args.a]):
        x, y = A["closure"][args.a][op], B["closure"][args.b][op]
        d = ["%s: %r → %r" % (f, x.get(f), y.get(f)) for f in CLOSURE_FIELDS
             if x.get(f) != y.get(f)]
        print("  %-6s Σ=%s app=%s 残差=%s (%.2f%%) %s"
              % (op, y["sum"], y["app"], y["residual"], y["residual_pct"],
                 "" if not d else "DIFF " + "; ".join(d)))
        if d:
            bad.append("closure." + op)

    if bad:
        print("\nFAIL  有差异：%s" % bad)
        return 1
    print("\nPASS  %s 与 %s 逐行逐字段相同（内核逐字节相同，符合预期）"
          % (args.b, args.a))
    return 0


if __name__ == "__main__":
    sys.exit(main())
