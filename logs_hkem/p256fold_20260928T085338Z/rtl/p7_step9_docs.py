#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""P7 §8.13：Step 9 能耗（A 档：解析式工具估计 + B 档：实测活动窗口）—— **一次性生成器，现已过期**。

写 `08_P7_PPA与CSA决策.md` §8.13 + `13_合并影响` 一行。
**在 Windows 侧跑**：`md文档/` 树在 git 仓库之外（仓库的上一级），Linux 侧没有该目录。

> ⚠ **不要再跑本脚本**（2026-09-30 起）：§8.13 已由它写入，随后经过**两次解析修正**
> （`timing` 延时值混入 ×1.81、多组拉平取中位 ×10.15）⇒ 报告里的标度段与数值都变了
> （判据窗口 `[0.02, 50]`、L1 的 `P_int/P_sw` = 18.3/12.7/10.4、1 fJ 由**两工具互证**坐实）。
> 本脚本的断言反映的是**修正前**的文案，重跑必然失败；它的价值只在于审计线（生成了哪些段落）。
> 要核数/更新请用：`p7_step9_7_docs.py`（§8.13.7）、`p7_step9_1_fix.py`（§8.13.1 表格）、
> `p7_step9_ext_docs.py`（§8.13.6）。本脚本现带显式过期护栏，失败信息会直接说明这一点。

用法：python3 logs_hkem/p256fold_20260928T085338Z/rtl/p7_step9_docs.py [--check] [--docs-dir DIR]
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
R = REPO / "logs_hkem/p256fold_20260928T085338Z/reports"
DESIGNS = [("L1", "`otbn_p256_fold` 单独（7,467 实例）"), ("A0", "serial 常量化（205,988 实例）"),
           ("A1", "overlap 常量化（203,354 实例）"), ("B0", "基线（无 fold，194,818 实例）")]
POW = re.compile(r"^\| (\d\.\d\d) \| ([\d.]+) mW \| ([\d.]+) mW \| ([\d.]+) mW \| \*\*([\d.]+) mW\*\* \| ([\d.]+) \|", re.M)
EN = re.compile(r"\| \*\*energy/(\w+)\*\*[^|]*\| (\d+)（([^|]*)） \| (.+?) \|\s*$", re.M)
SMOKE = REPO / "hw/ip/otbn/dv/smoke/p256/p256_fold_test.s"


