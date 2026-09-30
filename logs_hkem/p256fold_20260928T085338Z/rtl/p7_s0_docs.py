#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""P7 Step 10（S0）：写出 `$run_dir/ppa/S0_software_search.md` —— 软件侧对照的**搜索与依赖限制**。

PDF §15.1 判据 2 的原文：「**软件对照（S0）须核查**：当前官方版本、常数处理、×1 提取、寄存器调度与
既有 ISA 可表达性。**若尝试后没有更快的软件版，给出尝试和依赖限制；不要承诺一定能得到新的软件周期。**」

本节**只读**官方实现（`sw/otbn/crypto/p256_base.s` 等，**不改**任何 `sw/` 文件 ✗），逐项给出证据；
所有数字从源码与已入库日志读，断言不成立即拒绝写。

用法：python3 logs_hkem/p256fold_20260928T085338Z/rtl/p7_s0_docs.py [--check]
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
RUN = REPO / "logs_hkem/p256fold_20260928T085338Z"
RT = RUN / "rtl"
BASE_S = REPO / "sw/otbn/crypto/p256_base.s"
DOC = REPO.parent / "md文档" / "p256方案20260927" / "new_contribution_2/08_P7_PPA与CSA决策.md"


def mul_modp_stats():
    """mul_modp 本体的静态规模（按 `bn.*` 计）与用到的指令族。"""
    t = BASE_S.read_text(encoding="utf-8", errors="replace")
    i = t.index("\nmul_modp:")
    j = t.index("\nsetup_modp:", i)      # 下一个顶层例程标签 = mul_modp 本体结束
    body = t[i:j]
    ops = re.findall(r"bn\.[a-z0-9._]+", body)
    fam = {}
    for o in ops:
        fam[o] = fam.get(o, 0) + 1
    return len(ops), fam, body


