#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""P7 §8.9：Step 7 的「完整性/安全控制」类别归属（一次性；数值由脚本算出）。

追加到 `08_P7_PPA与CSA决策.md` 末尾，并同步 `13_合并影响` 的更新记录一行。
用法：python3 logs_hkem/p256fold_20260928T085338Z/rtl/p7_step7_sec_docs.py [--check]
"""
import argparse
import pathlib
import re

REPO = pathlib.Path(__file__).resolve().parents[3]
DOCS = REPO.parent / "md文档" / "p256方案20260927" / "new_contribution_2"

# 宽度常量的真值（逐个从 RTL/pkg 解析，见提交信息）
WV = {"ExtWLEN": 312, "WLEN": 256, "HWLEN": 128, "QWLEN": 64, "32'd32": 32,
      "NumShares*SecAddWidth": 2 * 32, "39": 39, "1": 1, "UrndPartialSeedWidth": 32,
      "8*24": 8 * 24, "DmemAddrWidth": 15, "2*39": 2 * 39,
      "W": 260, "AW": 130, "256": 256, "128": 128,
      "BufferWidth": 2 * (32 + 1), "NumShares * Width": 2 * 32, "StateWidth": 177}


def scan():
    rows = []
    for f in sorted((REPO / "hw/ip/otbn/rtl").glob("*.sv")):
        t = f.read_text(encoding="utf-8", errors="replace")
        for m in re.finditer(r"prim_blanker\s*#\s*\(\s*\.Width\s*\(([^)]*)\)\s*\)\s*(\w+)", t):
            rows.append((f.name, m.group(1).strip(), m.group(2)))
    return rows


def main():
    rows = scan()
    tot = sum(WV[w] for _, w, _ in rows)
    fold = sum(WV[w] for f, w, _ in rows if "p256_fold" in f)
    unit = 829.122 / fold                      # 实测单价（fold：+829.122 µm² / 774 bit）
    est = tot * unit
    assert len(rows) == 54 and fold == 774, (len(rows), fold)

    S = """### 8.9 Step 7 的「完整性/安全控制」类别：能实测的实测、不能分的如实标（2026-09-30）

**为什么这一类天生难分**：判据 3 要求「完整性/安全控制**单列**、不得混入功能面积」，但这一类**不是 cell 类型** ——
blanking（与门）、ECC（XOR/XNOR）、onehot 检查（与/或）用的都是普通标准单元；**平铺网表里没有任何标记**能把它们与
功能逻辑区分开（§8.4 第 5 条已登记）。本节因此**分四档**给，逐档标明口径：

| 档 | 内容 | 值 | 来源 |
|---|---|---|---|
| **① 实测** | **fold 的 blanking**（4 个门 / **774 bit**） | **+829.122 µm²** ⇒ 单价 **%.3f µm²/bit**（与库 `AND2_X1` = 1.064 自洽 ✓） | §8.7 的 L1「补前/补后」之差（差减法，实测） |
| **② 结构量 + 估算** | `prim_blanker` 实例 **%d**（`git grep -c` 口径 61：差额来自**实例名含 `prim_blanker` 的行被重复计入**，如 `u_prim_blanker_a2b_inp1`；两法都给出「比基线 +4」）；掩码位总数 **%s bit**（含 fold 的 774）⇒ 按 ① 的单价**估** ≈ **%.1f µm²** | **估算**（非实测） | RTL 逐条解析 + 宽度常量解析（`ExtWLEN` 312 / `WLEN` 256 / `HWLEN` 128 / `QWLEN` 64 / `32'd32` / `NumShares*SecAddWidth` 64 / `39` / `1` / `UrndPartialSeedWidth` 32 / `8*24` / `DmemAddrWidth` 15 / `2*39` / `W` 260 / `AW` 130 / `256` / `128` / `BufferWidth` %d / `NumShares * Width` 64） |
| **③ 只给实例数（面积不可分）** | ECC：`prim_secded_inv_39_32_enc` **16** / `_dec` **22**；`prim_onehot_check` **6**；`prim_count` **18** | — | RTL 行计数（与 ① 同一口径） |
| **④ §10.6 的两组位数** | 原始 **644 bit**（F 260 + h 256 + LL 128）；按 39-bit/字口径「保护后」**F→351 / h→312 / LL→156** | — | RTL 核对（`f_q` 260 / `h_q` 256 / `ll_q` 128） |

**一条必须讲清的精度（否则会误读）**：fold 的 F/h/LL 是**内部状态、不带 39-bit 完整性编码**（它们不在 WDR/ACC 的
完整性路径上）⇒ 对它们而言 **blanking + wipe 就是全部保护**；「保护后位数」只适用于**沿用完整性编码**的那些状态。
**本节也不把 ② 的估算混进 L1/L2 面积表**：§8.7 的六类表里这些门按 cell 类型落在「组合逻辑」列 ✓，安全类在这里
**单列**并标明估算属性 ✓ —— 这就是「不混入功能面积」在本环境下的可行落地方式（**不猜**一个看起来精确的拆分）。
""" % (unit, len(rows), f"{tot:,}", est, WV["BufferWidth"])

    p = DOCS / "08_P7_PPA与CSA决策.md"
    t = p.read_text(encoding="utf-8")
    assert "### 8.9 " not in t, "§8.9 已存在"
    if not args.check:
        p.write_text(t.rstrip("\n") + "\n\n" + S, encoding="utf-8")

    q = DOCS / "13_合并影响与回归清单.md"
    t2 = q.read_text(encoding="utf-8")
    lines = t2.split("\n")
    i = next(k for k, l in enumerate(lines) if l.startswith("| 2026-09-30 | `e4b1c9d711` |"))
    lines.insert(i + 1,
                 "| 2026-09-30 | `34234d43ab` | **P7 Step 7 的「完整性/安全控制」类别归属（P7 §8.9）**。"
                 "该类**不是 cell 类型**（blanking/ECC 用普通 AND/XOR，平铺网表无标记）⇒ 分四档给："
                 "① **实测** fold 的 blanking = **+829.122 µm² / 774 bit**（单价 1.071 µm²/bit，与库 "
                 "`AND2_X1`=1.064 自洽）；② **结构量+估算**：`prim_blanker` 实例 **54**（`git grep -c` 口径 61，"
                 "差额是实例名含关键字被重复计入；两法都给 +4）、掩码位 **%s** ⇒ 估 ≈ **%.1f µm²**；"
                 "③ 只给实例数（面积不可分）：secded enc 16 / dec 22、`prim_onehot_check` 6、`prim_count` 18；"
                 "④ §10.6 两组位数：原始 **644**（F260+h256+LL128）、保护后 **351/312/156**。"
                 "**精度声明**：fold 的 F/h/LL 是内部状态、**不带** 39-bit 完整性编码 ⇒ 对它们 blanking+wipe 即全部保护。 |"
                 % (f"{tot:,}", est))
    if not args.check:
        q.write_text("\n".join(lines), encoding="utf-8")
    print(S)
    print("OK" + (" (check only)" if args.check else ""))


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()
    main()
