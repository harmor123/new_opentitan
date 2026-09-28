# P2 契约：位宽、采样点、接口与调度（Step 1 交付物）

> 单元：`hw/ip/otbn/rtl/otbn_p256_fold.sv`（本阶段新建）。依据：`contribution 2.pdf` §5、§6、§8、§10.2–§10.3。
> 口径：`[PDF]` = PDF 原文；`[P2]` = 本阶段自定（PDF 未规定或原文声明"不是已编译的端口定义"）。

## 1. 位宽与采样契约（Step 1）

| 项 | 约定 | 来源 |
|---|---|---|
| `F` | signed **260-bit** 累加器；每拍组合检查精确和落在 `[-2^259, 2^259)`（261 位精确和的最高两位相同） | [PDF] §5「采用 signed 260 bit」；§10.3 |
| `h0…h7` | **256-bit** 临时寄存器；`c9` 从 BN-MAC **当拍新结果**旁路采样；**不从 WDR 另开端口** | [PDF] §6 第 13 页 |
| `LL` | **128-bit**；`c12` 采样 MAC shift-out **低半字** | [PDF] §6 第 13 页 |
| `ACC130` | **≥130-bit**；`c15` 采 shift-out **之后** ACC 的更新值，**此后保持** | [PDF] §10.2 |
| `L0` | **258-bit** = `{ACC[129:0], LL[127:0]}`，整体零扩到 260 进 CPA；**绝不截断 `ACC[129:128]`** | [PDF] §6 第 14 页 |
| `k` / `x` | `c19` 时 `k = signed'(F[259:256])`、`x = F[255:0]`；该拍 operand mux 把 CPA 第一输入**从 F 切为 zero-extended x** | [PDF] §5 第 25–27 行；§6 第 13 页 |
| `k·d` | **12 项编译期常量 LUT**（`k = −4…7`，260-bit 二补码），不占 64×64 multiplier、不送回 BN-MAC；`k = −8…−5` 给安全默认值并由断言命中 | [PDF] §5 第 29–30 行；§10.3 |
| 校正 | `candidate = T ± p`（**第二输入**在 mux 里取 ±p，反相 + 进位）；`result = (T<0 \|\| candidate≥0) ? candidate : T`；**无需全宽比较器**；260-bit signed 加法，不用 unsigned borrow | [PDF] §5 第 33–38 行；§6 第 13 页 |
| 拼接方向 | 文档表是 `low-word-first`，与 SV `{high, ..., low}` **相反** | [PDF] §10.3 静态检查第 4 条 |
| 唯一加法器 | 全单元只有 1 个 260-bit CPA（加/减共享、第二输入反相）；无 barrel shifter；无新增通用 multiplier | [PDF] §6 第 14 页；§10.3 |

`P = 2^256 − 2^224 + 2^192 + 2^96 − 1`、`d = 2^256 − P` 由 `gen_kd_sv.py` 从模型生成并逐位自检；
`KD_xx` 常量写在 `.sv` 内（脚本生成、不手抄；`p2_rtl_emul.py` 会从 `.sv` 解析回来与模型现算比对）。

## 2. 端口清单（[P2]：PDF §10.2 明说"以下是逻辑接口需求，不是已编译的端口定义"）

| 端口 | 方向/宽度 | 语义 |
|---|---|---|
| `clk_i` / `rst_ni` | in | 时钟 / 异步复位（低有效）：复位清 `F/h/LL/ACC130/k/wd` |
| `start_i` | in | 一拍脉冲：本拍进入 `c0`；同时清上一次的全部暂存与提交标志 |
| `abort_i` | in | 错误/取消：清暂存、**抑制** wd 写回、立刻回 idle |
| `wipe_i` | in | 安全清理请求：清 `F/h/LL/ACC130`（P2 单元级；P7 的安全清理阶段另计拍） |
| `mac_result_pre_so_i` | in `[255:0]` | shift-out 选择**之前**的 MAC 加法器输出（当拍新结果） |
| `mac_acc_after_so_i` | in `[129:0]` | shift-out **之后** ACC 的更新值（c15 采） |
| `busy_o` / `cycle_o` | out / `[4:0]` | 运行中 / 当前周期号 `c0…c21`；未运行 = `5'd31` |
| `f_o` | out signed `[259:0]` | 当前 `F`（scoreboard 逐拍比对对象） |
| `h_o` `ll_o` `acc130_o` | out | `h0…h7` / `LL` / `ACC130`（供三条 off-by-one 断言读取） |
| `k_o` | out signed `[3:0]` | `c19` 的 k（位型 `0xc…0x7` = `−4…7`） |
| `wd_valid_o` / `wd_o` | out / `[255:0]` | `c21` 唯一写回脉冲 / 结果（`< p`） |