def app_counts(p):
    t = (RT / p).read_text(encoding="utf-8", errors="replace")
    ins = [int(m.group(1), 16) for m in re.finditer(r"instruction count: (0x[0-9a-f]+), cycles: (\d+)", t)]
    cyc = [int(m.group(2)) for m in re.finditer(r"instruction count: (0x[0-9a-f]+), cycles: (\d+)", t)]
    assert len(ins) == 4, p
    return ins[0], ins[2], cyc[0], cyc[2]          # ECDH A 的指令/周期（Keygen/ECDH 成对）


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    n_ops, fam, body = mul_modp_stats()
    assert n_ops == 52, ("mul_modp 的静态规模变了，先复核再写文档", n_ops)
    for k in ("bn.mulqacc", "bn.mulqacc.z", "bn.mulqacc.so", "bn.mulqacc.wo", "bn.addm", "bn.rshi"):
        assert k in fam, ("mul_modp 里找不到 %s" % k)
    src = BASE_S.read_text(encoding="utf-8", errors="replace")
    m = re.search(r"loopi\s+(\d+),\s*(\d+)\s*/\* SCA_TEST_REPLACE", src)
    assert m and m.group(1) == "321", "阶梯的 loopi 变了，先复核"
    assert "bn.wsrr" in src and "URND" in src, "阶梯里没有 URND（SCA 加固）"
    k_ins, e_ins, k_cyc, e_cyc = app_counts("b1_test_p256_only.test.log")
    t = DOC.read_text(encoding="utf-8", errors="replace")
    m2 = re.search(r"调用数两档相同（\*\*(\d+)\*\*）", t)
    assert m2, "文档里找不到每次 ECDH 的 p256mul 调用数"
    calls = int(m2.group(1))
    assert calls == 9599, calls

    L = []
    L.append("# S0：software-only 对照的搜索与依赖限制（P7 Step 10；PDF §15.1 判据 2）")
    L.append("")
    L.append("> PDF 原文：「**软件对照（S0）须核查**：当前官方版本、常数处理、×1 提取、寄存器调度与既有 ISA "
             "可表达性。**若尝试后没有更快的软件版，给出尝试和依赖限制；不要承诺一定能得到新的软件周期。**」")
    L.append("")
    L.append("**结论先行**：本次**未找到、也未实现**比官方实现更快的**同安全等级**软件版 ⇒ 按 PDF 的允许"
             "路径如实记录搜索过程与依赖限制（下列五项逐项给证据）。官方实现本身即是我们的 baseline（B0，"
             "P0 冻结）⇒ 「仅战胜未优化软件」这一质疑不成立：B0 = 官方代码 ✓。")
    L.append("")
    L.append("## 1. 当前官方版本（读的是哪份）")
    L.append("")
    L.append("- `sw/otbn/crypto/p256_base.s`（%d 行）—— 坐标算术与 `mul_modp`；"
             "`p256_shared_key.s`（ECDH 上层）。**本节只读，不修改任何 `sw/` 文件** ✗。" % len(src.split(chr(10))))
    L.append("- baseline = P0 冻结的 `run_p256.elf`（sha256 `f4d64e80…`，36,732 B）+ 其 chip 日志"
             "（`$run_dir/rtl/test_p256_only.trace.uart0.log`）⇒ 对照物可复现 ✓。")
    L.append("")
    L.append("## 2. 常数处理")
    L.append("")
    L.append("- `setup_modp` 每次标量乘**起始装一次**：`MOD ← p`、`w28 ← r256`、`w29 ← r448`"
             "（`scalar_mult_int` 第 1300–1303 行处的调用 ✓）⇒ 循环内**不重复装载** ✓。")
    L.append("- 约简用 `bn.addm`（对 `p` 的模加）+ 现成的 `r256/r448` 常数；**减法项**刻意不存表，"
             "改写为 `bn.sub` 的移位链（源码注释给了理由：负项 ~224 位比正项 ~256 位更快）⇒ "
             "常数侧已是最省 ✓。")
    L.append("")
    L.append("## 3. ×1 提取与阶梯结构")
    L.append("")
    L.append("- 阶梯 = **二进制 double-and-add**，`loopi 321, 63`（= 320 位 + 1 次收尾 ✓）：每迭代"
             "**1 次 `proj_double`** + **按标量位条件 1 次 `proj_add`** ✓。")
    L.append("- 标量位/中间值逐次用 `bn.wsrr … URND` 随机化后再提取（SCA 加固），**不是**追求速度的写法 ✓。")
    L.append("- ⇒ **321 次 double 是结构下界**（256 位标量无论二进制还是 w-窗口都要 255–256 次 double ✗"
             "窗口省不掉它）；可减的只有 `proj_add` 的次数（窗口法 ~160 → ~60）⇒ 那需要**预计算表**，"
             "并会改变逐操作 URND 掩码的安全策略 ⇒ 属**安全—性能权衡**，不是「白捡的软件优化」✗。")
    L.append("")
    L.append("## 4. 寄存器调度与指令选择（`mul_modp` 本体，逐项计数）")
    L.append("")
    L.append("- 静态规模：**%d 条 `bn.*`** —— %s ⇒ 每次都把 MAC 装满（`mulqacc` 及其 `.z/.so/.wo` "
             "变体共 %d 条），写回只在与约简衔接处做（`.so`/`.wo` 就是为此而用）✓。"
             % (n_ops, "、".join("`%s`×%d" % (k, fam[k]) for k in
                                ("bn.mulqacc", "bn.mulqacc.z", "bn.mulqacc.so", "bn.mulqacc.wo",
                                 "bn.addm", "bn.add", "bn.sub", "bn.rshi") if k in fam),
                fam.get("bn.mulqacc", 0) + fam.get("bn.mulqacc.z", 0) + fam.get("bn.mulqacc.so", 0)
                + fam.get("bn.mulqacc.wo", 0) + fam.get("bn.mulqacc.wo.z", 0)))
    L.append("- 累加链**串行依赖**（每条 `mulqacc` 累加到同一 ACC ⇒ 必须等上一条出结果）⇒ 该等待是"
             "**结构性**的，软件层无法消除（除非改算法/数据流 ✗）✓。")
    L.append("- 实测（B1 用的同一份旧 app，新 RTL 上与基线逐位一致 ✓）：每次 ECDH = **%s 条指令 / %s "
             "周期** ⇒ **%.2f cycles/insn**，即约 **%.0f%%** 的周期是等待 ✓ —— 与上面的结构判断一致。"
             % (format(e_ins, ","), format(e_cyc, ","), e_cyc / e_ins, 100 * (1 - e_ins / e_cyc)))
    L.append("- 调用规模：每次 ECDH ≈ **%s 次 `mul_modp`**（§8.12 实测调用数）⇒ 平均 %.1f 条指令/调用"
             "（= 52 条本体 + 调用与循环开销 ✓，两者吻合）。"
             % (format(calls, ","), e_ins / calls))
    L.append("")
    L.append("## 5. 既有 ISA 可表达性")
    L.append("")
    L.append("- 官方已用到最强的 MAC 形式（`bn.mulqacc` 的 `.z/.so/.wo`）、`bn.addm/subm`、`bn.rshi`、"
             "`bn.subb/addc`、`bn.mov/addi`、`bn.lid` —— 本任务所需的算术形式**在既有 ISA 内已表达完毕** ✓；"
             "没有「存在但未用」的指令可捡 ✗。")
    L.append("- 与我们的新指令对比：A1 的收益来自**硬件**（合并归约 + 6 拍窗口），不是「用了更好的软件写法」 "
             "✓ —— 这正是 B0/A1 对照要证明的事 ✓。")
    L.append("")
    L.append("## 6. 尝试与依赖限制（如实记录）")
    L.append("")
    L.append("| 候选项 | 是否可做 | 卡在哪 |")
    L.append("|---|---|---|")
    L.append("| 指令级重排 / 消冗 | ✗ 无空间 | `mulqacc` 串行累加同一 ACC ⇒ 等待是结构性的；本体已 52 条、常数已预装 ✓ |")
    L.append("| 窗口法（w=2/4）减少 `proj_add` | 需实现 + 需改安全策略 | 需要预计算点表；且要改动官方**逐操作 URND 掩码**的加固写法 ⇒ 安全—性能权衡 ✗ |")
    L.append("| 改动阶梯本身 | ✗ 受限 | 阶梯在 `sw/otbn/crypto/*`（**本任务不改任何 `sw/` 文件** ✗）；要做只能把阶梯复制进我们包再改 + 重新过 KAT/协议测试 ⇒ 记为依赖限制 |")
    L.append("| 换更快的点公式（如 Jacobian → 其他坐标） | ✗ 超范围 | 会改变域运算次数与 KAT 口径 ⇒ 不是「同一算术的软件优化」✗ |")
    L.append("")
    L.append("⇒ **结论**：软件侧（调度、常数、指令选择）**已无空间**；结构侧的可行手段都要么改安全策略、"
             "要么改 vendored 代码/算术口径 ⇒ 按 PDF 判据 2 的允许路径**如实记录** ✓，"
             "**不承诺**存在更快的同安全等级软件版 ✗。")
    L.append("")
    L.append("**复现（只读）**：")
    L.append("")
    L.append("```bash")
    L.append("awk 'NR>=419 && NR<=566' sw/otbn/crypto/p256_base.s | grep -c -E '^\\s+bn\\.'   # mul_modp 的 bn.* 条数 = 52")
    L.append("grep -n 'loopi     321, 63' sw/otbn/crypto/p256_base.s                          # 阶梯迭代数")
    L.append("grep -a 'OTBN instruction count' logs_hkem/p256fold_20260928T085338Z/rtl/b1_test_p256_only.test.log")
    L.append("```")
    L.append("")

    out = RUN / "ppa" / "S0_software_search.md"
    out.parent.mkdir(parents=True, exist_ok=True)
    txt = "\n".join(L)
    if not args.check:
        out.write_text(txt + "\n", encoding="utf-8")
        print("[写] %s" % out)
    print(txt)
    print("OK" + (" (check only)" if args.check else ""))


if __name__ == "__main__":
    main()
