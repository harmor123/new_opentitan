#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""P7 §8.13.1 的表 A-1 / 表 A-2 就地更新（数值随 2026-09-30 的两次解析修正而变）+ §8.13.7 的 13 行。

为什么单独一个脚本：§8.13.1 原由 `p7_step9_docs.py` 生成（它带"§8.13 已存在"的护栏，不能重跑），
而修正后的数值在 §8.13.7 里已经写了 ⇒ 必须把 §8.13.1 的表也换掉，否则同一文档里两处数字互相矛盾 ✗。

**旧值从 git 历史读**（`git show 9b78d6a881:…p7_energy_*.md`），新值从现行报告读 ⇒ 一个数都不手写；
替换前断言旧字面量在文档里**恰好出现一次**（否则拒绝写）。

用法：python3 logs_hkem/p256fold_20260928T085338Z/rtl/p7_step9_1_fix.py [--check] [--docs-dir DIR]
"""
import argparse
import pathlib
import re
import subprocess
import sys

for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

REPO = pathlib.Path(__file__).resolve().parents[3]
DOCS = REPO.parent / "md文档" / "p256方案20260927" / "new_contribution_2"
DOC = "08_P7_PPA与CSA决策.md"
R = REPO / "logs_hkem/p256fold_20260928T085338Z/reports"
OLD_COMMIT = "9b78d6a881"          # 修正前的报告（路 A 首次入库）
POW = re.compile(r"^\| (0\.\d\d) \| ([\d.]+) mW \| ([\d.]+) mW \| ([\d.]+) mW \| \*\*([\d.]+) mW\*\* \|", re.M)
EN = re.compile(r"\| \*\*energy/(\w+)\*\*[^|]*\| (\d+)（([^|]*)） \| (.+?) \|\s*$", re.M)
ALPHAS = ("0.10", "0.25", "0.50")


def report(text, name):
    rows = {m.group(1): (float(m.group(2)), float(m.group(3)), float(m.group(4)), float(m.group(5)))
            for m in POW.finditer(text)}
    assert set(rows) == set(ALPHAS), (name, list(rows))
    en = {m.group(1): [x.strip() for x in m.group(4).split("|")] for m in EN.finditer(text)}
    return rows, en


def load(name, commit=None):
    if commit:
        r = subprocess.run(["git", "show", "%s:logs_hkem/p256fold_20260928T085338Z/reports/p7_energy_%s.md"
                            % (commit, name)], capture_output=True, text=True, encoding="utf-8", cwd=str(REPO))
        assert r.returncode == 0, "git show 失败：%s %s" % (commit, name)
        return report(r.stdout, name)
    return report((R / ("p7_energy_%s.md" % name)).read_text(encoding="utf-8", errors="replace"), name)


def tool_val(i):
    """工具报告 Total 行的第 i 个分量（1=Internal, 2=Switching, 3=Leakage）—— 从文件读，不手写。"""
    f = R / "p7_sta_power_otbn_p256_fold_a0.10.rpt"
    m = re.search(r"^Total\s+([\d.eE+-]+)\s+([\d.eE+-]+)\s+([\d.eE+-]+)", f.read_text(encoding="utf-8", errors="replace"), re.M)
    assert m, "工具报告里没解析到 Total 行"
    return float(m.group(i))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--docs-dir")
    args = ap.parse_args()
    global DOCS
    if args.docs_dir:
        DOCS = pathlib.Path(args.docs_dir)

    p = DOCS / DOC
    assert p.exists(), "找不到 %s（本脚本是 Windows 侧工具；确需在别处生成用 --docs-dir）" % p
    t = p.read_text(encoding="utf-8")

    reps = []
    # 表 A-1：每个设计一行，三档 α 的 "P_sw / P_int / P_leak / **P_total mW**"
    for k in ("L1", "A0", "A1", "B0"):
        o, _ = load(k, OLD_COMMIT)
        n, _ = load(k)
        cell = lambda rows, a: "%.4f / %.4f / %.4f / **%.4f mW**" % rows[a]
        old = " | ".join(cell(o, a) for a in ALPHAS)
        new = " | ".join(cell(n, a) for a in ALPHAS)
        reps.append((old, new, "表 A-1 %s" % k))
    # 表 A-2：能量行的三档数值
    for k, kind in (("L1", "mul"), ("A0", "ECDH"), ("A1", "ECDH")):
        _, oe = load(k, OLD_COMMIT)
        _, ne = load(k)
        old = " | ".join(oe[kind])
        new = " | ".join(ne[kind])
        reps.append((old, new, "表 A-2 %s" % k))

    for old, new, what in reps:
        c = t.count(old)
        if c == 0 and t.count(new) == 1:
            print("已是最新：%s" % what)
            continue
        assert c == 1, ("%s：旧字面量在文档里出现 %d 次（期望 1）" % (what, c), old[:60])
        t = t.replace(old, new, 1)
        print("更新：%s" % what)

    # 在表 A-1 标题下加一条"已更新"的说明（幂等）
    anchor = "**表 A-1：四个设计的功耗**（V=1.10 V、f=125 MHz、Nangate45 typical、α 为**声明式假设**、ICG=0）"
    note = (anchor + "\n\n> 表中数值已按 **2026-09-30** 的两次解析修正更新（旧值 0.6195 / 1.5323 mW 等"
            "见 §8.13.7 乙的审计线：`git show 9b78d6a881`）；修正依据与两工具互证见 §8.13.7。")
    if t.count(note) == 1:
        pass
    else:
        assert t.count(anchor) == 1, "表 A-1 标题未找到"
        t = t.replace(anchor, note, 1)
        print("已加注：表 A-1")

    # 13 行（§8.13.7）
    q = DOCS / "13_合并影响与回归清单.md"
    assert q.exists(), q
    t2 = q.read_text(encoding="utf-8")
    row_start = "| 2026-09-30 | `ac2771ba43` | **P7 Step 9 两工具互证"
    if row_start in t2:
        print("13 行已存在")
    else:
        lines = t2.split("\n")
        i = next(k for k, l in enumerate(lines) if l.startswith("| 2026-09-30 | `670b43ffb3` |"))
        cur = load("L1")[0]["0.10"]                       # (sw, int, leak, tot) mW
        p0 = load("L1", OLD_COMMIT)[0]["0.10"][1]
        p1 = load("L1", "b62bb16c5e")[0]["0.10"][1]
        ti, ts, tl = tool_val(1), tool_val(2), tool_val(3)
        lines.insert(
            i + 1,
            "| 2026-09-30 | `ac2771ba43` | **P7 Step 9 两工具互证（P7 §8.13.7）**。同一 liberty / 同一 `.sta.v` "
            "网表 / 同一 α 下用 OpenSTA 2.0.17 的 `report_power` 校解析式估计：**内部功耗差 %.1f%%**"
            "（%.4f ↔ %.4f mW）、**漏电差 %.1f%%**（三个 α 档一致）、开关差 %.2f×（口径差：平坦 α 是上界）；"
            "单位「W」与标度「1 fJ/单位」由该吻合反证坐实。**两次解析修正的审计线**：`timing` 延时值混入"
            "（×%.2f）→ 多组拉平取中位（×%.2f），修后与工具差 %.1f%%。**A0/A1/B0 上 `report_power` 段错误**"
            "（规模相关；`ulimit`/去掉活动率标注均无效；本机无更新版工具）⇒ 三设计走同一库常数标度的解析式。 |"
            % (100 * (cur[1] / ti - 1), cur[1], ti * 1e3, 100 * abs(cur[2] / tl - 1), cur[0] / ts,
               p1 / p0, cur[1] / p1, 100 * (cur[1] / ti - 1)))
        t2 = "\n".join(lines)
        print("13 行已加")

    if not args.check:
        p.write_text(t, encoding="utf-8")
        q.write_text(t2, encoding="utf-8")
    print("OK" + (" (check only)" if args.check else ""))


if __name__ == "__main__":
    main()
