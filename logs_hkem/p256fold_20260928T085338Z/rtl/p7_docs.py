#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""P7 Step 1/Step 2 的文档更新（一次性工具；带断言）。

改两个文件（<repo>/../md文档/p256方案20260927/new_contribution_2/）：
  08_P7_PPA与CSA决策.md   —— 新增 §8 实测结果（冻结条件十项 + 四组综合 + 判据对照 + 限制）
  13_合并影响与回归清单.md —— §3 第 8 行补 P7 常量开关、新增 pre_syn 行、计数刷新、更新记录一行

用法：python3 logs_hkem/p256fold_20260928T085338Z/rtl/p7_docs.py [--check]
"""
import argparse
import pathlib

DOCS = (pathlib.Path(__file__).resolve().parents[4] / "md文档"
        / "p256方案20260927" / "new_contribution_2")

S8 = """## 8. 实测结果（2026-09-30，顶端 `8f8210dccc`）

### 8.1 Step 2：统一综合条件（十项逐项落定）

| # | 项 | 落定值 | 依据（实测） |
|---:|---|---|---|
| 1 | 库 | Nangate45 `NangateOpenCellLibrary_typical.lib`（OpenROAD-flow-scripts 平台目录，公开） | 由 `LR_SYNTH_CELL_LIBRARY_PATH` 注入 |
| 2 | 工艺角 | `typical`（该库只提供 typical 一组） | 库内容无 `set_operating_conditions` |
| 3–4 | VDD / 温度 | 库内建（typical 角自带） | 同上 |
| 5 | 时钟 | **8000 ps = 125 MHz** | `otbn_lr_synth_conf.tcl` 的 `lr_synth_clk_period`；与 `syn/constraints.sdc` 的 `MAIN_TCK 8.0` 一致 |
| 6 | IO delay | 输出 70% / 输入 30% 周期 | `lr_synth_outputs = {*_o 70.0}`、`lr_synth_inputs = {*_i 30.0}` |
| 7 | false paths | **无** | 该 tcl 全文无例外 |
| 8 | multicycle paths | **无**（未给新 fold 路径加任何例外） | 同上 |
| 9 | 工具 | **yosys 0.64+341**（git cc9692caa）+ `yosys-abc` + **sv2v 0.0.13** | `yosys -V` 实测；`dc_shell` 不在本机 ⇒ 走仓库自带 `pre_syn` 流（AES/KMAC 同款） |
| 10 | 优化等级 | `synth -flatten`；ABC uprate 4000 ps | `lr_synth_abc_clk_uprate`、`LR_SYNTH_FLATTEN=1` |
| — | **内存尺寸（必填）** | **IMEM 32768 B / DMEM 32768 B** | `otbn_core` 的 `chparam`，值取自 `otbn.sv:115,117`（`OTBN_IMEM_SIZE=0x8000`、`OTBN_DMEM_SIZE=0x4000` + `DmemScratchSizeByte=16384`）——**不是** `syn_setup.example.sh` 的默认 4096/4096 |
| — | **面积层次** | **L1/L2 可得；L3（完整 SoC）本机不可得** | 本机只有 yosys/sv2v；SoC 级需 DC 或等价商业流程 |

### 8.2 Step 1：四组综合（同一 flow、同一冻结条件）

唯一变量：RTL 版本（B0 = 基线 `2d87e79bee`，无 fold 单元）与 `p256_serial_mode` 常量（A0 = `1'b1` 默认；A1 = 由 `--define=OTBN_P256_OVERLAP_SYNTH` 注入 `1'b0`）。**L1** 是 fold 模块单独作顶层。

