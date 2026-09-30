#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""P7 Step 4：读 STA 时序报告，给各组最差 slack、最差 N 条、以及**路径端点归属**。

**为什么不用 flow 自带的翻译器**：`translate_timing_rpts.sh` → `translate_timing_csv.py`
→ `python/flow_utils.py:61` 在 `build_translated_names_dict` 里对不含 `/` 的行做 `split('/', 1)[1]`
而 `IndexError`；该脚本在 `syn_yosys.sh:208` 也没有 `|| error` 保护 ⇒ 崩了不影响报告（`sta` 在第 204 行
已写完）。**第一段 `build_translated_names.py` 不碰那段代码** ⇒ 它产出的名字映射
`<run>/generated/ys_translated_names` 是完整的、可直接用。

名字映射的格式（实测）：ABC 生成的单元 `otbn_core/_NNNNN_` 与它 Q 网络上的**原始对象名**
（带层级，如 `otbn_core/u_otbn_rf_bignum...rf`）**紧邻**出现。**但不能按「每两行一组」按索引配对** ——
实测该文件不是全局 2 行步长（`select -list` 每次打印的行数会变），按索引配对会**错配**；
故按相邻行配对（优先下一行，回退上一行，并在报告表头印出回退组数）。

输入：
  `<timing-dir>/{overall,reg2reg,reg2out,in2reg,in2out}.csv.rpt`（`起点,终点,slack`）
  `--names <run>/generated/ys_translated_names`（可选；给了就加归属列）

用法：
  python3 logs_hkem/p256fold_20260928T085338Z/rtl/p7_sta_report.py \
      --timing-dir hw/ip/otbn/pre_syn/syn_out/otbn_core_2026_09_30_16_59_16/reports/timing \
      --names     hw/ip/otbn/pre_syn/syn_out/otbn_core_2026_09_30_16_59_16/generated/ys_translated_names \
      --label "A0（serial 常量化，TIMING_RUN=1，ABC -D 4000）" --top 12 \
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
GEN = re.compile(r"^(?:.*/)?(_\d+_)$")
POINT = re.compile(r"^(?:.*/)?(_\d+_)(?:/\w+)?$")
HDR = "Start Point, End Point, WNS (ns)"


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


def read_names(path):
    """ys_translated_names → {_NNNNN_: 归属名}。

    **不按「每两行一组」配对**：实测该文件并非全局 2 行步长（各次迭代 `select -list`
    打印的行数会变），按索引配对会把大量条目**错配**（据此曾得出错误的路径归属）。
    改为**按相邻行**：某个 `_NNNNN_` 行的归属 = 紧邻的**非 `_NNNNN_` 行**（优先下一行）。
    自检：A0 里 `_317066_ → rf_bignum_predec`、`_278426_ → …u_otbn_rf_bignum_inner.rf`，
    与直接 `grep -A1` 看到的邻接关系一致。
    """
    lines = [ln.strip() for ln in
             pathlib.Path(path).read_text(encoding="utf-8", errors="replace").split("\n")
             if ln.strip()]
    out, fallback = {}, 0
    for i, ln in enumerate(lines):
        m = GEN.match(ln)
        if not m:
            continue
        if i + 1 < len(lines) and not GEN.match(lines[i + 1]):
            out.setdefault(m.group(1), lines[i + 1].split("/", 1)[-1])
        elif i > 0 and not GEN.match(lines[i - 1]):
            out.setdefault(m.group(1), lines[i - 1].split("/", 1)[-1])
            fallback += 1
    return out, fallback


def attr_point(name, names):
    """`otbn_core/_317066_/Q` 或 `_317066_` → 归属名；映射不到就标出。

    两种形式都要认：**原始 csv** 是 `单元/pin`（翻译器崩掉时保持原样，如 A0），
    **被翻译器覆盖过的 csv** 只剩裸单元名（翻译器跑完时，如 L1）。
    """
    if not names:
        return "-"
    m = POINT.match(name)
    if m and m.group(1) in names:
        return names[m.group(1)]
    return "（未在映射中）"


