# Step 9 能量估计（路 A：本机解析式，**工具估计非硅测**）— A1+pd（overlap 常量化）

| 项 | 值 |
|---|---|
| liberty | `/home/chy/nangate45/NangateOpenCellLibrary_typical.lib` |
| 网表 | `/home/chy/new_pqc/opentitan/hw/ip/otbn/pre_syn/syn_out/otbn_core_2026_09_30_20_22_02/generated/otbn_core_netlist.sta.v` |
| V / f | 1.10 V（来源：CLI --vdd）/ 125.0 MHz |
| 角 / clock gating | Nangate45 typical / **0（无 ICG，§8.2 实测）** |
| α | 时钟网 = 1；数据网 = 0.10, 0.25, 0.50（**声明式假设，非实测活动率**） |
| 公式 | `P_sw = f·V²·ΣαC`；`P_int = f·Σα·E_int`（表中位值近似）；`P_leak = Σ cell_leakage_power`；`E/op = P_total·cycles/f` |

**liberty 头部单位（原文，供复核）**：`time_unit = 1ns`；`capacitive_load_unit = (1,ff)`；`leakage_power_unit = 1nW`；`voltage_unit = 1V`；`current_unit = 1mA`；`nom_voltage = 1.10`；`nom_temperature = 25.00`；`pulling_resistance_unit = 1kohm`

**电容/泄漏单位（逐项从文件取）**：`capacitive_load_unit` = (1.0, 'ff') ⇒ 1e-15 F/单位；`leakage_power_unit` = 1nW ⇒ 1e-09 W/单位。

**内部功耗标度（按物理上界自动选定，候选逐个列出）**：
- 1 pJ（voltage_unit×current_unit×time_unit） ⇒ 各 α 档 P_int/P_sw = 898, 437, 250 ✗ 违背物理上界
- 1 fJ（= 1 µW × 1 ns） ⇒ 各 α 档 P_int/P_sw = 0.898, 0.437, 0.25 **✓ 选中**
- 1 aJ（= 1 nW × 1 ns） ⇒ 各 α 档 P_int/P_sw = 0.000898, 0.000437, 0.00025 ✗ 违背物理上界

> 按物理上界自动选定：**1 fJ（= 1 µW × 1 ns）**（各 α 档 P_int/P_sw ∈ [0.02, 5]）。**相对比较与标度无关** ✓；绝对 nJ/µJ 依赖该标度 ✗。

## 规模与自校验

- 实例 **203354** 个、cell **80** 种；按 cell 面积累加 = **318693.270 µm²**。
- liberty 解析出 **135** 个 cell；带 `internal_power` 的 pin 数 = **238**；带 `cell_leakage_power` 的 cell 数 = **126**。
- 网表里有、liberty 里没有的 cell：无 ✓
- **自校验（实例数 vs 同一运行的 `area.rpt`）**：比对 80 个 cell，**全部一致 ✓**

## 功耗（逐 α 档）

| α（数据网） | P_sw | P_int | P_leak | **P_total** | P_int/P_sw |
|---:|---:|---:|---:|---:|---:|
| 0.10 | 13.3357 mW | 11.9730 mW | 6.7329 mW | **32.0417 mW** | 0.898 |
| 0.25 | 28.8835 mW | 12.6104 mW | 6.7329 mW | **48.2268 mW** | 0.437 |
| 0.50 | 54.7965 mW | 13.6725 mW | 6.7329 mW | **75.2020 mW** | 0.250 |

> 量级自检：P_int/P_sw = **0.898**（在 1e-3…1e3 内 ✓）。

## 能量指标（`E = P_total · cycles / f`）

| 指标 | cycles（来源） | α=0.10 | α=0.25 | α=0.50 |
|---|---:|---:|---:|---:|
| **energy/ECDH**（整核口径，含空闲块 ⇒ 高估） | 230376（帧数 × 每调用拍数，实测） | 59.053 µJ | 88.882 µJ | 138.598 µJ |

> `energy/协议阶段` 需要该阶段的 **OTBN 侧**拍数（现只有宿主 `HKEM_PROF` 口径 ✗）⇒ 待补。

## 误差与限制（必须同读）

1. **α 是假设不是实测** ⇒ 本报告 = vectorless 工具估计。**同一 α 档下的相对比较**有效 ✓；绝对值须标注为工具估计 ✗ 不得写成硅测/签核功耗。
2. **`internal_power` 取表中位值**：真实值依赖 (input slew, output load) 索引 ✗ ⇒ 近似；精确值需从 OpenSTA 逐实例导出 slew/load（未做）。
3. **不含互连线电容**（无 PEX ✗）⇒ 低估开关功耗；`P_leak` 为 typical 角单值（无温度/工艺角扫描 ✗）。
4. 整核口径把**空闲块**也按同一 α 计入 ⇒ 高估 `energy/ECDH`；fold 单独口径（L1）不受此影响 ✓。
5. **不做「少 cycle ⇒ 节能」的推断**（PDF §15.4 明令）⇒ 能量必须由本表的 P 与实测 cycles 相乘得到。

