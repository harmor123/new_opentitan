#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""P7 §8.14：Step 6「双 CSA 决策」的记录（门限 / 两个数 / 时序限制 / 决策 + Pareto 口径）。

**在 Windows 侧跑**（`md文档/` 在 git 仓库之外）。数值全部从已入库文件读：
  * 代价：`reports/p7_csa_cost_{p7_cpa4_ref,p7_cpa2_ref,p7_csa1_cost,p7_csa2_cost}_area.rpt`（同 flow 综合）
  * fold 面积参照：`reports/p7_energy_L1.md`（同一 TIMING_RUN=1 网表，按 cell 面积累加）
  * 收益（**投影**）：§13.1 的 24 → 22 ⇒ ECDH −19,204 / Keygen −19,186 拍（文档里已登记，逐字核）

断言（不成立即拒绝写）：四个模块的 sequential 面积满足 2× 关系（260 触发器×1/×2）；
面积序 cpa2 < cpa4 < csa1 < csa2；增量区间为正；文档里确有 −19,204 / −19,186 与门限所需的 §8.11/§8.12。

用法：python3 logs_hkem/p256fold_20260928T085338Z/rtl/p7_step6_docs.py [--check] [--docs-dir DIR]
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

REPO = pathlib.Path(__file__).resolve().parents[3]
DOCS = REPO.parent / "md文档" / "p256方案20260927" / "new_contribution_2"
DOC = "08_P7_PPA与CSA决策.md"
QDOC = "13_合并影响与回归清单.md"
R = REPO / "logs_hkem/p256fold_20260928T085338Z/reports"
MODS = ("p7_cpa4_ref", "p7_cpa2_ref", "p7_csa1_cost", "p7_csa2_cost")


