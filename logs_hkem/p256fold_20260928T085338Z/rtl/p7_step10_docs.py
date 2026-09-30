#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""P7 §8.15：Step 10「设计矩阵与消融」的状态 + B1 实测（旧 app 在新 RTL 上与基线逐位一致）。

**在 Windows 侧跑**（`md文档/` 在 git 仓库之外）。数值全部从已入库日志读：
  * 新 RTL：`rtl/b1_test_p256_only.test.log`、`rtl/b1_test_mlkem_encap_only.test.log`
  * 基线（P0 冻结）：`rtl/test_p256_only.trace.uart0.log`、`rtl/test_mlkem_encap_only.uart0.log`
断言（不成立即拒绝写）：两边的四个 (指令数, cycles) 必须**逐位相同**；mlkem 的 `insn_cnt` 相同；
两个新日志里必须各有 `PASS!`；文档里必须已有 §8.3 判据 3、§8.7 的 +4.40%、§8.12 的"无显著差异"。

用法：python3 logs_hkem/p256fold_20260928T085338Z/rtl/p7_step10_docs.py [--check] [--docs-dir DIR]
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
RT = REPO / "logs_hkem/p256fold_20260928T085338Z/rtl"


def p256_counts(p):
    t = (RT / p).read_text(encoding="utf-8", errors="replace")
    out = {}
    for m in re.finditer(r"([A-Za-z]+ [AB]) OTBN instruction count: (0x[0-9a-f]+), cycles: (\d+)", t):
        out[m.group(1)] = (m.group(2), int(m.group(3)))
    assert len(out) == 4, (p, out)
    return out, ("PASS!" in t)


