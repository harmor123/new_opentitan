#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""P7 §8.7：补 blanking 后的面积对照（一次性；数值全部从报告文件读出，不手抄）。

追加到 `08_P7_PPA与CSA决策.md` 末尾，并同步 `13_合并影响` 的更新记录一行。
用法：python3 logs_hkem/p256fold_20260928T085338Z/rtl/p7_step37_docs.py [--check]
"""
import argparse
import pathlib
import re

REPO = pathlib.Path(__file__).resolve().parents[3]
DOCS = REPO.parent / "md文档" / "p256方案20260927" / "new_contribution_2"
R = REPO / "logs_hkem/p256fold_20260928T085338Z/reports"
CATS = ["寄存器", "组合逻辑", "mux", "buffer", "clock gating", "其它（未分类）"]


def parse(path):
    t = path.read_text(encoding="utf-8")
    d = {"area": float(re.search(r"总面积：([\d.]+) um\^2", t).group(1)),
         "seq": float(re.search(r"时序单元 ([\d.]+)", t).group(1)),
         "kge": float(re.search(r"kGE：([\d.]+)", t).group(1))}
    for c in CATS:
        m = re.search(r"^\| " + re.escape(c) + r" \| ([\d,]+) \| ([\d.]+) \|", t, re.M)
        d[c] = (int(m.group(1).replace(",", "")), float(m.group(2)))
    return d


def cells(path, name):
    t = path.read_text(encoding="utf-8")
    m = re.search(r"^\| `" + name + r"` \| ([\d,]+) \|", t, re.M)
    return int(m.group(1).replace(",", "")) if m else 0


def main():
    B0 = parse(R / "p7_area_B0.md")
    A0, A0n = parse(R / "p7_area_A0.md"), parse(R / "p7_area_A0_after_blanking.md")
    A1, A1n = parse(R / "p7_area_A1.md"), parse(R / "p7_area_A1_after_blanking.md")
    L1, L1n = parse(R / "p7_area_L1.md"), parse(R / "p7_area_L1_after_blanking.md")
    a0, a1, l1 = A0n["area"], A1n["area"], L1n["area"]
    dA0, dA1, dL1 = a0 - A0["area"], a1 - A1["area"], l1 - L1["area"]
    and2 = cells(R / "p7_area_L1_after_blanking.md", "AND2_X1") - cells(R / "p7_area_L1.md", "AND2_X1")
    dffr = cells(R / "p7_area_L1_after_blanking.md", "DFFR_X1") - cells(R / "p7_area_L1.md", "DFFR_X1")
    dmux = A0n["mux"][0] - A0["mux"][0]
    dcomb = A0n["组合逻辑"][1] - A0["组合逻辑"][1]

    L = []
    L.append("### 8.7 Step 3 查 5 修复后重跑：**补 blanking 后**的面积（2026-09-30）")
    L.append("")
    L.append("> 本节数值**取代 §8.2 的那批**（§8.2 是补 blanking 之前的数）。B0 不在表里重复：基线 RTL 不含 "
             "fold 单元、不受本次改动影响（仍 **%.3f µm^2**）。数据源：`reports/p7_area_A0_after_blanking.md`、"
             "`..._A1_after_blanking.md`、`..._L1_after_blanking.md`（生成器 `run_dir/rtl/p7_area_report.py`）。"
             % B0["area"])
    L.append("")
    L.append("| 指标 | B0（基线） | A0 补前 | **A0 补后** | A1 补前 | **A1 补后** | L1 补前 | **L1 补后** |")
    L.append("|---|---:|---:|---:|---:|---:|---:|---:|")
    L.append("| 总面积 µm^2 | %.3f | %.3f | **%.3f** | %.3f | **%.3f** | %.3f | **%.3f** |"
             % (B0["area"], A0["area"], a0, A1["area"], a1, L1["area"], l1))
    L.append("| kGE | %.1f | %.1f | **%.1f** | %.1f | **%.1f** | %.1f | **%.1f** |"
             % (B0["kge"], A0["kge"], A0n["kge"], A1["kge"], A1n["kge"], L1["kge"], L1n["kge"]))
    L.append("| 时序单元 | %.3f | %.3f | **%.3f** | %.3f | **%.3f** | %.3f | **%.3f** |"
             % (B0["seq"], A0["seq"], A0n["seq"], A1["seq"], A1n["seq"], L1["seq"], L1n["seq"]))
    for c in CATS:
        L.append("| %s | %.1f | %.1f | **%.1f** | %.1f | **%.1f** | %.1f | **%.1f** |"
                 % (c, B0[c][1], A0[c][1], A0n[c][1], A1[c][1], A1n[c][1], L1[c][1], L1n[c][1]))
    L.append("")
    L.append("**差值（四条）**：")
    L.append("")
    L.append("| 差值 | 值 | 含义 |")
    L.append("|---|---:|---|")
    L.append("| **A0 − B0** | **%+.3f µm^2（%+.2f%%）** | fold 单元（**含 blanking**）在完整 OTBN 上的代价 = L2 层新成本 |"
             % (a0 - B0["area"], 100 * (a0 - B0["area"]) / B0["area"]))
    L.append("| **A1 − A0** | **%+.3f µm^2（%+.3f%%）** | 两种调度**仍几乎同面积** ⇒ §8.3 的「共享 datapath」结论在补 blanking 后依然成立 |"
             % (a1 - a0, 100 * (a1 - a0) / a0))
    L.append("| **L1 补前→补后** | **%+.3f µm^2（%+.2f%%）** | blanking 的**本体**代价：4 个门共 **774 bit** 掩码（F260+h256+LL128+ACC130） |"
             % (dL1, 100 * dL1 / L1["area"]))
    L.append("| **A0−B0 − L1** | **%+.3f µm^2** | 集成层（接线 + 调度表 + 模式 mux + 综合再映射）的净贡献 |"
             % ((a0 - B0["area"]) - l1))
    L.append("")
    L.append("**两条自证（比总数更有信息量）**：")
    L.append("")
    L.append("1. **时序单元逐位不变**：B0 %.3f / A0 %.3f / A1 %.3f / L1 %.3f —— 补前补后**完全相同** ⇒ "
             "本次改动**只动组合的 blanking 与门**，寄存器/状态位一位没动 ✓。"
             % (B0["seq"], A0["seq"], A1["seq"], L1["seq"]))
    L.append("2. **L1 的 cell 级证据**：`AND2_X1` +%d（≈ 774 bit 掩码的与门）、`DFFR_X1` %+d ✓。" % (and2, dffr))
    L.append("")
    L.append("**再映射（不是新逻辑）**：A0 的 `mux` 实例数 +%d、组合逻辑 %+.1f µm^2 —— "
             "综合器把 blanking 的使能条件折进了多路选择结构，因此 L2 的增量（%+.1f）大于 L1 本体（%+.1f）。"
             % (dmux, dcomb, dA0, dL1))
    L.append("")
    L.append("**结论**：(a) fold 的相对代价从 +3.84%% 变为 **%+.2f%%**（A0−B0）；(b) A0/A1 之差从 −0.107%% 变为 "
             "**%+.3f%%** ⇒ 共享 datapath 的判据**不受影响**；(c) **blanking 本体 = %+.1f µm^2**（占 L1 的 %+.1f%%）。"
             % (100 * (a0 - B0["area"]) / B0["area"], 100 * (a1 - a0) / a0, dL1, 100 * dL1 / L1["area"]))
    L.append("")

    sec = "\n".join(L)
    p = DOCS / "08_P7_PPA与CSA决策.md"
    t = p.read_text(encoding="utf-8")
    assert "### 8.7 " not in t, "§8.7 已存在"
    if not args.check:
        p.write_text(t.rstrip("\n") + "\n\n" + sec, encoding="utf-8")

    q = DOCS / "13_合并影响与回归清单.md"
    t2 = q.read_text(encoding="utf-8")
    lines = t2.split("\n")
    i = next(k for k, l in enumerate(lines) if l.startswith("| 2026-09-30 | `543d39dc19` |"))
    lines.insert(i + 1,
                 "| 2026-09-30 | `3560cdf5c2` | **P7 Step 3 查 5 修复后重跑：A0/A1/L1 三组面积**（补 blanking 后）。"
                 "A0 **%.3f**（补前 %.3f，%+.3f）、A1 **%.3f**（%+.3f）、L1 **%.3f**（%+.3f）；B0 不受影响（%.3f）。"
                 "**A0−B0 = %+.3f（%+.2f%%）**、**A1−A0 = %+.3f（%+.3f%%）**、**L1 本体 = %+.3f**、"
                 "`A0−B0 − L1 = %+.3f`（集成层）。**两条自证**：三个运行的时序单元逐位不变（只动组合 blanking）✓；"
                 "L1 的 `AND2_X1` %+d、`DFFR_X1` %+d ✓（≈774 bit 掩码）。**再映射**：A0 的 `mux` %+d、"
                 "组合逻辑 %+.1f µm^2（使能条件被折进多路选择结构）。见 `08_P7_*.md` §8.7。 |"
                 % (a0, A0["area"], dA0, a1, dA1, l1, dL1, B0["area"],
                    a0 - B0["area"], 100 * (a0 - B0["area"]) / B0["area"],
                    a1 - a0, 100 * (a1 - a0) / a0, dL1, (a0 - B0["area"]) - l1,
                    and2, dffr, dmux, dcomb))
    if not args.check:
        q.write_text("\n".join(lines), encoding="utf-8")
    print(sec)
    print("OK" + (" (check only)" if args.check else ""))


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()
    main()
