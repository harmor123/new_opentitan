#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""P7 Step 3 查 5（blanking 缺件）的文档更新（一次性；带断言）。

改两个文件：
  08_P7_PPA与CSA决策.md   —— 新增 §8.6（发现 + 修复 + 计数 57→61 + 回归）；给 §8.2 的面积数加"补
                             blanking 之前"的标注（那一节即将被 §8.7 的新数取代）
  13_合并影响与回归清单.md —— §3 第 1 行补 blanking；更新记录加一行

用法：python3 logs_hkem/p256fold_20260928T085338Z/rtl/p7_step3_docs.py [--check]
"""
import argparse
import pathlib

DOCS = (pathlib.Path(__file__).resolve().parents[4] / "md文档"
        / "p256方案20260927" / "new_contribution_2")

S86 = """### 8.6 Step 3 查 5 的发现与修复：fold 新状态缺 blanking（2026-09-30）

**发现（实测）**：`prim_blanker` 实例计数 **基线 57 → 本分支（修复前）仍 57**，而 §3 Step 3 查 5 明令
「新增 Fold 状态后这个数字**必须增加**（F/h/LL 的清理），**不增加即为遗漏**」；PDF §10.6 要求
「F(260)/h(256)/LL(128) 共 **644 bit 全量进入 blanking 与 wipe**」，且「**清零 ≠ 侧信道安全**」。
修复前我们**只有 wipe 清零**（`if (abort_i || wipe_i)` 把 `f_d/h_d/ll_d/acc130_d` 置 0 —— 功能性、
综合器拆不掉），**没有 blanking**：`h_q` 直接拼出 `v_a/v_b/v_p0/v_p1/v_m0…v_m3` 送 CPA、`f_q` 直接
读成 `k_c19`、`f_o/h_o/ll_o/acc130_o` 直赋 ⇒ **空闲期这些线上仍带 F/h/LL 的真值**。

**修复**（`otbn_p256_fold.sv`，4 个 `prim_blanker`，与全库其余 57 处同构）：**只掩消费路径** ——
寄存器自身的保持路径（`f_d = f_q` 等）与 DV 路径（`f_o/h_o/ll_o`、`P256EV` 事件流）继续用原值，
掩了会自清状态、或改动设备侧证据。

| blanker | 宽度 | en（= 该状态**真被消费**的相位） | 依据（逐个从 RTL 读出，不是猜） |
|---|---:|---|---|
| `u_blank_f` | 260 | `busy_q && phase ≥ 10` | `cpa_a` 的默认值就是 F（10…18 的 F←F+t_*）；19 的 x 与 `k_c19`；20 的 ±p 符号；21 的写回 |
| `u_blank_h` | 256 | `busy_q && 10 ≤ phase ≤ 17` | 八个 row addend `t_2a/2b/p0/p1/n0…n3` 由 `v_*`（源 `h_q`）拼出 |
| `u_blank_ll` | 128 | `busy_q && phase == 18` | `t_l0 = {ACC[129:0], LL[127:0]}`（`A_L0_no_truncate` 的守卫同为 phase 18） |
| `u_blank_acc130` | 130 | `busy_q && phase == 18` | 同上 |

另加 **6 条不变量断言**：`A_{f,h,l0}_blanked_idle`（未使能必须为 0）与 `A_{f,h,l0}_blanked_pass`
（使能必须透传）。**修复后计数：57 → 61**（`otbn_p256_fold.sv` +4）。

**修复后回归（全部实测）**：

| 检查 | 判据 | 结果 |
|---|---|---|
| 单元级纯 py 预检（`p3_fold_emul.py --fuzz 80`） | mismatches 0 | 21×2 向量 + 80 fuzz ⇒ **0** ✓ |
| P2 单元 TB | `PASS - 0 errors / 1114 checks` | ✓ |
| P3 双调度单元 TB | `PASS - 0 errors / 2000 checks`（含 `mode_switch_no_stale`） | ✓ |
| 6 条新断言的相位分析 | 一条未报 ⇒ `en` 相位**既没写宽也没写窄** | ✓ |
| co-sim（fold / mixed，各两档） | 金标**逐字节不变** | **待跑**（RTL 改动后必须复跑；见 §8.7） |
| chip 锚点（`test_p256_only_sim_verilator`） | `PASS!` + 四个指令数逐位不变 + `P256EV` 五列形态分布不变 | 见 §8.7 |

