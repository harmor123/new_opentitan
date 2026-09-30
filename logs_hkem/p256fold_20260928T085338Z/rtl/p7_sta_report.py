#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""P7 Step 4：读 OpenSTA（yosys pre_syn 流经 sta 跑出）的时序报告，给出各路径组的最差 slack 与最差 N 条。

**为什么不用 flow 自带的翻译器**：`translate_timing_rpts.sh` → `python/translate_timing_csv.py`
→ `hw/vendor/lowrisc_ibex/syn/python/flow_utils.py:61` 按"每两行一对 + `split('/', 1)[1]`"读名字映射表，
遇到**不含 `/` 的行**（我们新增的裸模块名，如 `otbn_p256_fold`）就 `IndexError` ✗ ⇒ 整条后处理挂掉。
那个翻译器只是"把网名翻成人读的名字"；**报告本体是完整的** ⇒ 本工具直接读原始 `*.csv.rpt`，不改 vendored 脚本。

输入：`<timing-dir>` 下的 `{overall,in2reg,reg2reg,reg2out,in2out}.csv.rpt`（三列：起点,终点,slack）
输出：Markdown（stdout + `--out`）

用法：
  python3 logs_hkem/p256fold_20260928T085338Z/rtl/p7_sta_report.py \
      --timing-dir hw/ip/otbn/pre_syn/syn_out/latest/reports/timing \
      --label "A0（serial 常量化，-D 4000）" \
      --out logs_hkem/p256fold_20260928T085338Z/reports/p7_sta_A0.md
"""
import argparse
import pathlib
import re
import sys

for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

GROUPS = ["overall", "reg2reg", "reg2out", "in2reg", "in2out"]
ROW = re.compile(r"^\s*(\S+),(\S+),\s*(-?[0-9.]+)\s*$")


def read_group(d, g):
    p = d / ("%s.csv.rpt" % g)
    if not p.exists():
        return None
    rows = []
    for ln in p.read_text(encoding="utf-8", errors="replace").split("\n"):
        m = ROW.match(ln)
        if m:
            rows.append((m.group(1), m.group(2), float(m.group(3))))
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--timing-dir", required=True)
    ap.add_argument("--label", default="")
    ap.add_argument("--top", type=int, default=10)
    ap.add_argument("--out")
    args = ap.parse_args()
    d = pathlib.Path(args.timing_dir)
    assert d.is_dir(), "找不到 %s" % d

    L = ["# 时序报告（%s）" % (args.label or d)]
    L.append("")
    L.append("> 数据源：`%s/*.csv.rpt`（OpenSTA 经 yosys pre_syn 流；本工具直接读原始报告，"
             "绕开坏掉的 vendored 名字翻译器）。每条 = `起点,终点,slack(ns)`；**负 = 违例**。"
             % d.resolve().as_posix())
    L.append("")
    per = {}
    for g in GROUPS:
        rows = read_group(d, g)
        if rows is None:
            continue
        per[g] = rows
        worst = min(rows, key=lambda r: r[2])
        L.append("- **%s**：%d 条，最差 slack **%.4f ns**（`%s` → `%s`）"
                 % (g, len(rows), worst[2], worst[0], worst[1]))
    L.append("")
    L.append("## 最差 %d 条路径（overall 组）" % args.top)
    L.append("")
    L.append("| # | 起点 | 终点 | slack (ns) |")
    L.append("|---:|---|---|---:|")
    for i, (s, e, sl) in enumerate(sorted(per.get("overall", []), key=lambda r: r[2])[:args.top], 1):
        L.append("| %d | `%s` | `%s` | **%.4f** |" % (i, s, e, sl))
    L.append("")
    L.append("## 各组的 slack 分布（前 5 档）")
    L.append("")
    L.append("| 组 | 最差 | 中位（近似） | 最好 |")
    L.append("|---|---:|---:|---:|")
    for g, rows in per.items():
        sl = sorted(r[2] for r in rows)
        L.append("| %s | %.4f | %.4f | %.4f |" % (g, sl[0], sl[len(sl) // 2], sl[-1]))
    L.append("")

    out = "\n".join(L)
    print(out)
    if args.out:
        pathlib.Path(args.out).write_text(out + "\n", encoding="utf-8")
        print("[写] %s" % args.out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
