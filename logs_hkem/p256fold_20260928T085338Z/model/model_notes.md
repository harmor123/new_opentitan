# P1 四句解释（§11 P1 通过条件：`⼯程负责⼈能解释 L≥2^256 、负 C 、 260-bit 范围和⼀次最终校正的原因`）

> 口径：全部 `[MODEL]`（附录 A 的分析模型；RTL 尚不存在）。每条都指到 `p256_fold_model.py` 的**具体断言/表达式**（行号按本 run 冻结件 `4d7d9c0b…`）。

## 1. 为什么 `L ≥ 2^256`

- **位拼接**：`mac()` 末尾 `low = (acc << 128) | ll` —— `L` 由 128 位 `LL` 与高部 `acc` 拼成，本身就在 2²⁵⁶ 量级；
- **合法域**：`assert 0 <= low < 3*N`（L69）——上界是 `3N`（`N = 2^256` 量级），所以 `L ≥ 2^256` 是**正常输入**，不是异常；
- **高部不是简单移位**：`split_raw()` 的 `return t, R256*t[0] - R320*t[1] - R384*t[2] + R448*t[3]`（L48）——高位以 **R256/R320/R384/R448 的带符号加权**进入 `C`，因此 `C` 会随 `high` 的取值出现**负值**（见第 2 条）。
- 佐证（本 run 实测）：`observed_product_ranges_not_exhaustive.L_max` = `374281068267899565195320000181521119346630982866649914172370543783726211894980`（≈ 2²⁵⁸ 量级）。

## 2. 为什么 `C` 会是负的

- `verify_algebra()` 给出**真实乘法 case 的精确极值**（L145-146）：
  - `cmin = -(B-1)*(R320+R384)`，`cmax = (B-1)*(R256+R448)`；
  - `assert -(1 << 289) < cmin < -(1 << 288)`（L147）⇒ **负下界确实存在**且需要 289+ 位；
  - `assert 1 << 288 < cmax < 1 << 289`（L148）⇒ 正上界同量级。
- 真实例子（`actual_reduced_operand_example_requiring_290_signed_bits`，本 run 实测非 `null`）：
  `a = 0xb1dd8570832f2ba75d4407eefdd26ffc06b6acc3a0252b8020454337b6bca789`、
  `b = 0xe10a814c2be74fcbe8cad87fb88c517d9f1a0c3db7a764495e9df71c139def11`（均 `< p`）、
  `C = -0x150853d792ca69260da153055cc7cc213f7135e8c82df0b0fb1a92d687814c57eb03e7ab0` ⇒ **原始 `C` 需要 290-bit signed**（不是 289，见 §0.3 失败条件②）。
- box corner 的另一组界：`assert -4*N < cpmin <= cpmax < 4*N`（L151，`cpmin/cpmax` 是独立 32-bit 字盒上的线性极值 ⇒ 预折叠 `C′` 的 259-bit）。

## 3. 为什么是 260-bit 范围

- 模型常量 `W = 260`、`MASKW = (1 << W) - 1`；
- 每一次加法都过 `checked_add()`：`assert -(1 << (W-1)) <= exact < (1 << (W-1))`（L36）——**用 `assert` 而不是让 Python 的无限精度掩盖溢出**（附录 A 原文）；
- 三个口径在 `algebra` 段分开自报（**不要混用**）：
  `raw_signed_width = 290`（原始 `C`）、`prefold_signed_width = 259`（预折叠 `C′`）、`accumulator_width = 260`（累加器 `W`）。
- 与 L0 的关系：`L0 = {ACC130, LL128}`，由 `assert L0 == low` 一致（Step 4 实测 `True`）。

## 4. 为什么只需要**一次**最终校正

- `quotient_fold()`（c19）先做两步断言：`assert -4 <= q <= 7`（L77）与 `assert -P < t < 2*P`（L79）
  ⇒ `t` 与 `[0, P)` 最多差一个 `±p`；
- `correction()`（c20）的注释逐字：`# One shared add/sub plus sign-controlled selection. No early exit.`（L82），随后
  `assert 0 <= result < P`（L85）与 `assert result == t % P`（L86）；
- 三类校正在真实输入上**都被触发过**（本 run：`add_p 8 / sub_p 39 / keep 20209`）⇒ "一次够"不是纸面结论，而是 20,256 组上的实测分类。

## 附：本阶段**不**下的结论（避免越界）

- `c15 ACC130` 的**最坏位宽**：`(p−1)²` 这一个用例只用到 64 bit ⇒ 位宽证据属 §6 端口契约与 P2 单元验证（本文件不下任何位宽数字）。
- `schedules.assumed_new_fetch_cycles = 1` 是**假设**（只有旧 wrapper 的 P0 实测支撑）；新指令的 1 拍必须在新 trace 上重测（P3/P4）。
- `projections`（30/24/22 → 373,026/315,414/296,210）自带 `analytical projection, not measurement` ⇒ 不得与 P0 的 RTL 实测（54 拍、603,474）写进同一个等式做收益相减。