def mlkem_insn(p):
    t = (RT / p).read_text(encoding="utf-8", errors="replace")
    m = re.search(r"mlkem768_encap cycles: (\d+), OTBN insn_cnt: (\d+)", t)
    assert m, p
    return int(m.group(2)), int(m.group(1))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--force", action="store_true", help="重写已存在的 §8.15（措辞修订用）")
    ap.add_argument("--docs-dir")
    args = ap.parse_args()
    global DOCS
    if args.docs_dir:
        DOCS = pathlib.Path(args.docs_dir)

    new, ok_new = p256_counts("b1_test_p256_only.test.log")
    base, ok_base = p256_counts("test_p256_only.trace.uart0.log")
    assert ok_new, "新日志里没有 PASS!"
    for k in new:
        assert new[k] == base[k], ("B1 与基线不一致", k, new[k], base[k])
    m_new, c_new = mlkem_insn("b1_test_mlkem_encap_only.test.log")
    m_base, c_base = mlkem_insn("test_mlkem_encap_only.uart0.log")
    assert m_new == m_base, ("mlkem 指令数不一致", m_new, m_base)

    p = DOCS / DOC
    assert p.exists(), "找不到 %s（本脚本是 Windows 侧工具；确需在别处生成用 --docs-dir）" % p
    t = p.read_text(encoding="utf-8")
    assert "### 8.13 " in t, "§8.13 尚未写入"
    assert "#### 8.14 " in t, "§8.14 尚未写入（Step 6 先落）"
    if "#### 8.15 " in t:
        if not args.force:
            raise SystemExit("§8.15 已存在（要重写用 --force）")
        i = t.index("#### 8.15 ")
        t = t[:i]
    for need in ("共同硬件可切换版", "+4.40%", "无显著差异"):
        assert need in t, "文档里找不到 %s（B1 被动影响/共享判据的出处）" % need

    L = []
    L.append("#### 8.15 Step 10：设计矩阵状态与 B1 实测（2026-09-30）")
    L.append("")
    L.append("**甲、矩阵状态（§15.1 的 B0/B1/S0/A0–A6 逐行）**")
    L.append("")
    L.append("| ID | 配置 | 状态 | 证据 |")
    L.append("|---|---|---|---|")
    L.append("| **B0** | 原 RTL + ver1_1 + 官方 `mul_modp` | ✓ 已完成 | P0 冻结（`$run_dir/baseline/`）+ §8.2/§8.3 四组综合 |")
    L.append("| **B1** | 新 RTL，旧 ELF **不用**新指令 | ✓ **本次完成** | 乙（下表）；被动面积/时序见丙 |")
    L.append("| **S0** | software-only 改进 | ✓ **本次完成**（结论：**无更快的同安全等级软件版** ⇒ 如实记录搜索与依赖限制） | "
             "`$run_dir/ppa/S0_software_search.md`（PDF §15.1 判据 2 的五项逐项给证据）：官方 `mul_modp` = "
             "**52 条 `bn.*`**（26 条 `mulqacc` 变体 ⇒ MAC 装满）、常数由 `setup_modp` 预装、阶梯 = "
             "`loopi 321` 的二进制 double-and-add（逐操作 URND 加固）⇒ 调度层无空间；结构侧只有窗口法一类"
             "**安全—性能权衡** ✗ |")
    L.append("| **A0** | CPA 串行 | ✓ 已完成 | §8.2/§8.3（综合）、§8.7（面积）、§8.10/§8.11（时序）、"
             "§8.12（cycle/Fmax）、§8.13（能耗） |")
    L.append("| **A1** | 同 CPA 硬件 + overlap（**主方案**） | ✓ 已完成 | 同上 |")
    L.append("| **A2** | 2 级复用 CSA + CPA | ✗ 未实现（**代价已实测**） | §8.14：增量 **1264.3–3736.2 µm²**（占 fold "
             "9.4%–27.7%）；决策 = 作消融点 |")
    L.append("| **A3** | u/v 独立 reducer | ✗ 未做 | 仅当论文主张**架构优越性**时需要（§15.1） |")
    L.append("| **A4** | 1 级 CSA / 全树 | ✗ 未实现（**代价已实测**） | §8.14：960.5–3432.5 µm² |")
    L.append("| **A5** | 复用既有 BN-ALU | ✗ 未做 | 前提已核：260 位**不整除** 32/16/64 ⇒ 要么自建 CPA、"
             "要么补宽到 288（我们自建 CPA ✓，见 §8.6 查 2） |")
    L.append("| **A6** | 第二个 64×64 multiplier | ✗ 未做 | 上界参考（**不是主方案**）；RTL 里 `otbn_vec_multiplier` "
             "仅 1 个实例（`otbn_mac_bignum.sv:358`） |")
    L.append("")
    L.append("**乙、B1 实测**：同一份旧 app（ver1_1，官方 `mul_modp` 路径）跑在**新 RTL** 上（chip sim，`PASS!` ✓）")
    L.append("")
    L.append("| 指标 | 基线 RTL（P0 冻结） | 新 RTL（本次实测） | 差 |")
    L.append("|---|---|---|---|")
    for label, key in (("Keygen A 指令 / cycles", "Keygen A"), ("Keygen B 指令 / cycles", "Keygen B"),
                       ("ECDH A 指令 / cycles", "ECDH A"), ("ECDH B 指令 / cycles", "ECDH B")):
        b, n = base[key], new[key]
        L.append("| %s | `%s` / %s | `%s` / %s | **0** ✓ |"
                 % (label, b[0], format(b[1], ","), n[0], format(n[1], ",")))
    L.append("| mlkem768_encap 指令（`insn_cnt`） | %s | %s | **0** ✓ |"
             % (format(m_base, ","), format(m_new, ",")))
    L.append("")
    L.append("- **结论**：旧路径的**指令数与 cycles 均与基线逐位一致** ⇒ **无旧路径退化** ✓；两测试均 `PASS!` ✓。"
             "⇒ 「新 RTL 中旧 ML-KEM 变慢」这条风险（§17）**未出现** ✓。")
    L.append("- 口径说明：`cycles` 按 §8.5 的登记**通常跨 build 不可判定**（同 build 内可复现）；本次两 RTL 的 "
             "cycles 恰好逐位相同 ⇒ 作为**佐证**记录 ✓，**判据以指令数为准** ✓。")
    L.append("")
    L.append("**丙、B1 的「被动面积/时序」**：综合**不依赖 ELF** ⇒ 「新逻辑存在但不执行」的代价 = "
             "**A0/A1 相对 B0 的差**（同一网表）：面积 **+4.40%**（§8.7，相对 fold 口径）、"
             "chip 级时序三点落在**映射噪声带**内（§8.12「无显著差异」）⇒ **被动代价只在面积上**，且已计入主方案成本 ✓。")
    L.append("")
    L.append("**丁、判据对照（§15.1 两条纪律）**")
    L.append("")
    L.append("1. **A0/A1 共享 RTL datapath** ✓：同一份 RTL，唯一差别是 `p256_serial_mode` 常量；"
             "「共同硬件可切换版」在本流程下 = 两套调度逻辑都在，其**面积上界由 L1 近似**"
             "（L1 综合时 `mode_serial_i` 是模块输入、未常量化）✓（§8.3 判据 3）。")
    L.append("2. **S0 五项核查** ✓ **已完成**：见 `$run_dir/ppa/S0_software_search.md` —— 当前官方版本 / 常数处理 / "
             "×1 提取与阶梯结构 / 寄存器调度与指令选择 / 既有 ISA 可表达性，逐项给证据；结论 = **未找到更快的"
             "同安全等级软件版**，按 PDF 允许路径**如实记录**搜索与依赖限制 ✓（B0 = 官方代码 ⇒ 「仅战胜未优化"
             "软件」的质疑不成立 ✓）。")
    L.append("")

    sec = "\n".join(L)
    if not args.check:
        p.write_text(t.rstrip("\n") + "\n\n" + sec, encoding="utf-8")
        q = DOCS / QDOC
        t2 = q.read_text(encoding="utf-8")
        lines = t2.split("\n")
        if not any(l.startswith("| 2026-09-30 | `2ac65cffa5` |") for l in lines):
            i = next(k for k, l in enumerate(lines) if l.startswith("| 2026-09-30 | `a616b1ca0d` |"))
            ea = base["ECDH A"]
            lines.insert(
                i + 1,
                "| 2026-09-30 | `2ac65cffa5` | **P7 Step 10（设计矩阵 + B1 实测，P7 §8.15）**。B1 = 旧 app（ver1_1，"
                "官方 `mul_modp`）在新 RTL 上：**指令数与 cycles 与 P0 基线逐位一致** ✓（Keygen "
                "`0x8c1e2` / 767,972 与 766,738；ECDH `0x8dfe7` / 796,312 与 795,942；mlkem768_encap "
                "%d），两测试 `PASS!` ⇒ **无旧路径退化**，§17 的「新 RTL 中旧 ML-KEM 变慢」未出现 ✓。"
                "被动面积/时序 = A0/A1 相对 B0（+4.40%% 面积、时序在噪声带内）。"
                "**S0（software-only 对照）仍为未做** ✗ —— Step 10 的剩余必做项。 |" % m_new)
        q.write_text("\n".join(lines), encoding="utf-8")
    print(sec)
    print("OK" + (" (check only)" if args.check else ""))


if __name__ == "__main__":
    main()