def area(m):
    t = (R / ("p7_csa_cost_%s_area.rpt" % m)).read_text(encoding="utf-8", errors="replace")
    a = re.search(r"Chip area for module '[^']+': ([0-9.]+)", t)
    s = re.search(r"used for sequential elements: ([0-9.]+) \(([0-9.]+)%\)", t)
    assert a and s, "area.rpt 缺字段：%s" % m
    return float(a.group(1)), float(s.group(1)), float(s.group(2))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--force", action="store_true", help="重写已存在的 §8.14（措辞修订用）")
    ap.add_argument("--docs-dir")
    args = ap.parse_args()
    global DOCS
    if args.docs_dir:
        DOCS = pathlib.Path(args.docs_dir)

    A = {m: area(m) for m in MODS}
    a4, a2, s1, s2 = (A[m][0] for m in MODS)
    # 断言：面积序与 sequential 的 2× 关系（260 触发器 ×1 / ×2）
    assert a2 < a4 < s1 < s2, A
    assert abs(A["p7_csa1_cost"][1] - 2 * A["p7_cpa2_ref"][1]) < 1e-3, A
    assert abs(A["p7_csa2_cost"][1] - 2 * A["p7_cpa2_ref"][1]) < 1e-3, A
    ff = A["p7_cpa2_ref"][1] / 260.0                     # 每个触发器的面积（µm²）
    d_lo, d_hi = s2 - a4, s2 - a2                        # A2 增量区间
    d4_lo, d4_hi = s1 - a4, s1 - a2                      # A4 增量区间
    assert 0 < d_lo < d_hi, (d_lo, d_hi)
    l1 = (R / "p7_energy_L1.md").read_text(encoding="utf-8", errors="replace")
    m = re.search(r"按 cell 面积累加 = \*\*([0-9.]+) µm²\*\*", l1)
    assert m, "L1 报告里没解析到 fold 面积累加"
    fold = float(m.group(1))

    p = DOCS / DOC
    assert p.exists(), "找不到 %s（本脚本是 Windows 侧工具；确需在别处生成用 --docs-dir）" % p
    t = p.read_text(encoding="utf-8")
    assert "### 8.13 " in t, "§8.13 尚未写入"
    if "#### 8.14 " in t:
        if not args.force:
            raise SystemExit("§8.14 已存在（要重写用 --force）")
        i = t.index("#### 8.14 ")
        j = t.find("\n### ", i)
        t = t[:i] + (t[j + 1:] if j > 0 else "")
    # 门限与收益的出处必须真的在文档里
    for need in ("−19,204", "−19,186", "3.4113"):
        assert need in t, "文档里找不到 %s（门限/收益的出处）" % need

    L = []
    L.append("#### 8.14 Step 6「双 CSA 决策」：门限、两个数与决策口径（2026-09-30）")
    L.append("")
    L.append("**甲、门限**（PDF §11 P7 的次序纪律：「只有在 CPA 主线闭环后，才加入双 CSA」）：**已过** ✓ —— "
             "CPA 主方案（A1）已实现并完成正确性验证与 PPA 实测：面积/时序见 §8.7/§8.10/§8.11，"
             "同频 cycle 与 Fmax 见 §8.12，能耗见 §8.13；fold 本体的残余关键路径为 **3.4113 ns**"
             "（行 mux + 平坦 CPA，§8.11/§8.12）。")
    L.append("")
    L.append("**乙、两个数**")
    L.append("")
    L.append("| 数 | 值 | 来源/状态 |")
    L.append("|---|---|---|")
    L.append("| 性能增量 | 24 → 22 拍/调用 ⇒ **ECDH −19,204 拍、Keygen −19,186 拍**（app 级约 6.1–6.2%） | "
             "**§13.1 的投影** ✗ —— 我们的实测只覆盖 30 → 24 两级（§8.12）；22 那一级**没有对应实现** |")
    L.append("| 面积代价（A2 = 2 级 CSA + 260 位 carry 状态） | **%.1f – %.1f µm²**（占 L1 fold %.1f µm² 的 "
             "**%.1f%%–%.1f%%**） | **本次实测** ✓（探针模块，同 flow/同 liberty/同约束，见丙） |"
             % (d_lo, d_hi, fold, 100 * d_lo / fold, 100 * d_hi / fold))
    L.append("| 面积代价（A4 = 1 级 CSA 形态） | %.1f – %.1f µm²（%.1f%%–%.1f%%） | 同上 ✓ |"
             % (d4_lo, d4_hi, 100 * d4_lo / fold, 100 * d4_hi / fold))
    L.append("| 时序影响 | **不给结论** ✗ | A2 未集成到主数据通路 ⇒ 无法定量；只能定性说：A1 的残余路径是"
             "「行 mux + 平坦 CPA」⇒ 用 CSA + carry 状态替换平坦 CPA 有望缩短其中一部分，但幅度未知 ✗ |")
    L.append("")
    L.append("**丙、面积代价的测法与口径（可复核）**：四个**端口完全相同**的孤立模块（W=260；"
             "clk/rst/en + 4 输入 + sum/carry），只差求和结构，用**流程自带**的 `tcl/yosys_run_synth.tcl` 与 "
             "`tcl/sta_run_reports.tcl`（一行不改）各跑一次 —— 同一 liberty（sha256 `8d540a4d…`）、"
             "clk 8000 ps、ABC `-D 4000`、flatten、`TIMING_RUN=1`，SDC 亦用流程自带的通用模板 ✓。")
    L.append("")
    L.append("| 模块 | 结构 | 面积 µm² | sequential µm²（占比） |")
    L.append("|---|---|---:|---:|")
    for m, desc in (("p7_cpa4_ref", "平坦 CPA 4 项 + 1 寄存器"),
                    ("p7_cpa2_ref", "平坦 CPA 2 项 + 1 寄存器"),
                    ("p7_csa1_cost", "1 级 3:2 压缩 + carry 状态 + 末级 CPA"),
                    ("p7_csa2_cost", "2 级 3:2 压缩 + carry 状态 + 末级 CPA")):
        L.append("| `%s` | %s | %.3f | %.3f（%.1f%%） |" % (m, desc, A[m][0], A[m][1], A[m][2]))
    L.append("")
    L.append("- **内部一致性**（可交叉验证）：`sequential` 面积 = %.3f / %.3f µm²，恰为 **1× / 2×** 关系"
             "（两个 CSA 模块各多一个 260 位寄存器）⇒ 每个触发器 **%.2f µm²**（Nangate45 量级 ✓）。"
             % (A["p7_cpa2_ref"][1], A["p7_csa1_cost"][1], ff))
    L.append("- **增量为何给区间**：A1 的真实 CPA 是「2 操作数 + 操作数 mux」，而 A2 的「两级」对应 **4 项**相加 "
             "⇒ 与哪一侧比较取决于对微架构的假设，故给 [相对 4 项平坦 CPA, 相对 2 项平坦 CPA] 的闭区间 ✓，"
             "不用单一假设定口径 ✗。")
    L.append("")
    L.append("**丁、决策与 Pareto 口径（按 §17 的合法降级路径逐字对照）**")
    L.append("")
    L.append("- **决策**：**主方案保持 CPA（A1）**；A2 记入设计矩阵（Step 10）作为**消融点**。依据：换来的 "
             "−6.1%% app 级时间目前只是**投影** ✗，而面积代价是 **+%.1f%%–%.1f%%** 的 fold 面积（实测 ✓）。"
             % (100 * d_lo / fold, 100 * d_hi / fold))
    L.append("- **本记录不足以支撑「A2 更优」的主张** ✗：若论文要主张它，必须先实现 A2（CSA 版 fold + "
             "ISS/逐拍模型 + KAT）并**实测**面积/时序/能耗，再重做 Pareto。")
    L.append("- **Pareto 写法**：A1 侧给全实测点（面积 %.1f µm²、残余关键路径 3.4113 ns、每调用 24 拍、"
             "`energy/mul` 2.166 nJ；见 §8.12/§8.13）；"
             "A2 侧只给「投影拍数 + 实测增量面积区间」并**逐项标注**，不得把投影写成实测 ✗。"
             % fold)
    L.append("")
    L.append("**复现**（一条命令；产物含四份 `area.rpt` 与时序 csv）：")
    L.append("")
    L.append("```bash")
    L.append("bash logs_hkem/p256fold_20260928T085338Z/rtl/csa_cost/p7_csa_cost_run.sh")
    L.append("```")
    L.append("")

    sec = "\n".join(L)
    if not args.check:
        p.write_text(t.rstrip("\n") + "\n\n" + sec, encoding="utf-8")
        q = DOCS / QDOC
        t2 = q.read_text(encoding="utf-8")
        lines = t2.split("\n")
        if any(l.startswith("| 2026-09-30 | `a616b1ca0d` |") for l in lines):
            print("13 行已存在 ⇒ 不重复插入")
            q.write_text(t2, encoding="utf-8")
            print(sec)
            print("OK")
            return
        i = next(k for k, l in enumerate(lines) if l.startswith("| 2026-09-30 | `670b43ffb3` |"))
        lines.insert(
            i + 1,
            "| 2026-09-30 | `a616b1ca0d` | **P7 Step 6（双 CSA 决策，P7 §8.14）**。门限（§11 P7「CPA 主线闭环后」）"
            "**已过** ✓。两个数：性能增量 24→22 ⇒ ECDH −19,204 / Keygen −19,186 拍（**§13.1 投影** ✗）；"
            "面积代价 **实测** —— 用流程自带 tcl 对四个同端口孤立模块各综合一次（同 liberty/clk 8000 ps/"
            "ABC -D 4000/flatten/TIMING_RUN=1）得 A2（2 级 CSA + 260 位 carry 状态）增量 **%.1f–%.1f µm²**"
            "（占 L1 fold %.1f µm² 的 %.1f%%–%.1f%%），A4（1 级）%.1f–%.1f µm²；sequential 面积呈 1×/2× 关系"
            "（%.2f µm²/FF）✓。决策：**主方案保持 CPA（A1）**，A2 作消融点；论文若主张 A2 更优须先实现并实测 ✗。 |"
            % (d_lo, d_hi, fold, 100 * d_lo / fold, 100 * d_hi / fold, d4_lo, d4_hi, ff))
        q.write_text("\n".join(lines), encoding="utf-8")
    print(sec)
    print("OK" + (" (check only)" if args.check else ""))


if __name__ == "__main__":
    main()