| 指标 | **B0**（基线 RTL） | **A0**（serial 常量化） | **A1**（overlap 常量化） | **L1**（`otbn_p256_fold` 单独） |
|---|---:|---:|---:|---:|
| 总面积 um^2 | **296,692.942** | **308,086.786** | **307,758.542** | **11,437.202** |
| kGE | 371.9 | 386.1 | 385.5 | 14.3 |
| 时序单元 | 92,301.468 (31.11%) | 96,493.628 (31.32%) | 96,488.308 (31.35%) | 5,543.440 (48.47%) |
| 寄存器 | 92,364.2 | 96,516.6 | 96,490.8 | 5,543.4 |
| 组合逻辑 | 165,742.8 | 175,368.5 | 172,262.7 | 4,988.8 |
| mux | 38,700.0 | 36,200.0 | 39,000.0 | 904.9 |
| buffer / clock gating | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 |

**三条差值（全部实测）**：

| 差值 | 值 | 含义 |
|---|---:|---|
| **A0 − B0** | **+11,393.844 um^2（+3.84%）** | 引入 fold 单元后完整 OTBN 的增量 = **L2 层新成本**（寄存器 +4,152.4 / 组合 +9,625.7 / mux −2,500.0） |
| **A1 − A0** | **−328.244 um^2（−0.107%）** | 两种调度面积**几乎相同**（组合 −3,105.8 / mux +2,800.0 的再平衡）⇒ **共享 datapath** |
| **L1 vs (A0 − B0)** | **11,437.202 vs 11,393.844 ⇒ 差 43.4 um^2（0.4%）** | L2 的增量**几乎全部**就是 fold 模块本体；MAC 侧接线 + 调度表 + 模式 mux 的净贡献在噪声量级 |

### 8.3 Step 1 判据对照

| 判据（§3 Step 1） | 结论 | 证据 |
|---|---|---|
| 1. A1 先出、**不提前上 CSA** | ✓ 四组综合里**没有任何 CSA 结构**（A2 未做） | §8.2 |
| 2. A0/A1 **共享 RTL datapath** 并记录模式选择参数 | ✓ 同一份 RTL，唯一差别是 `p256_serial_mode` 常量（A0 默认 `1'b1`；A1 由宏注入 `1'b0`） | **A1 − A0 = −0.107%** |
| 3. 若综合器因模式参数删掉不同控制逻辑 ⇒ 同时报「共同硬件可切换版」与「各自常量化版」并标清差异 | ✓ 本次给的是**各自常量化版**（A0/A1），差异 0.107% 且已标清（组合 ↔ mux 再平衡）；**「共同硬件可切换版」**在本流程下 = "两套都在"，其面积上界可由 **L1** 近似（L1 综合时 `mode_serial_i` 是**模块输入、未常量化** ⇒ 两套调度逻辑都在） | §8.2 |

### 8.4 限制与澄清（避免误读）

1. **L3（完整 SoC）不可得**：本机无 DC/OpenROAD ⇒ 只报 L1/L2。**不得用 L2 冒充 L3**，也不得用 L3 稀释 L1/L2 的结论（§15.2 原文）。
2. **`Area in kGE = 0.0` 是 vendored 脚本的格式不匹配，不是设计问题**：`hw/vendor/lowrisc_ibex/syn/python/get_kge.py:50` 把报告**第一列当 cell 名**，而 yosys 0.64 的列序是 `<个数> <面积> <cell名>` ⇒ 零匹配。本阶段 kGE 由 `run_dir/rtl/p7_area_report.py` 算（参考单元 `NAND2_X1`，其单元面积由报告自身推得）。
3. **`cells` 汇总行只印 3 位有效数字**（`3.08E+05`）⇒ 用它自证时带 ±几百 um^2 的量化差；**以模块总面积（全精度）为准**（逐 cell 行之和与它差 0.04% 以内）。
4. **`clock gating = 0`** 只表示本流程**没有插入 ICG cell**，不等于设计无门控成本。
5. **「完整性/安全控制」不能由平铺报告分割**（ECC/blanking 逻辑与普通 NAND/AND 同级），表里保持 `n/a`。结构侧按 §10.6 可报两组位数：新状态 **F(260)+h(256)+LL(128) = 644 原始位**；沿用 39-bit/字完整性编码时 **F→351、h→312、LL→156 物理位**（待与 RTL 逐项核对后填数）。