真实接入（P3，PDF §10.5）：`mac_result_pre_so` / `mac_acc_after_so` 两个 tap 在
`hw/ip/otbn/rtl/otbn_mac_bignum.sv:440`（`adder_result`）经 `:536`（`adder_result_blanked`）
与 `:545-547`（shift-out 三元式）导出；本阶段由 testbench 按固定周期注入。

## 3. 调度（[PDF] §8 表 c0…c21；与模型 `light()` 的 fold trace 同号同序）

| 周期 | MAC 列（§8） | 本单元动作 | 可用数据 |
|---|---|---|---|
| c0–c2 | 高部前 3 次乘 | idle | — |
| **c3** | `a3b0<<64`，shift-out 128 | `F ← H = {MAC[127:0], 128'b0}`（**直接 seed，不经 CPA**） | H |
| c4–c8 | 高部乘 | hold | — |
| **c9** | `a3b3<<128` | `h0…h7 ← mac_result_pre_so[255:0]` | 高部 256 位 |
| **c10** | `a0b0` | `F ← F + 2A` | |
| c11 | `a0b1<<64` | `F ← F + 2Bv` | |
| **c12** | `a1b0<<64`，shift-out 128 | `F ← F + P0`；`LL ← mac_result_pre_so[127:0]` | LL |
| c13 | `a0b2` | `F ← F + P1` | |
| c14 | `a1b1` | `F ← F − M0` | |
| **c15** | `a2b0` | `F ← F − M1`；`ACC130 ← mac_acc_after_so[129:0]` | ACC130（此后保持） |
| c16 | hold ACC | `F ← F − M2` | |
| c17 | hold ACC | `F ← F − M3` | `F = H + C′` |
| **c18** | hold ACC | `F ← F + L0`（258→260 零扩） | `R′` 就绪 |
| **c19** | idle | `k ← signed'(F[259:256])`；`F ← x + k·d`，`x = F[255:0]` | `−p < T < 2p` |
| **c20** | idle | 一次条件 `±p` | result 在 `F` 中就绪 |
| **c21** | idle / 清理 | 唯一 `wd` 写回（本单元不做 ISA 退休） | result 写回 |

**完成周期固定 = 22 拍**（`c0…c21`，不随输入值 / `k` / `correction` 分支变化；无早退）。
`c22 = ret`（取指气泡 `F′`）属 P3/P4，本单元不计。

## 4. 观测与比对约定（写 scoreboard 前必须先定死）

- §8 约定：「结果在该行周期末锁存，下一周期可用」⇒ 本单元的输出是**寄存器值**：
  周期 `c` 的运算结果在 `c` 的时钟沿锁存，`c+1` 拍起在 `F/h/LL/ACC130/k/wd` 上可见。
- 模型 fold trace 的 `cycle c` 记的是**该拍运算后的值** ⇒ 比对规则为
  **`RTL 输出(F)@c` == `model.F@c`**（同号同拍，无需平移）。
- 四个采样点的比对（Step 3 三条断言的正面）：
  `F@c3 == H`、`h@c9 == high`、`LL@c12 == LL`、`ACC130@c15 == ACC130`。
  反面（不得采到邻拍/旧值）由 testbench 用同一条向量的**相邻拍值**构造，例如
  `h@c9 != mac_result_pre_so@c8`、`h@c9 != acc_q@c8`、`F@c3 != (mac_result_pre_so[127:0]@c2) << 128`。