def load(name):
    return (R / ("p7_energy_%s.md" % name)).read_text(encoding="utf-8", errors="replace")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--docs-dir", help="md文档/…/new_contribution_2 的路径（默认 <仓库上级>/md文档/…）")
    args = ap.parse_args()

    global DOCS
    if args.docs_dir:
        DOCS = pathlib.Path(args.docs_dir)

    E = {k: load(k) for k, _ in DESIGNS}
    act = (R / "p7_activity_L1.md").read_text(encoding="utf-8", errors="replace")

    # ---- 过期护栏（先于一切）：报告已按 2026-09-30 的两次解析修正更新 ⇒ 本脚本的断言语义已不适用
    if "∈ [0.02, 50]" in E["L1"] or "**由工具实测锚定**" in E["L1"] or "组间**相加**" in E["L1"]:
        raise SystemExit(
            "本脚本已过期（一次性生成器，勿重跑）：报告已按 2026-09-30 的两次解析修正更新 ——\n"
            "  · 取值规则改为「只取 internal_power 组内 + 组间相加」（此前 timing 延时值混入 ×1.81、"
            "多组拉平取中位 ×10.15）；\n"
            "  · 标度判据窗口 [0.02, 5] → [0.02, 50]，且 1 fJ/单位由**两工具互证**坐实（见 §8.13.7 甲）；\n"
            "  · §8.13 已由本脚本写入，数值已由 p7_step9_1_fix.py 就地更新（表 A-1/A-2）⇒ 重跑无意义。\n"
            "要核数/更新请用：p7_step9_7_docs.py（§8.13.7）、p7_step9_1_fix.py（§8.13.1 表格）、"
            "p7_step9_ext_docs.py（§8.13.6）。")

    # ---- 断言：报告必须都通过自检（否则不得进文档 ✗）
    for k, _ in DESIGNS:
        assert "自校验（实例数 vs 同一运行的" in E[k], k
        assert "**全部一致 ✓**" in E[k], "%s 的自校验未过 ⇒ 不得引用" % k
    assert "1 fJ（= 1 µW × 1 ns） ⇒ 各 α 档 P_int/P_sw = 0.997, 0.499, 0.292 **✓ 选中**" in E["L1"]
    assert "1 pJ（voltage_unit×current_unit×time_unit） ⇒ 各 α 档 P_int/P_sw = 997, 499, 292 ✗" in E["L1"]
    assert "✅ **自检通过**" in act, "B 档自检未过 ⇒ 不得引用"
    assert "逐窗口拍数 = 28, 28, 28" in act
    assert "`clk_i` | 1 | 84 | 1.0000 |" in act, "clk_i 的 α 必须恰为 1.0000（计数逐拍精确的判据）"
    for row in ("| `cpa_b` | 260 | 2220 | 0.1016 |", "| `cpa_ext` | 261 | 1413 | 0.0644 |",
                "| `mac_acc_after_so_i` | 130 | 1052 | 0.0963 |", "| `cpa_sub` | 1 | 6 | 0.0714 |",
                "| `cycle_q` | 5 | 81 | 0.1929 |"):
        assert row in act, row
    # 独立旁证：窗口数必须等于 smoke 程序里 bn.p256mul 的条数（同一 run 跑的就是它，见 run_p256_fold.sh）
    nfold = len(re.findall(r"^\s*bn\.p256mul\b", SMOKE.read_text(encoding="utf-8", errors="replace"), re.M))
    nwin = int(re.search(r"\*\*窗口\*\*：`(\d+)` 个", act).group(1))
    assert nfold == nwin == 3, (nfold, nwin)
    rs = (REPO / "hw/ip/otbn/dv/smoke/p256/run_p256_fold.sh").read_text(encoding="utf-8", errors="replace")
    assert re.search(r'\$SIM" --load-elf=.*\s-t \| tee', rs), "run_p256_fold.sh 不再默认带 -t ⇒ 8.13.5 第 1 条失效"

    powt = {k: POW.findall(E[k]) for k, _ in DESIGNS}
    for k, _ in DESIGNS:
        assert powt[k], k
    en = {k: EN.findall(E[k]) for k, _ in DESIGNS}
    assert en["L1"] and en["A0"] and en["A1"], en

    L = []
    L.append("### 8.13 Step 9 能耗：A 档（本机解析式工具估计）+ B 档（实测活动窗口）（2026-09-30）")
    L.append("")
    L.append("**口径先行（PDF §15.4）**：允许「**工具估计**」，但要求**同工作负载、同安全配置、同电压、可比活动窗口**，"
             "记录**随机种子**与 **clock gating**，给 `energy/mul`、`energy/ECDH`、`energy/协议阶段` 三个指标与"
             "**绝对量和工具条件**；**不得由「少 cycle」自动推出「节能」**。本节按**两档**给，逐档标明强度 ✓。")
    L.append("")
    L.append("#### 8.13.1 A 档：解析式工具估计（`run_dir/rtl/p7_energy_est.py`，只读网表 + liberty）")
    L.append("")
    L.append("- 公式：`P_sw = f·V²·Σα·C`（`C` = 该网驱动的各输入脚电容和）、`P_int = f·Σα·E_int`"
             "（liberty `internal_power` 表中位值）、`P_leak = Σ cell_leakage_power`、`E/op = P_total·cycles/f`。")
    L.append("- **单位逐项从 liberty 解析**并印进报告：`capacitive_load_unit=(1,ff)`、`leakage_power_unit=1nW`、"
             "`time_unit=1ns`、`voltage_unit=1V`、`current_unit=1mA`、`nom_voltage=1.10`。")
    L.append("- **`internal_power` 标度按物理上界选定**：文件声明推出 1 pJ/单位，但该标度让单门内部能耗 ≈2.7 pJ "
             "≫ 它驱动满负载时全部充电能量 73 fJ（物理不可能 ✗）⇒ 三候选逐档打印、自动选 **1 fJ/单位**"
             "（各 α 档 `P_int/P_sw` = 0.997/0.499/0.292 ✓）。**相对比较与该标度无关** ✓。")
    L.append("- **自校验（硬）**：网表实例数按 cell 与**同一次运行**的 `reports/area.rpt` 逐项比对 —— "
             "L1 **70/70**、A0 **82/82**、A1 **80/80**、B0 **78/78** 全部一致 ✓"
             "（注：**不得**用 `p7_area_*.md` 当判据 —— 那批出自 `TIMING_RUN=0` 的运行，与 `TIMING_RUN=1` 的网表"
             "是**两个设计点**，§8.1 第 10 项已登记 ✗）。")
    L.append("")
    L.append("**表 A-1：四个设计的功耗**（V=1.10 V、f=125 MHz、Nangate45 typical、α 为**声明式假设**、ICG=0）")
    L.append("")
    L.append("| 设计 | α=0.10 P_sw / P_int / P_leak / **P_total** | α=0.25 | α=0.50 |")
    L.append("|---|---|---|---|")
    for k, desc in DESIGNS:
        cells = []
        for row in powt[k]:
            cells.append("%s / %s / %s / **%s mW**" % (row[1], row[2], row[3], row[4]))
        L.append("| **%s** %s | %s | %s | %s |" % (k, desc, cells[0], cells[1], cells[2]))
    L.append("")
    L.append("**表 A-2：能量指标**（`E = P_total·cycles/f`；cycles 用**实测**值，不做「少 cycle ⇒ 节能」的推断）")
    L.append("")
    L.append("| 设计 | 指标 | cycles（来源） | α=0.10 | α=0.25 | α=0.50 |")
    L.append("|---|---|---:|---:|---:|---:|")
    for k in ("L1", "A0", "A1"):
        kind, cyc, src, v = en[k][0]
        vals = [x.strip() for x in v.split("|")]
        L.append("| **%s** | `energy/%s`（%s） | %s（%s） | %s | %s | %s |"
                 % (k, "mul" if kind == "mul" else "ECDH",
                    "fold 单元口径" if k == "L1" else "整核口径，含空闲块 ⇒ 高估",
                    cyc, src, vals[0], vals[1], vals[2] if len(vals) > 2 else "-"))
    L.append("")
    L.append("- **B0 只给功耗、不给能量** ✗：它的 ECDH 走另一套指令调度，**同口径的拍数未实测** ⇒ 不硬凑 ✓。")
    L.append("- `energy/协议阶段` 需该阶段的 **OTBN 侧**拍数（现只有宿主 `HKEM_PROF` 口径 ✗）⇒ **未列** ✗（待补）。")
    L.append("")
    L.append("#### 8.13.2 B 档：实测活动窗口（`run_dir/rtl/p7_activity_vcd.py`，从 RTL 波形量）")
    L.append("")
    L.append("**窗口与计数（实测，均有独立旁证）**：")
    L.append("")
    L.append("- 载体：`run_p256_fold.sh`（**第 64 行** `… $P256_EXTRA -t | tee …`，**默认带 `-t`** ⇒ 自动产生 "
             "`sim.fst`，895 KB / 564 拍）→ `fst2vcd` → 解析。")
    L.append("- **窗口 = 3 个**，与程序**逐条对得上**：该 run 跑的就是 `hw/ip/otbn/dv/smoke/p256/p256_fold_test.s`，"
             "其中 `bn.p256mul` **恰 3 条**（生成器直接数文件并断言 == 窗口数 ✓）；"
             "**逐窗口拍数 = 28 / 28 / 28** ✓✓ —— 这是 RTL 契约「完成周期固定、无早退」的**直接实测**。")
    L.append("- **计数正确性的硬自证**：`clk_i` 的 **α_bit = 1.0000**（84 事件 /(1 bit × 84 拍)）—— "
             "时钟每拍恰好一次 0→1 ⇒ 窗口边界与拍数**逐拍精确** ✓✓。")
    L.append("- **实测 α_bit**（每拍每 bit 的 0→1）：**聚合 0.0284**；翻转信号**中位 0.0357**、"
             "区间 **[0.0071, 1.0000]**。分层看（表中真实值）：**宽数据通路**（`cpa_b` 0.1016、`b_sel` 0.0982、"
             "`f_d`/`out_o` 0.0662、`cpa_a` 0.0661、`cpa_ext` 0.0644）**0.064–0.102**；"
             "**MAC 内部**（130/256 bit 的 `mac_acc_after_so_i` 0.0963、`mac_result_pre_so_i` 0.0722）；"
             "**单比特控制**（`cpa_sub` 0.0714；`busy_q`/`valid`/`a_x` 0.0357）**0.036–0.071**；"
             "**5 位计数器**（`cycle_q`/`phase` 0.1929）——**计满回绕**所致，不是数据活动 ⇒ 归入控制类 ✓。")
    L.append("")
    L.append("**与 A 档假设的对照（重要但不可越界）**：A 档用的 α=0.1/0.25/0.5 里，**只有 0.1 档接近内部数据通路的"
             "实测值（≈0.07）** ✓，0.25/0.5 档**明显偏高** ⇒ **A 档的绝对能量偏保守（高估）** ✓。"
             "**但幅度不可由本项数据定量** ✗：门级 α 取决于**内部网**，而内部网未被逐门测到"
             "（门↔信号绑定只覆盖映射里出现在时序报告中的那些网：**6/1047 = 0.6%** ✗）⇒ **不得据此改 A 档的数** ✗。")
    L.append("")
    L.append("#### 8.13.3 工具条件（PDF 点名要记的字段，逐项给）")
    L.append("")
    L.append("| 项 | 值 |")
    L.append("|---|---|")
    L.append("| 电压 / 频率 | **1.10 V**（liberty `nom_voltage`）/ **125 MHz** |")
    L.append("| 工艺库 / 角 / 温度 | Nangate45 `NangateOpenCellLibrary_typical.lib` / typical / 25 ℃ |")
    L.append("| 活动率 α | **声明式假设 0.10 / 0.25 / 0.50**（A 档）；**RTL 信号级实测**（B 档，见 8.13.2）——"
             "门级仍是模型 ✗ |")
    L.append("| **clock gating** | **0（无 ICG cell，§8.2 实测 ✓）** |")
    L.append("| 随机种子 | **无**：综合（yosys/ABC）与本估计均为**确定性**流程 ⇒ 无种子可记（如实写，不编 ✗） |")
    L.append("| 活动窗口 | A 档：无（vectorless ✗）；B 档：`busy_o` 高电平 3 × 28 拍（实测 ✓） |")
    L.append("")
    L.append("#### 8.13.4 限制（必须与全部数字同读）")
    L.append("")
    L.append("1. **A 档的 α 是假设不是实测** ⇒ 只满足 PDF 的「工具估计」字面、**不满足**「可比活动窗口」✗；"
             "B 档已补上**实测窗口与 RTL 级 α** ✓，但**门级**活动率不可得（Nangate45 只有 `.lib`、无 Verilog "
             "行为模型 ⇒ 门级仿真做不了 ✗）⇒ 门级 α 只能是「其驱动信号的活动率」的**模型** ✗。")
    L.append("2. `internal_power` 取表中位值（真实值依赖 (input slew, output load) 索引 ✗）；精确值需从 OpenSTA "
             "逐实例导出 slew/load（未做 ✗）。")
    L.append("3. **不含互连线电容**（无 PEX ✗）⇒ 低估 `P_sw`；`P_leak` 为 typical 角单值（无温度/工艺角扫描 ✗）。")
    L.append("4. 整核口径把**空闲块**按同一 α 计入 ⇒ 高估 `energy/ECDH` ✗（L1 的 fold 口径不受此影响 ✓）。")
    L.append("5. **不做「少 cycle ⇒ 节能」的推断** ✓：A0↔A1 在**同一 α 档**下的能量差，全部来自两项**表内实测**"
             "（功率几乎相同：α=0.25 档 48.6175 vs 48.2268 mW，差 0.81%；而**实测窗口** 287,970 vs 230,376 拍）"
             "⇒ 结论是「同一功率 × 更短窗口」，**不是**从 cycle 推的 ✗。A0/A1 的功率差 0.81% 与 §8.12 的"
             "「调度对 Fmax 无显著差异」同向 ⇒ **调度本身不省功耗**，省的是时间 ✓。")
    L.append("")
    L.append("#### 8.13.5 可复现性（工具行为差异与命令）")
    L.append("")
    L.append("1. **`run_p256_fold.sh:64` 默认就带 `-t`**（`… $P256_EXTRA -t | tee \"$RUN_LOG\"`）⇒ `sim.fst`"
             "（895 KB）自动产生 ✓，无需改脚本 ✓；**窗口数要和程序对上**：该 smoke 程序里 `bn.p256mul` "
             "恰 3 条 ⇒ 3 个窗口 ✓（这一条应写进校验，光看波形会漏）；")
    L.append("2. **`fst2vcd` 的 scalar 变化是「值在前」**（`1!`、`0ua`），与 VCD 标准（`<id><值>`）**相反** ✗ "
             "⇒ 自研解析器必须先统计命中数**定一次格式**再全文一致使用 ✓（本仓库脚本已实现 ✓）；")
    L.append("3. **同一个网跨 scope 共用 id**（fold 的 `clk_i` ≡ 顶层 `IO_CLK` ≡ `!`）⇒ 判层次**只能按 `$scope` "
             "路径** ✗，按 id 判会错 ✓；")
    L.append("4. **`$var parameter` 也会出现在 scope 里**（`P260`/`NEG_P`/`W`/`AW`）⇒ 必须排除 ✗，否则「信号数」混入常量 ✓；")
    L.append("5. 命令：`fst2vcd -f sim.fst -o fold.vcd` → `python3 run_dir/rtl/p7_activity_vcd.py --vcd fold.vcd "
             "--scope u_otbn_p256_fold --clk clk_i --busy busy_o --names <L1 run>/generated/ys_translated_names "
             "--out <report>`（脚本内置自检：α ≤ 1 且各窗口拍数唯一，不过则**非零退出** ✓）。")
    L.append("")

    sec = "\n".join(L)
    p = DOCS / DOC
    assert p.exists(), (
        "找不到 %s\n"
        "⇒ 本脚本是 **Windows 侧工具**：`md文档/` 树在 git 仓库之外（仓库的上一级），Linux 侧没有该目录。\n"
        "   Linux 上只跑**实测命令**（bazel / pre_syn / 波形解析），不用跑文档生成器；\n"
        "   确需在别处生成时：`--docs-dir <new_contribution_2 的路径>`。" % p)
    t = p.read_text(encoding="utf-8")
    assert "### 8.13 " not in t, "§8.13 已存在"

    q = DOCS / "13_合并影响与回归清单.md"
    assert q.exists(), q
    t2 = q.read_text(encoding="utf-8")
    lines = t2.split("\n")
    i = next(k for k, l in enumerate(lines) if l.startswith("| 2026-09-30 | `aef299b498` |"))
    lines.insert(
        i + 1,
        "| 2026-09-30 | `670b43ffb3` | **P7 Step 9 能耗（P7 §8.13）：A 档工具估计 + B 档实测活动窗口**。"
        "A 档（解析式，只读网表+liberty）：四设计 × 三 α 档功耗 + `energy/mul`(L1) + `energy/ECDH`(A0/A1)；"
        "**实例数自校验对同 run `area.rpt` 70/82/80/78 全一致 ✓**；`internal_power` 标度按**物理上界**自动选 "
        "**1 fJ/单位**（1 pJ 被否：比值 997/499/292 ✗）。B 档（波形实测）：窗口 **3 × 28 拍**（= RTL 契约实测 ✓，"
        "旁证时钟变化 56 行 ✓）、`clk_i` 的 **α_bit = 1.0000**（计数逐拍精确 ✓）、实测 α_bit 聚合 0.0284 / "
        "中位 0.0357 / 内部数据通路 0.064–0.102 ⇒ **A 档的 0.1 档接近实测、0.25/0.5 偏高（偏保守）** ✓，"
        "但门级 α 不可得（绑定覆盖仅 6/1047）⇒ **不得据此改数** ✗。已记五条限制与四个可复现性坑。 |")
    if not args.check:
        p.write_text(t.rstrip("\n") + "\n\n" + sec, encoding="utf-8")
        q.write_text("\n".join(lines), encoding="utf-8")
    print(sec)
    print("OK" + (" (check only)" if args.check else ""))


if __name__ == "__main__":
    main()
