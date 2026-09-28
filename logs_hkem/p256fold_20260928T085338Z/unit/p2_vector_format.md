# P2 向量格式、字节序与位宽（Step 9 交付物）

> 依据：`contribution 2.pdf` §11 P2「把 Python 结果转换为项目已有的向量格式或 scoreboard 输入，记录**格式、字节序和位宽**」。
> 本文件同时是 **P3/P4 复用口径**：30/24 拍的对照必须继续用同一格式（换格式就无法与 P2 比较）。

## 1. 文件与字段

| 文件 | 生成者 | 用途 |
|---|---|---|
| `$run_dir/unit/p2_vectors.json` | `make_vectors.py` | 人读与工具用：21 条向量、逐拍 `F`、16 拍 tap、四采样值、`result` 与截断变体 |
| `hw/ip/otbn/pre_dv/otbn_p256_fold_vectors.h` | 同上（**自动生成，勿手改**） | testbench 的**编译期向量表**（TB 不解析 JSON、无运行时文件依赖） |
| `$run_dir/unit/p2_inject.log` | TB 运行输出（`tee`） | Step 8 的 scoreboard 输入 |

### JSON 字段（每条向量）

| 字段 | 含义 |
|---|---|
| `name` / `covers` | 向量名 / 对应的 §11 P2 必测项 |
| `source` | `"mac"` = 16 步真实乘法序列派生；`"inject"` = 直接注入四采样 |
| `a` / `b` | 输入操作数（`inject` 向量为 `null`，它不来自乘积） |
| `H` | c3 采的 seed（= `{MAC[127:0], 128'b0}`，**低 128 位恒为 0**） |
| `high` | c9 采的 256-bit 高部（`h0…h7`） |
| `LL` / `ACC130` / `L0` | c12 采的 128-bit / c15 采的 ≥130-bit / 拼接后的 258-bit（三者满足 `L0 == (ACC130 << 128) \| LL`） |
| `h[8]` | `high` 的 8 个 32-bit 字（模型口径，`h[i]` = bits `[32i+31:32i]`） |
| `R` / `T` / `q` / `result` | c18 末的 `R′` / c19 的 `T` / 小商 `k` / 最终结果（`< p`） |
| `mac_taps.pre_so[16]` | 16 拍 MAC **shift-out 前**的加法器输出（`mac_result_pre_so_i`） |
| `mac_taps.acc_after[16]` | 16 拍 **shift-out 后** ACC 的更新值（`mac_acc_after_so_i`） |
| `fold_F` | 模型 fold trace 的逐拍 `F`（键 = 周期号，13 拍：`c3` + `c10…c21`） |
| `result_trunc` / `trunc_differs` / `acc130_hi_nonzero` | Step 4 的截断失败用例口径（见 §6） |
| `completion_cycles` | 固定完成周期 = **22**（`c0…c21`） |

## 2. 字节序与拼接方向

- **JSON**：整数值一律写成十六进制字符串 `0x…`（大端书写，表示整数本身）；模型里的负值写作 `-0x…`。
- **生成的 C++ 头**：`uint32_t[9]`，**低字在前**（`word i` 覆盖 `bit[32i+31:32i]`）——与 Verilator 4.x 对宽信号的打包一致；测试台读 DUT 的宽端口用同一约定（`reinterpret_cast<uint32_t *>`）。
- **SV 拼接**：`{high, ..., low}`，与 PDF 表格的 **low-word-first** **相反**（§10.3 静态检查第 4 条）。`LANES` 表里 `None` = 零字。
- **负值表示**：`F` 是 260-bit signed。测试台打印的是**二补码位型**（`0x…`，不带负号）；scoreboard 对两边都做 **260 位掩码**后再比（掩码后与有符号值一一对应）。

## 3. 位宽表