- **`inject` 向量的 `H` 驱动口径**（实测踩到过）：DUT 在 c3 取 `tap[127:0]` 再左移 128 得到 seed，
  而 `H` 的低 128 位恒为 0 ⇒ TB 必须把 **`H>>128`** 放进 tap 的 `word0..3`。
  若按 `tap = H` 驱动，seed 会恒为 0（本 run 实测：`15a_T_max` 的 tb@c3=0 而 model@c3≠0）。

### 4.1 比对范围的位宽口径（实测踩到过，必须写死）

- `F` 是 **260-bit signed**。向量表（生成头文件）按 9 个字（288 bit）存放，模型侧的**负值会符号扩展到
  `word8` 的高 28 位**；而 DUT 的 `f_o` 只承载 `bit[259:256]`，其余补 0。
- ⇒ **比较必须只比低 260 位**（`word0..7` 全比 + `word8` 只比低 4 位）。若按 9 字全比，
  **每个 `F<0` 的拍都会误判 DIFF**（本 run 实测：`model − tb ≡ 0 (mod 2^260)`，四个 DIFF 点差值全为 0）。
- `compare_to_model.py` 同样按 260 位掩码比较两边。

### 4.2 TB 的时钟纪律（实测；P3 必须复核）

- **必须先在低电平 `eval()` 一次让本拍输入传播到组合逻辑，再抬时钟沿**。
  实测：本流程下「由主输入经组合推导」的 flop 输入若与时钟沿在同一次 `eval` 里出现，会**晚一拍提交**
  （表现为：`start` 要点两次、每向量多补一个 tick、c3/c9/c12/c15 采到上一拍的 tap）。
- 证据链：`unit/otbn_tap_probe.sv` + `otbn_tap_probe_tb.cpp` 的结构分叉（端口→flop 直连＝同拍；
  端口→两级组合→flop＝晚一拍）与 TB 内 `TRACE` 块的逐拍标记（修好后 `PROBE` 报「延迟 0 拍」）。
- 该纪律属**仿真台/流程**，不是 RTL 语义：P3 接入真 BN-MAC 后必须用同一探针重新确认。

## 5. 静态检查四项的落实点（[PDF] §10.3）

1. **无 inferred latch**：全部次态在 `always_comb` 内先给默认值再覆盖；无 `unique case` 缺 `default`。
2. **无动态 barrel shifter**：行向量是按 32-bit 字索引的**常量位置拼接**；`2A/2Bv` 是常量 `<<1`。
3. **无新增通用 multiplier**：`k·d` 走 12 项常量 LUT；行累加只用 CPA。
4. **有符号 cast 与常量宽度显式**：`$signed(...)`、`W'(260'h…)`、`{{(W-AW-128){1'b0}}, …}` 全部显式写宽。

**断言形式**：模块内是 **14 条带标签的即时断言**（`A_xxx: assert (...) else $error(...)`，含三条 off-by-one 的**正面**）。
理由：Verilator 4.x 只稳支持即时/终值断言（`hw/ip/otbn/pre_dv/README.md`），并发断言宏还需
`prim_assert` + `+define+INC_ASSERT` ⇒ 本模块刻意不依赖这两者，单元构建只需编译 **2 个文件**。
三条 off-by-one 的**反面**（与邻拍比较）在 testbench 里做（RTL 看不见邻拍）。

## 6. P2 范围（不在本阶段判的）

- 不含完整性编码 / URND wiping / 安全清理阶段（§10.6，属 P7）；清理若需独立占拍按 §9 行 29–31 另计。
- 不判 `F′` 的位置与数量（§8 原文：必须由新 trace 确定）；不判 ISA 退休（§10.4，P3）。
- `CSA` 版（§8 第二张表）只在 P2 记录两项常量（补偿 `+4`、260 位反相不截断 256 位），不阻塞 P2。

## 7. 本契约的复现与预检（Windows 侧纯 py，可复跑）

