#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""P7：把 yosys 的面积报告变成 Step 7 要的**六类拆分**（全部实测、不手抄）。

**为什么不用仓库里那个 `get_kge.py`**：`hw/vendor/lowrisc_ibex/syn/python/get_kge.py:50` 把报告的
**第一列当 cell 名**（`weight = weighted_dict.get(data[0])`），而 yosys 0.64 的 `stat` 报告列序是
**`<个数> <面积> <cell名>`** ⇒ 一个 cell 都匹配不上、累加器停在 0（于是打印 `Area in kGE = 0.0`）。
本工具按 0.64 的列序解析，并顺手给出 Step 7 的六类拆分；**不 patch vendored 脚本**。

输入：`$LR_SYNTH_OUT_DIR/reports/area.rpt`（yosys `stat` 的输出）
输出：Markdown（stdout + `--out`）

判据/自证：
  · 六类之和 + 未分类 == 报告里所有 cell 行之和（恒等式，本工具显式打印）；
  · kGE 的参考单元取 `NAND2_X1`，其单元面积**由报告自身推得**（该行总面积 / 该行个数），
    因此不需要 liberty 文件、也不受库版本影响；参考单元缺失则报错退出（不猜）。

⚠ **完整性/安全控制**这一类**不是 cell 类型**（ECC/blanking 逻辑与普通 NAND 同级），平铺报告
分不出来 ⇒ 本工具只标 `n/a`，必须由 **L1（fold 单元单独综合）** 或模块级 `stat` 得到。
"""
import argparse
import re
import sys

for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

CELL_LINE = re.compile(r"^\s*(\d+)\s+([0-9.]+(?:[eE][+-]?\d+)?)\s+([A-Za-z_][A-Za-z0-9_]*)\s*$")
TOTAL_LINE = re.compile(r"Chip area for module '\\?([\w$]+)':\s*([0-9.]+)")
SEQ_LINE = re.compile(r"of which used for sequential elements:\s*([0-9.]+)\s*\(([0-9.]+)%\)")

# 分类：**按顺序**首个命中生效（Nangate45 的 cell 命名）
CATS = [
    ("寄存器", ("DFF", "SDFF", "EDFF", "LATCH", "DLATCH")),
    ("clock gating", ("CLKGATE",)),
    ("buffer", ("BUF_", "BUFX", "CLKBUF")),
    ("mux", ("MUX",)),
    ("组合逻辑", ("INV", "NAND", "NOR", "XOR", "XNOR", "AOI", "OAI", "AND", "OR", "HA", "FA", "TIE", "LOGIC")),
]


def classify(cell):
    for name, prefixes in CATS:
        if cell.startswith(prefixes):
            return name
    return "其它（未分类）"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--area-rpt", required=True)
    ap.add_argument("--out")
    ap.add_argument("--top", type=int, default=15, help="Top-N cell 表")
    ap.add_argument("--label", default="", help="本次运行的名字（如 A0 / A1 / B0）")
    args = ap.parse_args()

    txt = open(args.area_rpt, encoding="utf-8", errors="replace").read()
    cells, total, seq, seq_pct, mod = [], None, None, None, None
    for line in txt.split("\n"):
        m = CELL_LINE.match(line)
        if m:
            cells.append((m.group(3), int(m.group(1)), float(m.group(2))))
            continue
        m = TOTAL_LINE.search(line)
        if m:
            mod, total = m.group(1), float(m.group(2))
        m = SEQ_LINE.search(line)
        if m:
            seq, seq_pct = float(m.group(1)), float(m.group(2))

    assert cells, "报告里没有解析到任何 cell 行（格式变了？）"
    assert total is not None, "报告里没有 'Chip area for module' 行"

    sum_cells = sum(a for _, _, a in cells)
    agg = {}
    for cell, cnt, area in cells:
        e = agg.setdefault(classify(cell), [0, 0.0])
        e[0] += cnt
        e[1] += area

    ref = next((a / cnt for name, cnt, a in cells if name == "NAND2_X1"), None)
    assert ref, "报告里没有 NAND2_X1 ⇒ 无法定 kGE 参考（不猜）"

    L = []
    L.append("# yosys 面积报告（%s）" % (args.label or args.area_rpt))
    L.append("")
    L.append("- 顶层模块：`%s`" % mod)
    L.append("- **总面积：%.3f µm²**（Nangate45）；时序单元 %.3f（%.2f%%）"
             % (total, seq if seq is not None else float("nan"),
                seq_pct if seq_pct is not None else float("nan")))
    L.append("- **kGE：%.1f**（= %.1f GE；参考单元 `NAND2_X1` = %.4f µm²，由报告自身推得：%.2f/%.0f）"
             % (total / ref / 1000, total / ref, ref,
                next(a for name, cnt, a in cells if name == "NAND2_X1"),
                next(cnt for name, cnt, a in cells if name == "NAND2_X1")))
    L.append("- cell 行合计 %.3f µm² vs 报告总面积 %.3f µm²（差 %.3f = %.2f%%）"
             % (sum_cells, total, total - sum_cells,
                100 * (total - sum_cells) / total))
    L.append("")
    L.append("## 六类拆分（Step 7 口径；**完整性/安全控制**见文末说明）")
    L.append("")
    L.append("| 类别 | 实例数 | 面积 µm² | 占面积 | 占 kGE |")
    L.append("|---|---:|---:|---:|---:|")
    order = ["寄存器", "组合逻辑", "mux", "buffer", "clock gating", "其它（未分类）"]
    tot6 = 0.0
    for k in order:
        if k not in agg:
            continue
        c, a = agg[k]
        tot6 += a
        L.append("| %s | %s | %.1f | %.2f%% | %.1f |"
                 % (k, f"{c:,}", a, 100 * a / total, a / ref / 1000))
    L.append("| **合计** |  | **%.1f** | **%.2f%%** | **%.1f** |"
             % (tot6, 100 * tot6 / total, tot6 / ref / 1000))
    L.append("| 完整性/安全控制 | n/a | n/a | n/a | n/a |")
    L.append("")
    L.append("> **完整性/安全控制那一类不是 cell 类型**（ECC/blanking 逻辑由普通 NAND/XOR 组成），"
             "平铺报告分不出来 ⇒ 必须由 **L1（fold 单元单独综合）** 或模块级 `stat` 归属，"
             "本表**不猜**（Step 7 判据 3 明令该类别单列、不得混入功能面积）。")
    L.append("")
    L.append("## Top %d cell" % args.top)
    L.append("")
    L.append("| cell | 实例数 | 面积 µm² |")
    L.append("|---|---:|---:|")
    for cell, cnt, area in sorted(cells, key=lambda x: -x[2])[:args.top]:
        L.append("| `%s` | %s | %.1f |" % (cell, f"{cnt:,}", area))
    L.append("")

    out = "\n".join(L)
    print(out)
    if args.out:
        open(args.out, "w", encoding="utf-8").write(out + "\n")
        print("\n[写] %s" % args.out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