> **`u_size_only_*` 的层级**：它是**网表层**命名（`hw/ip/prim/README.md:388`；`syn/constraints.sdc:50`
> 的 `set_size_only -all_instances [get_cells -h *u_size_only*]`）。本机 yosys 流**不读 SDC** ⇒ 该保护
> 在本阶段的综合里不可见；但按惯例用 `prim_blanker` 才能让真实（DC）流把它纳入保护集 —— 这正是
> 「按 OTBN 惯例写」而不是「自定义命名」的理由。

"""


def read(p):
    return p.read_text(encoding="utf-8")


def write(p, s):
    p.write_text(s, encoding="utf-8")


def line_index(lines, prefix, what):
    idx = [i for i, l in enumerate(lines) if l.startswith(prefix)]
    assert len(idx) == 1, "%s：期望 1 行，实际 %d 行" % (what, len(idx))
    return idx[0]


def patch_08():
    p = DOCS / "08_P7_PPA与CSA决策.md"
    t = read(p)
    orig = t

    # ① 给 §8.2 的面积数加"补 blanking 之前"的标注
    old = "### 8.2 Step 1：四组综合（同一 flow、同一冻结条件）\n"
    assert t.count(old) == 1
    t = t.replace(old, old + "\n> ⚠ **口径**：本小节四组面积是**补 blanking 之前**（`543d39dc19` 之前）的数；\n"
                             "> 补完后重测的数值见 §8.7（Step 3 查 5 修复后重跑）。\n", 1)

    # ② 追加 §8.6
    t = t.rstrip("\n") + "\n\n" + S86
    assert t != orig
    if not args.check:
        write(p, t)
    return p, len(orig.split("\n")), len(t.split("\n"))


def patch_13():
    p = DOCS / "13_合并影响与回归清单.md"
    t = read(p)
    orig = t

    lines = t.split("\n")
    i = line_index(lines, "| 1 | `hw/ip/otbn/rtl/otbn_p256_fold.sv`", "13/第 1 行")
    assert lines[i].endswith(" |")
    lines[i] = lines[i][:-2] + (
        "；**P7 新增 blanking**：4 个 `prim_blanker`（F/h/LL/ACC130，只掩消费路径）+ 6 条不变量断言 "
        "⇒ `prim_blanker` 计数 **57 → 61**（§3 Step 3 查 5 的判据） |")
    t = "\n".join(lines)

    lines = t.split("\n")
    i = line_index(lines, "| 2026-09-30 | `8f8210dccc` |", "13/更新记录锚点")
    lines.insert(i + 1,
                 "| 2026-09-30 | `543d39dc19` | **P7 Step 3 查 5 命中并修复：fold 新状态缺 blanking**。"
                 "**发现**：`prim_blanker` 计数基线 57 → 本分支仍 **57**，而 §3 Step 3 查 5 明令"
                 "「新增 Fold 状态后必须增加，不增加即为遗漏」；PDF §10.6 要求 F/h/LL **644 bit 全量进入 "
                 "blanking 与 wipe**，且「清零 ≠ 侧信道安全」—— 修复前只有 wipe 清零、**没有 blanking**"
                 "（`h_q` 直拼 `v_*` 送 CPA、`f_q` 直读 `k_c19`、`f_o/h_o/ll_o` 直赋）。**修复**：4 个 "
                 "`prim_blanker`（与全库其余 57 处同构），`en` 取「该状态真被消费的相位」（F：`phase≥10`；"
                 "h：`10≤phase≤17`；LL/ACC130：`phase==18`），**保持路径与 DV/事件流用原值**"
                 "（掩了会自清状态或改动 `P256EV` 证据）；另加 6 条不变量断言。计数 **57 → 61**。"
                 "**已实测**：纯 py 预检 mismatches 0（42 向量 + 80 fuzz）、P2 TB `1114 checks`、"
                 "P3 TB `2000 checks`（含 `mode_switch_no_stale`）。**待跑**：co-sim（fold/mixed 两档）、"
                 "smoke、chip 锚点、四组综合重跑（面积会变）。"
                 "**层级澄清**：`u_size_only_*` 是网表层命名（`prim/README.md:388` + `set_size_only`），"
                 "本机 yosys 流不读 SDC ⇒ 按惯例用 `prim_blanker` 才能让真实 DC 流保护到它。 |")
    t = "\n".join(lines)

    assert t != orig
    if not args.check:
        write(p, t)
    return p, len(orig.split("\n")), len(t.split("\n"))


def main():
    for name, fn in (("08_P7", patch_08), ("13_merge", patch_13)):
        path, a, b = fn()
        print("%-10s %-40s %4d -> %4d lines" % (name, path.name, a, b))
    print("OK" + (" (check only, nothing written)" if args.check else ""))


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()
    main()
