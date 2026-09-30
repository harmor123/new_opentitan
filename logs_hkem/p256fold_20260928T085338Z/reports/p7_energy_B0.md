# Step 9 能量估计（路 A：本机解析式，**工具估计非硅测**）— B0（基线，无 fold）

| 项 | 值 |
|---|---|
| liberty | `/home/chy/nangate45/NangateOpenCellLibrary_typical.lib` |
| 网表 | `/tmp/b0/hw/ip/otbn/pre_syn/syn_out/otbn_core_2026_09_30_18_17_11/generated/otbn_core_netlist.sta.v` |
| V / f | 1.10 V（来源：CLI --vdd）/ 125.0 MHz |
| 角 / clock gating | Nangate45 typical / **0（无 ICG，§8.2 实测）** |
| α | 时钟网 = 1；数据网 = 0.10, 0.25, 0.50（**声明式假设，非实测活动率**） |
| 公式 | `P_sw = f·V²·ΣαC`；`P_int = f·Σα·E_int`（表中位值近似）；`P_leak = Σ cell_leakage_power`；`E/op = P_total·cycles/f` |

**liberty 头部单位（原文，供复核）**：`time_unit = 1ns`；`capacitive_load_unit = (1,ff)`；`leakage_power_unit = 1nW`；`voltage_unit = 1V`；`current_unit = 1mA`；`nom_voltage = 1.10`；`nom_temperature = 25.00`；`pulling_resistance_unit = 1kohm`

**电容/泄漏单位（逐项从文件取）**：`capacitive_load_unit` = (1.0, 'ff') ⇒ 1e-15 F/单位；`leakage_power_unit` = 1nW ⇒ 1e-09 W/单位。

**内部功耗标度（按物理上界自动选定，候选逐个列出）**：
- 1 pJ（voltage_unit×current_unit×time_unit） ⇒ 各 α 档 P_int/P_sw = 1.69e+03, 1.32e+03, 1.16e+03 ✗ 违背物理上界
- 1 fJ（= 1 µW × 1 ns） ⇒ 各 α 档 P_int/P_sw = 1.69, 1.32, 1.16 **✓ 选中**
- 1 aJ（= 1 nW × 1 ns） ⇒ 各 α 档 P_int/P_sw = 0.00169, 0.00132, 0.00116 ✗ 违背物理上界

> 按物理上界自动选定：**1 fJ（= 1 µW × 1 ns）**（各 α 档 P_int/P_sw ∈ [0.02, 5]）。**相对比较与标度无关** ✓；绝对 nJ/µJ 依赖该标度 ✗。

## 规模与自校验

- 实例 **194818** 个、cell **78** 种；按 cell 面积累加 = **305121.152 µm²**。
- liberty 解析出 **135** 个 cell；带 `internal_power` 的 pin 数 = **238**；带 `cell_leakage_power` 的 cell 数 = **126**。
- `internal_power` 取值规则（**2026-09-30 修正**）：**只取 `internal_power { }` 组内**的 `values`，同 pin 内多组表与 rise/fall 拉平后取中位；**负值/零值按 >0 过滤**（实测：nangate45 里 `DFFR_X1` 的 rise_power 有负值、`Hidden_power_*` 为多组模板）——被过滤掉的负/零值共 **3820** 项。
- 网表里有、liberty 里没有的 cell：无 ✓
- **自校验（实例数 vs 同一运行的 `area.rpt`）**：比对 78 个 cell，**全部一致 ✓**

## 功耗（逐 α 档）

| α（数据网） | P_sw | P_int | P_leak | **P_total** | P_int/P_sw |
|---:|---:|---:|---:|---:|---:|
| 0.10 | 12.6841 mW | 21.4726 mW | 6.4371 mW | **40.5939 mW** | 1.693 |
| 0.25 | 27.4307 mW | 36.1043 mW | 6.4371 mW | **69.9721 mW** | 1.316 |
| 0.50 | 52.0083 mW | 60.4904 mW | 6.4371 mW | **118.9358 mW** | 1.163 |

> 量级自检：P_int/P_sw = **1.693**（在 1e-3…1e3 内 ✓）。

## 误差与限制（必须同读）

1. **α 是假设不是实测** ⇒ 本报告 = vectorless 工具估计。**同一 α 档下的相对比较**有效 ✓；绝对值须标注为工具估计 ✗ 不得写成硅测/签核功耗。
2. **`internal_power` 取表中位值**：真实值依赖 (input slew, output load) 索引 ✗ ⇒ 近似；精确值需从 OpenSTA 逐实例导出 slew/load（未做）。
3. **不含互连线电容**（无 PEX ✗）⇒ 低估开关功耗；`P_leak` 为 typical 角单值（无温度/工艺角扫描 ✗）。
4. 整核口径把**空闲块**也按同一 α 计入 ⇒ 高估 `energy/ECDH`；fold 单独口径（L1）不受此影响 ✓。
5. **不做「少 cycle ⇒ 节能」的推断**（PDF §15.4 明令）⇒ 能量必须由本表的 P 与实测 cycles 相乘得到。