def histogram(rows, names, top):
    """前 top 条 overall 路径的两端归属计数。"""
    st, en = {}, {}
    for s, e, _ in sorted(rows, key=lambda r: r[2])[:top]:
        for d, k in ((st, attr_point(s, names)), (en, attr_point(e, names))):
            d[k] = d.get(k, 0) + 1
    return st, en


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--timing-dir", required=True)
    ap.add_argument("--names", help="<run>/generated/ys_translated_names")
    ap.add_argument("--label", default="")
    ap.add_argument("--top", type=int, default=10)
    ap.add_argument("--attr-top", type=int, default=200,
                    help="归属直方图取最差多少条（默认 200）")
    ap.add_argument("--out")
    args = ap.parse_args()
    d = pathlib.Path(args.timing_dir)
    assert d.is_dir(), "找不到 %s" % d
    names, fallback = read_names(args.names) if args.names else ({}, 0)

    L = ["# 时序报告（%s）" % (args.label or d)]
    L.append("")
    L.append("> 数据源：`%s/*.csv.rpt`（OpenSTA 经 yosys pre_syn 流；本工具直接读原始报告，"
             "绕开坏掉的 vendored 名字翻译器）。每条 = `起点,终点,slack(ns)`；**负 = 违例**。"
             % d.resolve().as_posix())
    if names:
        L.append(">")
        L.append("> 归属列来自 `%s`：%d 组 `_NNNNN_` ↔ 原名（按**相邻行**配对，其中 %d 组走上一行回退）。"
                 % (pathlib.Path(args.names).name, len(names), fallback))
    L.append("")

    per = {}
    overwritten = []
    for g in GROUPS:
        rows = read_group(d, g)
        if rows is None:
            continue
        p = d / ("%s.csv.rpt" % g)
        if p.read_text(encoding="utf-8", errors="replace").startswith(HDR):
            overwritten.append(g)
        per[g] = rows
        if not rows:
            L.append("- **%s**：文件存在但 **0 行**（该组没有路径 / 格式对不上）" % g)
            continue
        worst = min(rows, key=lambda r: r[2])
        L.append("- **%s**：%d 条，最差 slack **%.4f ns**（`%s` → `%s`）"
                 % (g, len(rows), worst[2], worst[0], worst[1]))
    L.append("")
    if overwritten:
        L.append("> ⚠ **这些 csv 已被 vendored 翻译器覆盖**（%s）：`translate_timing_csv.py` 会**原地重写**"
                 "同一个文件、加表头 `%s`、并用 `generated_cell_re` **剥掉 pin 名** ⇒ 只剩裸单元名。"
                 "它自称的「翻译」在本设计上不生效（`build_translated_names_dict` 把字典建成 `{原名: _NNNN_}`，"
                 "而查表用 `_NNNN_`，永不命中）；净效果 = 丢 pin + 加表头。**归属用 `--names` 自己算**。"
                 % (", ".join(overwritten), HDR))
        L.append("")

    ov = per.get("overall", [])
    if ov:
        L.append("## 最差 %d 条路径（overall 组）" % args.top)
        L.append("")
        if names:
            L.append("| # | 起点 | 起点归属 | 终点 | 终点归属 | slack (ns) |")
            L.append("|---:|---|---|---|---|---:|")
        else:
            L.append("| # | 起点 | 终点 | slack (ns) |")
            L.append("|---:|---|---|---:|")
        for i, (s, e, sl) in enumerate(sorted(ov, key=lambda r: r[2])[:args.top], 1):
            if names:
                L.append("| %d | `%s` | `%s` | `%s` | `%s` | **%.4f** |"
                         % (i, s, attr_point(s, names), e, attr_point(e, names), sl))
            else:
                L.append("| %d | `%s` | `%s` | **%.4f** |" % (i, s, e, sl))
        L.append("")

        L.append("## 各组的 slack 范围")
        L.append("")
        L.append("| 组 | 条数 | 最差 | 最好 |")
        L.append("|---|---:|---:|---:|")
        for g, rows in per.items():
            if not rows:
                L.append("| %s | 0 | — | — |" % g)
                continue
            sl = sorted(r[2] for r in rows)
            L.append("| %s | %d | %.4f | %.4f |" % (g, len(sl), sl[0], sl[-1]))
        L.append("")

    if names and ov:
        st, en = histogram(ov, names, args.attr_top)
        L.append("## 前 %d 条路径的端点归属（top 12）" % args.attr_top)
        L.append("")
        for title, h in (("起点归属", st), ("终点归属", en)):
            L.append("**%s**" % title)
            L.append("")
            L.append("| 归属名 | 条数 |")
            L.append("|---|---:|")
            for k, v in sorted(h.items(), key=lambda kv: -kv[1])[:12]:
                L.append("| `%s` | %d |" % (k, v))
            L.append("")

    out = "\n".join(L)
    print(out)
    if args.out:
        pathlib.Path(args.out).write_text(out + "\n", encoding="utf-8")
        print("[写] %s" % args.out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
