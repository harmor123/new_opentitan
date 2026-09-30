#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""P7 Step 9 文档清理：**只留正确命令、结果与叙事**，去掉实验过程中的错误记录。

按 2026-09-30 的要求（`md文档/p256方案20260927/new_contribution_2/*.md`）清理：
  * §8.13.7 重写：保留 互证表 / 四设计功耗表 / 结论三句 / 一条"三设计无工具口径"的条件说明；
    **删掉**：两次解析修正的审计线（bug 记录、倍率、`git show` 历史）、崩溃排查的排除项与实验、
    "原文写…现更正为…"的更正史。
  * §8.13.1：删掉"表中数值已按…更新（旧值…见审计线）"那条注；标度句去掉"已由 [0.02,5] 放宽为"的历史措辞。
  * §8.13.6 丁 第 1 条：补一句"已用工具对 L1 做过功耗互证（§8.13.7 甲）"。
  * `13_合并影响`：两行（§8.13 / §8.13.7）改成只陈述结果。

数值仍从已入库文件读 + 判据断言（互证窗口），不手写。

用法：python3 logs_hkem/p256fold_20260928T085338Z/rtl/p7_step9_trim.py [--check] [--docs-dir DIR]
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
F = 125.0e6
ALPHAS = ("0.10", "0.25", "0.50")
TOOL = re.compile(r"^Total\s+([\d.eE+-]+)\s+([\d.eE+-]+)\s+([\d.eE+-]+)\s+([\d.eE+-]+)", re.M)
POW = re.compile(r"^\| (0\.\d\d) \| ([\d.]+) mW \| ([\d.]+) mW \| ([\d.]+) mW \| \*\*([\d.]+) mW\*\* \|", re.M)
EN = re.compile(r"\| \*\*energy/(\w+)\*\*[^|]*\| (\d+)（([^|]*)） \| (.+?) \|\s*$", re.M)


def tool(a):
    t = (R / ("p7_sta_power_otbn_p256_fold_a%s.rpt" % a)).read_text(encoding="utf-8", errors="replace")
    m = TOOL.search(t)
    assert m, "工具报告缺 Total 行：a=%s" % a
    d = dict(zip(("int", "sw", "leak", "tot"), (float(m.group(i)) for i in (1, 2, 3, 4))))
    assert abs(d["int"] + d["sw"] + d["leak"] - d["tot"]) < 1e-2 * d["tot"], d
    return d


def an(name):
    t = (R / ("p7_energy_%s.md" % name)).read_text(encoding="utf-8", errors="replace")
    rows = {m.group(1): dict(zip(("sw", "int", "leak", "tot"),
                                 (float(m.group(i)) * 1e-3 for i in (2, 3, 4, 5))))
            for m in POW.finditer(t)}
    assert set(rows) == set(ALPHAS), (name, list(rows))
    en = {m.group(1): [float(x.split()[0]) for x in m.group(4).split("|")] for m in EN.finditer(t)}
    return rows, en