```bash
cd "$run_dir/unit"                    # $run_dir = logs_hkem/p256fold_20260928T085338Z
export PYTHONUTF8=1                   # Windows 原生 Python 控制台为 GBK
python3 make_vectors.py               # 写 p2_vectors.json + 生成 otbn_p256_fold_vectors.h（TB 的编译期向量表）
python3 p2_rtl_emul.py --fuzz 400     # 逐句模拟 .sv 并与模型逐拍比对
```

判据：`mismatches: 0`（21 条向量 + 400 条随机）；`KD LUT 自检: OK`（`.sv` 内嵌常量 == 模型 `k·d`）；
`unique case 检查: OK`（块内标签唯一）。

### 7.1 单元 TB 的实测结果（本 run，Linux Verilator 4.210）

```text
PASS - 0 errors / 1114 checks
Test ***PASSED*** all 21 vectors
VECTORS: 21 run；完成周期（末拍 cycle_o）= c21，各向量一致
TIMING: start 重试合计 21 次（每向量 1 次）；补 tick 合计 0 次
ASSERT A_c3_H_no_off_by_one: PASS（反面被数据区分 20 次）
ASSERT A_c9_high_no_off_by_one: PASS（11 次）  ASSERT A_c12_LL_no_off_by_one: PASS（11 次）
ASSERT A_L0_truncated_must_differ: PASS（ACC130[129:128]≠0 的向量 6 条，截断全部改变结果）
STEP7 abort_mid_run(c14) / reset_mid_run(c8) / reset_then_rerun / wipe_idle / two_runs_no_stale：全 PASS
```
scoreboard：`逐拍行 286；mismatches: 0；日志 model 列不符 0；标记不符 0；缺失 0`。

### 7.2 诊断件（保留在 `run_dir/unit/`，可复跑）

| 文件 | 用途 |
|---|---|
| `otbn_tap_probe.sv` / `otbn_tap_probe_tb.cpp` | 三条结构路径的锁存时序分叉实验（判定「哪条结构晚一拍」） |
| TB 内 `LAYOUT` / `TRACE` / `PROBE` 行 | 端口地址布局；本体逐拍标记；测得的 tap 呈现→采样延迟 |
| `tap_probe.log` | 探针运行的原始输出 |

复跑探针：

```bash
cd "$repo_root"
verilator --cc --exe --build --trace --assert -Wno-WIDTH -Wno-UNOPTFLAT \
  --Mdir "$run_dir/unit/obj_dir/probe" --top-module otbn_tap_probe \
  "$run_dir/unit/otbn_tap_probe.sv" "$run_dir/unit/otbn_tap_probe_tb.cpp" -o otbn_tap_probe_tb
cd "$run_dir/unit" && "$run_dir/unit/obj_dir/probe/otbn_tap_probe_tb" | tee "$run_dir/unit/tap_probe.log"
```
**注意**：`p2_rtl_emul.py` 检查的是「SV 源码语义 vs 模型」；RTL 判定仍以 Verilator 单模块 testbench 为准：

```bash
# 单元构建（模块无外部依赖 ⇒ 只编 2 个文件；TB 的向量表来自生成头文件，与 TB 同目录）
# ⚠ 源文件写绝对路径：生成的 Makefile 在 --Mdir 里由 make -C 执行，相对路径会解析失败
cd "$repo_root"
mk="$run_dir/unit/obj_dir"
verilator --cc --exe --build --trace --assert -Wno-WIDTH -Wno-UNOPTFLAT \
  --Mdir "$mk" --top-module otbn_p256_fold \
  "$repo_root/hw/ip/otbn/rtl/otbn_p256_fold.sv" \
  "$repo_root/hw/ip/otbn/pre_dv/otbn_p256_fold_tb.cpp" \
  -o otbn_p256_fold_tb
cd "$run_dir/unit" && "$mk/otbn_p256_fold_tb" | tee "$run_dir/unit/p2_inject.log"  # PASS - 0 errors / N checks
python3 "$run_dir/unit/compare_to_model.py" --tb-log "$run_dir/unit/p2_inject.log" \
  --model "$run_dir/unit/p2_vectors.json" --out "$run_dir/unit/p2_diff.md"   # 判据：0 mismatches
```