### 8.5 产物与复现

产物（已入库）：`reports/p7_area_{A0,A1,B0,L1}.md`。

```bash
cd ~/new_pqc/opentitan
# 库（公开，一次性）
curl -L --fail -o ~/nangate45/NangateOpenCellLibrary_typical.lib \\
  https://raw.githubusercontent.com/The-OpenROAD-Project/OpenROAD-flow-scripts/master/flow/platforms/nangate45/lib/NangateOpenCellLibrary_typical.lib
# A0 / A1（同一 flow，只差一个宏）
cd hw/ip/otbn/pre_syn
./syn_yosys.sh
LR_SYNTH_EXTRA_DEFINES="--define=OTBN_P256_OVERLAP_SYNTH" ./syn_yosys.sh
# B0：基线 RTL 的 worktree + 同一份 flow 与冻结条件
cd ~/new_pqc/opentitan
git worktree add /tmp/b0 2d87e79bee
cp hw/ip/otbn/pre_syn/{syn_yosys.sh,syn_setup.sh} /tmp/b0/hw/ip/otbn/pre_syn/
(cd /tmp/b0/hw/ip/otbn/pre_syn && ./syn_yosys.sh)
# L1：fold 模块单独作顶层
cd hw/ip/otbn/pre_syn
sed -i "s|^export LR_SYNTH_TOP_MODULE=.*|export LR_SYNTH_TOP_MODULE=otbn_p256_fold|" syn_setup.sh
./syn_yosys.sh
# 解析（六类 + kGE + 自证）
python3 logs_hkem/p256fold_20260928T085338Z/rtl/p7_area_report.py \\
    --area-rpt hw/ip/otbn/pre_syn/syn_out/latest/reports/area.rpt --label A0 \\
    --out logs_hkem/p256fold_20260928T085338Z/reports/p7_area_A0.md
```