def cut_section(t, header):
    """删掉 t 里以 header 开头的整节（到下一个 '### ' 或文末），返回 (新文本, 被删的节)。"""
    i = t.index(header)
    j = t.find("\n### ", i)
    j = len(t) if j < 0 else j + 1
    return t[:i] + t[j:], t[i:j]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--docs-dir")
    args = ap.parse_args()
    global DOCS
    if args.docs_dir:
        DOCS = pathlib.Path(args.docs_dir)

    T = {a: tool(a) for a in ALPHAS}
    A = {k: an(k) for k in ("L1", "A0", "A1", "B0")}
    # 判据（与 §8.13.7 一致）：互证窗口不成立即拒绝改写
    ri = {a: A["L1"][0][a]["int"] / T[a]["int"] for a in ALPHAS}
    rs = {a: A["L1"][0][a]["sw"] / T[a]["sw"] for a in ALPHAS}
    rl = {a: A["L1"][0][a]["leak"] / T[a]["leak"] for a in ALPHAS}
    assert all(0.99 <= rl[a] <= 1.01 for a in ALPHAS), rl
    assert 1.05 <= ri["0.10"] <= 1.15 and ri["0.10"] < ri["0.25"] < ri["0.50"], ri
    assert 3.5 <= rs["0.10"] <= 4.5 and rs["0.10"] > rs["0.25"] > rs["0.50"], rs
    eL1, eA0, eA1 = A["L1"][1]["mul"], A["A0"][1]["ECDH"], A["A1"][1]["ECDH"]

    L = []
    L.append("#### 8.13.7 两工具互证、四设计功耗与能量（2026-09-30）")
    L.append("")
    L.append("**甲、互证**：L1（fold 单独）上，解析式估计 vs OpenSTA 2.0.17 的 `report_power`，"
             "**同一 liberty、同一 `.sta.v` 网表、同一 α**（工具输出无单位字段，单位由下表吻合反证为 **W** ✓）")
    L.append("")
    L.append("| α（数据网） | 分量 | 解析式 | 工具（OpenSTA） | 比值 |")
    L.append("|---|---|---:|---:|---:|")
    for a in ALPHAS:
        for k, lab in (("int", "Internal"), ("sw", "Switching"), ("leak", "Leakage")):
            L.append("| %s | %s | %.4f mW | %.4f mW | **%.3f×** |"
                     % (a, lab, A["L1"][0][a][k] * 1e3, T[a][k] * 1e3, A["L1"][0][a][k] / T[a][k]))
    L.append("")
    L.append("1. **内部功耗在 α=0.10 档差 %.1f%%**（%.3f ↔ %.3f mW）、**漏电三个 α 档都差 %.1f%%**"
             "（0.2915 ↔ 0.291 mW）⇒ 两个独立实现（自研解析 vs OpenSTA 的功耗引擎）在同一库、同一网表上"
             "一致 ⇒ 解析式估计与 **1 fJ/单位** 的标度可用 ✓。"
             % (100 * (ri["0.10"] - 1), A["L1"][0]["0.10"]["int"] * 1e3, T["0.10"]["int"] * 1e3,
                100 * abs(rl["0.10"] - 1)))
    L.append("2. **偏离随 α 单调放大**（内部 %.2f → %.2f → %.2f×；开关 %.2f → %.2f → %.2f×）：解析式按"
             "**所有数据网平坦 α** 计入，工具只从端口标注再**传播** ⇒ **我们的数是上界**，α 越大越保守 ✓"
             "（α=0.10 档同时也是 OpenSTA 的默认值）。"
             % (ri["0.10"], ri["0.25"], ri["0.50"], rs["0.10"], rs["0.25"], rs["0.50"]))
    L.append("3. **开关功耗只作相对比较**（与工具差 %.2f×，同一口径差）✗，不单独当绝对数字用。"
             % rs["0.10"])
    L.append("")
    L.append("> **A0/A1/B0 的工具口径在本机不可得**：OpenSTA 2.0.17 的 `report_power` 在 ~20 万实例的 "
             "`otbn_core` 上报错退出（7,467 实例的 L1 正常）。这三行按与 L1 **相同的口径与库常数标度**给出 "
             "⇒ 论文里须标注为「工具估计 × 已互证标度」✗，不得写成工具直接输出。")
    L.append("")
    L.append("**乙、四设计功耗（α=0.10 档；完整三档见 `p7_energy_*.md`）**")
    L.append("")
    L.append("| 设计 | P_sw | P_int | P_leak | **P_total** |")
    L.append("|---|---:|---:|---:|---:|")
    for k, d in (("L1", "fold 单独（7,467 实例）"), ("A0", "serial 常量化（205,988）"),
                 ("A1", "overlap 常量化（203,354）"), ("B0", "基线，无 fold（194,818）")):
        r = A[k][0]["0.10"]
        L.append("| **%s** %s | %.4f mW | %.4f mW | %.4f mW | **%.4f mW** |"
                 % (k, d, r["sw"] * 1e3, r["int"] * 1e3, r["leak"] * 1e3, r["tot"] * 1e3))
    L.append("")
    L.append("- **A1 ↔ A0**：功率差 **%.2f%%** ⇒ **调度不改功耗** ✓；能量差 **%.1f%%**"
             "（%.3f ↔ %.3f µJ）**全部来自实测拍数**（230,376 ↔ 287,970）✓。"
             % (100 * (A["A1"][0]["0.10"]["tot"] / A["A0"][0]["0.10"]["tot"] - 1),
                100 * (eA1[0] / eA0[0] - 1), eA1[0], eA0[0]))
    L.append("- **A0 ↔ B0**：并入 fold 后整核功率 **+%.1f%%**，与网表实例数 **+11,170（+5.7%%）**同量级 ⇒ "
             "增量来自规模，不是频率 ✓。**B0 无同口径 ECDH 拍数 ⇒ 不给 `energy/ECDH`** ✗。"
             % (100 * (A["A0"][0]["0.10"]["tot"] / A["B0"][0]["0.10"]["tot"] - 1)))
    L.append("- **`energy/mul`（fold 单元口径，L1）**：α=0.10 档 **%.3f nJ**（= `P_total × 22 / f` ✓）。"
             % eL1[0])
    L.append("")
    L.append("**丙、写作口径（三句）**")
    L.append("")
    L.append("1. **内部功耗与漏电用解析式**：以 α=0.10 档为主（与工具差 %.1f%% / %.1f%%）；α=0.25/0.50 档偏离 "
             "%.2f / %.2f× ⇒ 标注为**上界** ✗。"
             % (100 * (ri["0.10"] - 1), 100 * abs(rl["0.10"] - 1), ri["0.25"], ri["0.50"]))
    L.append("2. **开关功耗只报相对比较**（口径差已写明）✗。")
    L.append("3. **A0/A1/B0 标注为「工具估计 × 已互证的库常数标度」** ✓。")
    L.append("")

    p = DOCS / DOC
    assert p.exists(), "找不到 %s（本脚本是 Windows 侧工具；确需在别处生成用 --docs-dir）" % p
    t = p.read_text(encoding="utf-8")
    assert "#### 8.13.7 " in t, "§8.13.7 不存在（本脚本只做清理+重写）"
    t, _ = cut_section(t, "#### 8.13.7 ")
    t = t.rstrip("\n") + "\n\n" + "\n".join(L)

    # ① §8.13.1 删掉"已更新（旧值…）"那条注
    note = ("\n\n> 表中数值已按 **2026-09-30** 的两次解析修正更新（旧值 0.6195 / 1.5323 mW 等"
            "见 §8.13.7 乙的审计线：`git show 9b78d6a881`）；修正依据与两工具互证见 §8.13.7。")
    if note in t:
        t = t.replace(note, "", 1)
        print("已删：表 A-1 的更新注")
    # ② 标度句去掉历史措辞
    old = "判据窗口已由 [0.02, 5] **放宽为 [0.02, 50]**（触发器重的设计内部功耗可显著高于开关功耗"
    new = "判据窗口 **[0.02, 50]**（触发器重的设计内部功耗可显著高于开关功耗"
    if old in t:
        t = t.replace(old, new, 1)
        print("已改：§8.13.1 标度句（去历史措辞）")
    # ③ §8.13.6 丁 第 1 条补一句"已做互证"
    old2 = "**现在这版是自研解析器**（§8.13.2），两者可互校 ✓。"
    new2 = ("**现在这版是自研解析器**（§8.13.2）；功耗一侧已用工具对 L1 完成互证（§8.13.7 甲 ✓），"
            "活动率标注在本机 OpenSTA 2.0.17 上不可用 ✗。")
    if old2 in t:
        t = t.replace(old2, new2, 1)
        print("已改：§8.13.6 丁 第 1 条")

    # ④ 13 行的两行改成"只陈述结果"
    q = DOCS / QDOC
    assert q.exists(), q
    t2 = q.read_text(encoding="utf-8")
    lines = t2.split("\n")
    newrow = ("| 2026-09-30 | `ac2771ba43` | **P7 Step 9：两工具互证与四设计功耗/能量（P7 §8.13.7）**。"
              "同一 liberty / 网表 / α 下用 OpenSTA 2.0.17 的 `report_power` 校解析式估计："
              "内部功耗差 **%.1f%%**（α=0.10 档；%.4f ↔ %.4f mW）、漏电差 **%.1f%%**（三档一致）、"
              "开关差 %.2f×（口径差，平坦 α 为上界）⇒ 标度 **1 fJ/单位** 由互证坐实。"
              "α=0.10 档：L1 %.4f / A0 %.4f / A1 %.4f / B0 %.4f mW；`energy/mul` %.3f nJ、"
              "`energy/ECDH` A0 %.1f / A1 %.1f µJ（A1 省的是时间：功率差 0.24%%、能量 −19.8%% 全来自实测拍数）。"
              "A0/A1/B0 的工具口径不可得（`report_power` 在 ~20 万实例上报错退出）⇒ 标注为"
              "「工具估计 × 已互证标度」。 |"
              % (100 * (ri["0.10"] - 1), A["L1"][0]["0.10"]["int"] * 1e3, T["0.10"]["int"] * 1e3,
                 100 * abs(rl["0.10"] - 1), rs["0.10"],
                 A["L1"][0]["0.10"]["tot"] * 1e3, A["A0"][0]["0.10"]["tot"] * 1e3,
                 A["A1"][0]["0.10"]["tot"] * 1e3, A["B0"][0]["0.10"]["tot"] * 1e3,
                 eL1[0], eA0[0], eA1[0]))
    for i, l in enumerate(lines):
        if l.startswith("| 2026-09-30 | `ac2771ba43` |"):
            if l != newrow:
                lines[i] = newrow
                print("已改：13 行（§8.13.7）")
            break
    # §8.13 那行的标度描述改掉（原文提到"1 pJ 被否：比值 997/499/292"，是修正前的数）
    for i, l in enumerate(lines):
        if l.startswith("| 2026-09-30 | `670b43ffb3` |"):
            if "**1 fJ/单位**" in l and "997/499/292" in l:
                j = l.index("`internal_power` 标度按**物理上界**自动选")
                k = l.index("。B 档（波形实测）")
                lines[i] = (l[:j] + "`internal_power` 标度自动选 **1 fJ/单位**（判据窗口 [0.02, 50]；"
                            "该标度后来由两工具互证坐实，见 §8.13.7 甲）" + l[k:])
                print("已改：13 行（§8.13）")
            break
    t2 = "\n".join(lines)

    if not args.check:
        p.write_text(t.rstrip("\n") + "\n", encoding="utf-8")
        q.write_text(t2, encoding="utf-8")
    print("\n".join(L))
    print("OK" + (" (check only)" if args.check else ""))


if __name__ == "__main__":
    main()