| 项 | 位宽 | 说明 |
|---|---|---|
| `a` / `b` | 256 | 操作数（`0 ≤ a,b < 2^256`，§10.1） |
| `H` | 256（有效 128） | `{MAC[127:0], 128'b0}` |
| `high` / `h0…h7` | 256 | c9 当拍 MAC 新结果 |
| `LL` | 128 | c12 shift-out 前低半字 |
| `ACC130` / `mac_acc_after_so` | 130 | c15 后保持不变；130 位是 `low < 4N` 的直接后果 |
| `L0` | 258 | `{ACC[129:0], LL[127:0]}`，进 CPA 前**零扩**到 260，**绝不截断 `ACC[129:128]`** |
| `F` | 260 signed | 累加器；`c19` 的第一输入切为 `x = F[255:0]` |
| `KD` | 260 × 12 | `k = −4…7` 的 `k·d` 常量 LUT |
| `mac_result_pre_so` | 256 | shift-out **前**的加法器输出 |
| `result` / `wd` | 256（值 `< p`） | 写回值 |

## 4. 周期号

| 项 | 值 |
|---|---|
| 四个采样周期 | `c3`（H）/ `c9`（high）/ `c12`（LL）/ `c15`（ACC130） |
| fold 逐拍 | `c3`、`c10…c21`（共 13 拍） |
| 完成周期 | **22**（`c0…c21`，固定，不随输入/`k`/校正分支变化） |

## 5. 两类向量的语义（对应 PDF 的两步顺序）

- `source="mac"`（17 条）：按 §8 的 MAC 列逐拍喂 16 拍 tap（先 `pre_so` 后 `acc_after` 与模型 `mac()` 同构）⇒ **Step 5** 用。
- `source="inject"`（4 条）：只给四个采样拍，其余拍为 0 ⇒ **Step 2** 用。`k = −4`、`T` 极值**只在**这类向量上可达（真实 `(a,b) < p` 的乘积覆盖不到 `k = −4`，与模型 `verify_algebra()` 的独立字盒口径一致）。

## 6. `L0` 截断失败用例的口径（Step 4）

- `result_trunc`：把 `L0` 截成 `{ACC[127:0], LL[127:0]}` 后**在模型侧重算**的 fold 结果；重算若越界（模型断言失败）也记为"必然出错"。
- `trunc_differs = 1` ⇒ 截断会改变结果 ⇒ 该向量对 Step 4 有判别力。
- **DUT 本身不做修改**（不提供"截断模式"）：判别力是**数据侧**的事实，测试台据此断言
  「`ACC130[129:128] ≠ 0` 的向量必须 `trunc_differs = 1`」且「`result ≠ result_trunc`」。
- 实测（本 run）：21 条中 `ACC130[129:128] ≠ 0` 的 **6** 条，其 `trunc_differs` **全部为 1**（用例有效）。

## 7. 来源与哈希（跨平台口径）

- 生成脚本 / JSON / 头文件 / RTL / TB 的 sha256 见 `$run_dir/unit/frozen_files_p2.sha256`：用
  `git cat-file blob HEAD:<path> | sha256sum` 产出 ⇒ **与平台无关**（Windows 工作树是 CRLF、blob 是 LF）。
- 模型脚本 `$run_dir/model/p256_fold_model.py` 的 **sha256(LF)** = `704fce705660f2d48550d8442d09613c1aed84d33b81e3a87a3b8a2f49a0dbec`（JSON 字段 `model_sha256_lf`）。
- ⚠ 口径说明：`baseline/frozen_files.sha256` 里 P1 记录的 `4d7d9c0b…` 是**模型文件的 Windows CRLF 渲染**（不可跨平台复现）；其 blob（LF）口径为上面的 `704fce70…`。P2 已把该行修正为 blob 口径，并按同一口径在脚本里记录 `model_sha256_lf`。

## 8. 复现

```bash
cd "$run_dir/unit"
export PYTHONUTF8=1                     # Windows 原生 Python 控制台为 GBK；Linux 可省
python3 make_vectors.py                 # 写 p2_vectors.json + 生成 otbn_p256_fold_vectors.h（编译期向量表）
python3 p2_rtl_emul.py --fuzz 400       # SV 语义预检（判据：mismatches: 0）
```

TB 与 scoreboard 的命令见 `03_P2_FoldUnit与微序列验证.md` 的 Step 2 / Step 5 / Step 8。

## 9. 给 P3/P4 的约束

- 四采样周期号（`3/9/12/15`）、`L0` 拼接方向、`F` 的 260-bit signed 口径、`result` 的 `< p` 口径**不得改动**；
- 30/24 拍的分析只允许改**调度与周期号**，不允许改向量的数值口径与字段含义。