"""


def read(p):
    return p.read_text(encoding="utf-8")


def write(p, s):
    p.write_text(s, encoding="utf-8")


def sub_once(t, old, new, what):
    n = t.count(old)
    assert n == 1, "%s：期望 1 次，实际 %d 次" % (what, n)
    return t.replace(old, new, 1)


def line_index(lines, prefix, what):
    idx = [i for i, l in enumerate(lines) if l.startswith(prefix)]
    assert len(idx) == 1, "%s：期望 1 行，实际 %d 行" % (what, len(idx))
    return idx[0]


def patch_08():
    p = DOCS / "08_P7_PPA与CSA决策.md"
    t = read(p)
    orig = t
    anchor = "## 7. 溯源与待确认项"
    assert t.count(anchor) == 1
    t = t.replace(anchor, S8 + anchor, 1)          # §8 插在 §7 之前
    assert t != orig
    if not args.check:
        write(p, t)
    return p, len(orig.split("\n")), len(t.split("\n"))


def patch_13():
    p = DOCS / "13_合并影响与回归清单.md"
    t = read(p)
    orig = t

    # ① §3 第 8 行：补 P7 的常量开关
    lines = t.split("\n")
    i = line_index(lines, "| 8 | `rtl/otbn_core.sv`", "13/第 8 行")
    assert lines[i].endswith("| 同第 5 行 |")
    lines[i] = lines[i][:-len("| 同第 5 行 |")] + (
        "| 同第 5 行 + **P7**：`ifdef SYNTHESIS` 分支里 `p256_serial_mode` 默认 `1'b1`（A0），"
        "定义 `OTBN_P256_OVERLAP_SYNTH` 时为 `1'b0`（A1）—— 仿真路径逐字节不变，"
        "A0/A1 面积差 **−0.107%**（L2） |")
    t = "\n".join(lines)

    # ② 新增一行：pre_syn 流程修复
    lines = t.split("\n")
    i = line_index(lines, "| 21 | `test_perf/doc_fragments/ver1_2_extra.md`", "13/第 21 行")
    lines.insert(i + 1,
                 "| 22 | **`hw/ip/otbn/pre_syn/syn_yosys.sh`**（P7：yosys 前置综合流的三处修复） | "
                 "只影响该**实验性**前置综合流（不参与 chip 构建、不进 `//hw:rtl_files`）："
                 "① 包清单补 `keymgr_dpe`/`kmac`(含 `sha3_pkg`)/`ibex`；② 模块清单补 9 个 "
                 "（`prim_trivium`、`prim_hpc3`、`prim_flop_x`、`prim_secded_inv_{22_16,hamming_*}*`）；"
                 "③ `StateEnumT` 的 sed 改成通用模式、sv2v 调用加 `${LR_SYNTH_EXTRA_DEFINES}`。"
                 "不修则流在 sv2v/yosys 阶段逐条报缺包/缺模块 —— 上游 flow 落后于上游 RTL，"
                 "基线（B0）同样需要这些修复 ⇒ 两侧同一 flow 才是公平对照 | 无（不改变任何 RTL/功能）；"
                 "判据 = 四组综合（A0/A1/B0/L1）都能出面积报告 | 四组均出数，见 `08_P7_*.md` §8 |")
    t = "\n".join(lines)

    # ③ 计数刷新
    t = sub_once(t, "**代码/配置面（168 个文件", "**代码/配置面（169 个文件", "13/①计数")
    t = sub_once(t, "（**144 文件 / +723,140 行**）", "（**149 文件 / +723,650 行**）", "13/②计数")

    # ④ P4 行里"综合固定"的措辞按事实细化
    t = t.replace("`otbn_core.sv` 一处捕获模式（仿真 plusarg `p256_serial`、综合固定）",
                  "`otbn_core.sv` 一处捕获模式（仿真 plusarg `p256_serial`；综合为常量，"
                  "默认 serial，A1 由宏切 —— 见 §3 第 8 行的 P7 登记）", 1)

    # ⑤ 更新记录
    lines = t.split("\n")
    i = line_index(lines, "| 2026-09-30 | `16af5ad87f` |", "13/更新记录锚点")
    lines.insert(i + 1,
                 "| 2026-09-30 | `8f8210dccc` | **P7 Step 1/2 完成（A0/A1/B0/L1 四组综合，同一 flow）**。"
                 "**工具面**：本机只有 yosys 0.64+341 / yosys-abc / sv2v 0.0.13（无 DC）⇒ 走仓库自带 "
                 "`pre_syn` 流；该流落后于上游 RTL，逐条修复（包清单 3 处、模块清单 9 个、`StateEnumT` "
                 "的 sed 与 `${LR_SYNTH_EXTRA_DEFINES}`）—— **基线 B0 同样需要**，故两侧同一 flow。"
                 "**冻结条件**（`08_P7_*.md` §8.1 十项 + 内存尺寸）：Nangate45 typical、125 MHz（8000 ps）、"
                 "IO 70/30、无 false/multicycle、`synth -flatten`、ABC uprate 4000、"
                 "**IMEM/DMEM 均 32768 B**（不是 example 里的 4096/4096）。**结果**："
                 "B0 **296,692.942** / A0 **308,086.786** / A1 **307,758.542** / L1 **11,437.202** um^2；"
                 "**A0−B0 = +11,393.844（+3.84%）**、**A1−A0 = −328.244（−0.107%）**、"
                 "**L1 与 A0−B0 差 43.4 um^2（0.4%）** ⇒ 增量几乎全是 fold 模块本体、A0/A1 共享 datapath "
                 "被定量证实。**澄清**：`Area in kGE = 0.0` 是 vendored `get_kge.py` 的列序不匹配（非设计问题），"
                 "kGE 由 `run_dir/rtl/p7_area_report.py` 算；`cells` 汇总行只有 3 位有效数字（用模块总面积为准）；"
                 "`clock gating = 0` 只表示未插 ICG；**L3（SoC）本机不可得**，如实登记为限制。"
                 "§1 的 ① 刷新为 **169 个文件**、② 为 **149 文件 / +723,650 行**。 |")
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
