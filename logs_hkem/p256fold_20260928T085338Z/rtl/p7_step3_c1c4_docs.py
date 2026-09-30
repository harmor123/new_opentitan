#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""P7 §8.8：Step 3 查 1–4 实测（一次性；带断言）。

追加到 `08_P7_PPA与CSA决策.md` 末尾，并同步 `13_合并影响` 的更新记录一行。
用法：python3 logs_hkem/p256fold_20260928T085338Z/rtl/p7_step3_c1c4_docs.py [--check]
"""
import argparse
import pathlib

REPO = pathlib.Path(__file__).resolve().parents[3]
DOCS = REPO.parent / "md文档" / "p256方案20260927" / "new_contribution_2"

S88 = """### 8.8 Step 3 查 1–4 实测（2026-09-30）

判据逐条来自 §3 Step 3；"网表侧"证据取自最新一次 A1 综合的 yosys 日志
（`syn_out/otbn_core_<ts>/log/syn.log`，19.5 MB）与三份网表面积报告。

| 查 | RTL 侧 | 网表/日志侧 | 结论 |
|---|---|---|---|
| **1. 通用 64×64 乘法器仍为 1 个** | `hw/ip/otbn/rtl/otbn_mac_bignum.sv:367` 唯一一处 `otbn_vec_multiplier u_vec_multiplier`（文档里写的 `:358` 是 P3/P7 编辑前的行号，**已更正**） | 日志里 `module \\`\\otbn_vec_multiplier'` **×1 且无 `$paramod`** ⇒ 设计里只有这一份 | ✓ 未出现第 2 个通用乘法器 |
| **2. 新增 CPA 的实例/位片符合设计** | `otbn_vec_adder` 实例 **3 个**：`otbn_alu_bignum.sv:1037`、`:1076`、`otbn_mac_bignum.sv:490`；**fold 不用它**（`260 % 32 ≠ 0`） | 日志里 `otbn_vec_adder` 只有 **2 种参数化**（`$paramod$4fe5…` 与 `$paramod$70a6…`）⇒ ALU 两条同参数共享一次 elaborate + MAC 一条 = 3 个实例 ✓，**没有第 4 个** | ✓ 与设计一致 |
| **2b. fold 的 CPA 是"一个共享的加/减结构"** | `otbn_p256_fold.sv:266` **唯一一处加法器表达式**：`cpa_ext = {cpa_a[W-1],cpa_a} + {cpa_b[W-1],cpa_b} + {{W{1'b0}}, cpa_sub}`；减法 = 第二输入取反（`~t_n*`）+ 进位输入（`:234` 注释） | L1 面积报告 `XOR2_X1 125 + XNOR2_X1 201 = 326` ≈ 一条 260-bit 进位链的规模（若两条会翻倍） | ✓ 符合 §10.3「明确 carry-in adder、不手写两条 ripple chain」 |
| **3. KD 未被映射成意外通用乘法器** | 12 项 `KD_00…KD_11` 是 `localparam logic [W-1:0]` 常量（`:99-110`），由常量 `case (k)` 选择；`k = −8…−5` 走安全默认 `'0` 并由 `A_k_in_range` 命中 | 查 1 的日志计数已证明设计里只有 1 个通用乘法器 ⇒ KD 路径不可能有乘法器 | ✓ 是 elaboration 常量选择，不是运行时乘法 |
| **4. 无 latch** | — | 三份网表面积报告（A0/B0/L1）**LATCH cell 数 = 0** ✓；日志里 `latch` 提及 **19,749 次**，逐条查看**全部是 `No latch inferred for signal …`**（`PROC_DLATCH` pass 的逐信号**否定**报告，绝大多数来自 `prim_onehot_mux` 的 `in_mux[…]`），**没有一条是 `Latch inferred`** | ✓ 无推断锁存器 |

> ⚠ **读日志时的坑（留档）**：`grep -ci latch …/log/syn.log` 会得到**近 2 万**，看上去像"全是锁存器" ✗ ——
> 那是 `PROC_DLATCH` 逐信号打印的 **"No latch inferred"**。判据一律看**网表的 cell 类型**（面积报告的
> `LATCH` 行）+ 日志里是否存在 `Latch inferred`（**推断出**）字样，而不是提及次数。
> 另一处同类坑：`grep -c "module …X'"` 这种模式会**因为参数化前缀 `$paramod$<hash>\\` 而漏计** ——
> `otbn_vec_adder` 用该模式只数到 2（其实恰好等于"2 种参数化"），而 `otbn_vec_multiplier` /
> `otbn_p256_fold` 数到 0（它们未被参数化、日志里以 `\\` 形式出现）⇒ 计数要用宽松模式并看**唯一参数化数**。
"""


def main():
    p = DOCS / "08_P7_PPA与CSA决策.md"
    t = p.read_text(encoding="utf-8")
    assert "### 8.8 " not in t, "§8.8 已存在"
    if not args.check:
        p.write_text(t.rstrip("\n") + "\n\n" + S88, encoding="utf-8")

    q = DOCS / "13_合并影响与回归清单.md"
    t2 = q.read_text(encoding="utf-8")
    lines = t2.split("\n")
    i = next(k for k, l in enumerate(lines) if l.startswith("| 2026-09-30 | `3560cdf5c2` |"))
    lines.insert(i + 1,
                 "| 2026-09-30 | `e4b1c9d711` | **P7 Step 3 查 1–4 实测（全部通过）**。① 通用 64×64 乘法器"
                 "**仍为 1 个**（`otbn_mac_bignum.sv:367`；日志 `\\otbn_vec_multiplier'` ×1、无 `$paramod`）；"
                 "② `otbn_vec_adder` **3 实例 = 2 种参数化**（ALU 2 + MAC 1，无第 4 个），且 fold 的 CPA 是"
                 "**唯一一处**加法器表达式（`otbn_p256_fold.sv:266`，减法用取反 + carry-in）；"
                 "③ KD 是 12 项 `localparam` 常量 + 常量 `case`，不是运行时乘法；④ 三份网表 **LATCH cell = 0**，"
                 "日志里 19,749 次 `latch` 提及**全是** `No latch inferred`（`PROC_DLATCH` 逐信号否定报告）。"
                 "**顺带更正**：文档 Step 3 查 1 的位置 `:358` 已陈旧（现 `:367`）。见 `08_P7_*.md` §8.8。 |")
    if not args.check:
        q.write_text("\n".join(lines), encoding="utf-8")
    print("OK" + (" (check only)" if args.check else ""))


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()
    main()
