# 测量工具与版本（实测汇总）

> 仓库副本：与 `md文档/p256方案20260927/工具与版本_实测.md` 同源；外部证据路径见文内。

> 记录日期：2026-11-12  
> 用途：支撑论文中 chip-sim、Ibex 计时、ISS、主机固件编译、Yosys/OpenROAD/OpenSTA PPA 等段落的工具与口径核对。  
> 说明：本文件只列**可复核的文件与命令**；不记录实验过程中的错误尝试。

## 1. 仿真与软件工具

| 工具 | 版本 | 证据 / 路径 |
|---|---|---|
| Verilator | **4.210**（2021-07-07，rev v4.210） | `logs_hkem/p256fold_20260928T085338Z/run_manifest.json` → `simulator.version`；`step5_chip.log` → “found 4.210; needed 4.210”；`/tools/verilator/4.210/bin/verilator --version` |
| 默认系统 Verilator | 4.038（**不要用**） | `/usr/bin/verilator --version` = `Verilator 4.038 2020-07-11 rev v4.036-114-g0cd4a57ad` |
| Bazel | Bazelisk v1.24.1（Build label 8.7.0） | `run_manifest.json` → `toolchain.bazel` |
| Python | 3.10.12 | `run_manifest.json` → `toolchain.python` |
| 设备工具链 | **lowRISC clang 21.1.8**（`riscv32-unknown-elf-clang`，LLVM commit `e5b282fd2541f3d1eb56b5b796b31aae3e37a293`） | Bazel external：`.../external/+lowrisc_rv32imcb_toolchain+lowrisc_rv32imcb_toolchain/bin/riscv32-unknown-elf-clang --version`；`lib/clang/21/include` |
| 主机固件编译选项 | **`-flto -Oz`**（另有 `-ffreestanding`） | `offload_followup_20261009_1410/deliverables/logs/build_B.log` 的实际编译命令行；`deliverables/method_and_limits.md` 亦写明生产优化选项 `-Oz -flto -ffreestanding` |
| Ibex 周期计数器 | `ibex_mcycle_read()` | `sw/device/lib/testing/profile.c:10`；`profile_start()` / `profile_end()` |
| OTBN ISS | `hw/ip/otbn/dv/otbnsim`；功能 KAT 走 `otbn_sim_test` | `test_perf/harness.py`（指令级剖面）；`hw/ip/otbn/dv/otbnsim` |
| Chip sim | OpenTitan Earlgrey `Vchip_sim_tb` + `opentitantool` | `test_hybrid_kem_otbn_prompt_ver*/..._sim_verilator.bash.runfiles/_main`；日志中的 `Invoking test: ... --interface=verilator` |

### Verilator 4.210 的激活方式

`opentitan-env` 是 `~/.bashrc` 里的函数（约 `~/.bashrc:121-137`），交互 shell 中执行：

```bash
cd ~/new_pqc/opentitan
opentitan-env          # 打印 OpenTitan environment ready (Verilator 4.210)
verilator --version    # 期望：Verilator 4.210 2021-07-07 rev v4.210
```

> 非交互 SSH 不会加载 `.bashrc` 的函数；此时 `type opentitan-env` 会报 not found，且 `verilator` 仍是 `/usr/bin/verilator` 4.038。  
> 如果只需版本核对，可直接运行 `/tools/verilator/4.210/bin/verilator --version`。

### 主机固件实际编译命令的证据

```bash
grep -n -- '-flto' \
  ~/new_pqc/contribution3_pilot_20261004_2140/offload_followup_20261009_1410/deliverables/logs/build_B.log
```

该行同时包含：

- `external/+lowrisc_rv32imcb_toolchain+lowrisc_rv32imcb_toolchain/bin/riscv32-unknown-elf-clang`
- `-isystem .../lib/clang/21/include`
- `-flto -Oz -mllvm '--inline-threshold=10'`

因此 `lowRISC Clang 21.1.8 + -Oz + LTO` 有直接编译命令证据；Bazel 输出路径里的 `k8-fastbuild` 只是配置名，不代表没有这两个 flag。

## 2. PPA 工具与条件

| 工具 / 条件 | 版本 / 取值 | 证据 |
|---|---|---|
| Yosys | **0.64+341**（git sha1 `cc9692caa`，Release，GNU c++ 11.4.0） | `logs_hkem/p256fold_20260928T085338Z/ppa/syn_conditions.txt`；`yosys -V` |
| sv2v | **v0.0.13-11-g6662fa5** | `syn_conditions.txt`；`sv2v --version` |
| OpenROAD | **v2.0-17598-ga008522d8** | `postcts_evaluation_20261009_1010/H1/hold_repair/openroad.log:1`；`period_scan/H1/14.000ns/openroad.log:1`；`tools/run_openroad.sh` 最后一行 `exec .../tools/openroad/usr/bin/openroad` |
| OpenSTA | 独立 `sta` = 2.0.17；post-CTS 评价用 **pinned OpenSTA**（OpenROAD 内置 STA） | `delivery_v5/hardware_comparison.csv:2` → `tool = OpenROAD 2.0-17598-ga008522d8 / pinned OpenSTA`；`/usr/bin/sta -version` = 2.0.17 |
| 标准单元库 | Nangate45 `NangateOpenCellLibrary_typical.lib`，SHA256 `8d540a4d4cf6d09d27c87ad067857a9c0c2eeb023ab7a56e058cd3113db4e9b1` | `reports/ppa.json`；`postcts_evaluation.../deliverables/evidence_manifest.json` |
| 工艺角 | **typical / 1.10 V / 25 °C** | `reports/ppa.json`；`constraints_and_assumptions.md`；`p7_energy_*.md`（liberty 头 `nom_voltage=1.10`、`nom_temperature=25.00`） |
| 共同时钟约束 | **14.000 ns（71.428571 MHz）** | `postcts_evaluation.../deliverables/period_scan.csv` 的 H0/H1 `14.0` 行；`hardware_evaluation_summary.md` |
| 10 ns 目标 | H0 setup WNS −3.524828 ns、H1 −3.643989 ns（**失败，不能声称 100 MHz**） | `period_scan.csv` 的 `10.0` 行；`hardware_evaluation_summary.md` |
| 14 ns 结果 | H0 setup WNS **+0.475172 ns**、hold WNS **+0.000836 ns**；H1 setup WNS **+0.356009 ns**、hold WNS **+0.000704 ns**；slew/cap/pulse 违例均为 0 | `period_scan.csv`；`period_scan/H*/14.000ns/setup_wns.rpt`、`hold_wns.rpt` |
| Post-CTS 面积 | H0 **398,676.544001 µm²**；H1 **417,108.216001 µm²**；增加 **18,431.672000 µm² = 4.623215%**（约 4.62%） | `hardware_evaluation_summary.md`；`hardware_comparison.csv`（post-CTS 行） |
| 面积/时序边界 | 顶层 `otbn_core`；外部 IMEM/DMEM SRAM 宏及外围**不在面积和时序边界内**；Ibex、KMAC 在 `otbn_core` 之外 | `evidence_manifest.json` → `"scope": "post-CTS fixed otbn_core, placement RC, Nangate45 typical, no SRAM macro/peripheral"`；`hardware/H1/post/summary.json` → `memory_macros_included: false` |

### 流程与口径

- 综合：Yosys 把冻结 RTL 映射为 `H0/mapped.v`、`H1/mapped.v`；`hardware/H1/post/summary.json` 的 `netlist` 指向 `pre_syn/syn_out/.../otbn_core_netlist.sta.v`。
- 物理：OpenROAD 执行 floorplan、global/detailed placement、**clock-tree synthesis**；`scripts/15_physical_flow.tcl:66-98` 可见 `initialize_floorplan`、`global_placement`、`detailed_placement`、`clock_tree_synthesis`、`estimate_parasitics -placement`。
- 时序：post-CTS 数据库 + `set_propagated_clock` + **placement RC**；`scan_point.tcl:6-24` 用 `read_liberty`、`read_db`、`read_sdc`、`estimate_parasitics -placement`、`report_checks`、`report_worst_slack`、`report_tns`、`report_check_types`。
- 关键限制：**没有 global-route/detailed-route 寄生提取（无 SPEF）**；14 ns 是固定 post-CTS 实现上的共同评价点，**不是 routed Fmax 或实际芯片频率**；reset release 未签核。见 `constraints_and_assumptions.md`、`hardware_evaluation_summary.md`。

## 3. 与论文句子的对应

| 论文句子 | 证据 |
|---|---|
| Verilator 4.210 | `run_manifest.json`；`/tools/verilator/4.210/bin/verilator` |
| OTBN cycles 来自 RTL traces；host cycles 来自 Ibex counter | `run_manifest.tracer.script = rtl_trace_attr.py`；`profile.c:10` |
| ISS 用于功能检查和指令级剖面 | `test_perf/harness.py`；`hw/ip/otbn/dv/otbnsim`；`otbn_sim_test` |
| lowRISC Clang 21.1.8 + `-Oz` + LTO | `build_B.log` 实际编译命令；工具链版本 21.1.8 |
| `phase_elapsed` 连续 Ibex 区间；`protocol_total` 非重叠段之和 | `repo/contribution3_matrix_p/p_common.h:74`；`16_accept_host.py` / `accept_stage.py` 的 note |
| phase 包含 app loading 与 cleanup | `phase_elapsed` note；`HKEM_PROFILE` 的 `*_load`、`wipe_after_*` 段 |
| 相同输入/时间边界 | `paired_comparisons.csv`、`prepare_A.py`；同一 phase/input_id |
| 功能正确性对参考输出 | `PASS`/`CHECK_ARRAYS_EQ`/`reused_application_inputs.json` |
| ML-KEM invalid-ciphertext、Fold、reset/abort/load | `fold_correctness_audit.md`（8 个 Decaps ISS：有效输入 + `ct[544]/ct[1087]` 翻转 + 非零 z；P2 abort c14/reset c8；P3 serial abort c20）；`reused_application_inputs.json` 的 `invalid_ciphertext_nonzero_z` |
| Yosys + OpenROAD placement/CTS + OpenSTA | 本节第 2 部分；`hardware_evaluation_summary.md`、`openroad.log`、`scan_point.tcl` |
| Nangate45 typical 1.10 V / 25 °C、共同 14 ns | `constraints_and_assumptions.md`、`period_scan.csv` |
| post-CTS 标准单元面积/时序、placement RC | `hardware_evaluation_summary.md`、`constraints_and_assumptions.md`、`period_scan/H*/14.000ns/` |
| 面积排除 SRAM/Ibex/KMAC | `evidence_manifest.json` 的 scope；`hardware/H1/post/summary.json` 的 `memory_macros_included: false` |

## 4. 证据目录

### 4.1 P-256 Fold 旧 PPA（Yosys + OpenSTA、8 ns）

```text
logs_hkem/p256fold_20260928T085338Z/
├── run_manifest.json
├── ppa/syn_conditions.txt
├── ppa/constraints.sdc
├── reports/ppa.csv
├── reports/ppa.json
└── reports/p7_energy_*.md
```

用途：早期 P-256 Fold 消融（A0/A1/B0/B1/L1）的 Yosys 面积与 OpenSTA 时序；**不是**论文那段 post-CTS/14 ns 数据的来源，避免混用。

### 4.2 Post-CTS 硬件评价（论文 PPA 句子的来源）

```text
~/new_pqc/contribution3_pilot_20261004_2140/paper_supplement_20261008_153149/
└── timing_validation_20261008_2335/
    ├── scripts/15_physical_flow.tcl          # OpenROAD placement/CTS/route/extract
    ├── delivery_v5/hardware_comparison.csv   # 显式 tool = OpenROAD ... / pinned OpenSTA
    └── postcts_evaluation_20261009_1010/
        ├── scan_point.tcl                    # OpenSTA 时序命令
        ├── deliverables/hardware_evaluation_summary.md
        ├── deliverables/constraints_and_assumptions.md
        ├── deliverables/period_scan.csv
        ├── deliverables/hardware_comparison.csv
        ├── deliverables/evidence_manifest.json
        ├── H1/hold_repair/openroad.log       # OpenROAD 版本
        └── period_scan/H1/14.000ns/          # setup/hold/slew/cap/pulse 报告
```

### 4.3 主机固件编译与测试

```text
~/new_pqc/contribution3_pilot_20261004_2140/offload_followup_20261009_1410/
└── deliverables/
    ├── logs/build_B.log                      # 实际 clang 命令行（-flto -Oz）
    └── method_and_limits.md

~/new_pqc/contribution3_pilot_20261004_2140/paper_supplement_20261008_153149/
└── deliverables/fold_correctness_audit.md    # Fold/abort/reset/wipe/Decaps ISS 覆盖
```

## 5. 复现命令

### 5.1 工具版本

```bash
# Verilator 4.210（交互 shell）
cd ~/new_pqc/opentitan
opentitan-env
verilator --version

# 或直接查绝对路径
/tools/verilator/4.210/bin/verilator --version

# Yosys / sv2v / 独立 OpenSTA
yosys -V
sv2v --version
sta -version

# OpenROAD（工程内 wrapper）
~/new_pqc/contribution3_pilot_20261004_2140/paper_supplement_20261008_153149/timing_validation_20261008_2335/tools/run_openroad.sh -version
```

### 5.2 主机固件编译选项

```bash
grep -n -- '-flto' \
  ~/new_pqc/contribution3_pilot_20261004_2140/offload_followup_20261009_1410/deliverables/logs/build_B.log
```

### 5.3 Post-CTS 面积/时序

```bash
B=~/new_pqc/contribution3_pilot_20261004_2140/paper_supplement_20261008_153149/timing_validation_20261008_2335

# 汇总
cat "$B/postcts_evaluation_20261009_1010/deliverables/hardware_evaluation_summary.md"

# 14 ns 扫描点
grep -E '^H[01],14\.0,' "$B/postcts_evaluation_20261009_1010/deliverables/period_scan.csv"

# OpenROAD/OpenSTA 证据
head -1 "$B/postcts_evaluation_20261009_1010/period_scan/H1/14.000ns/openroad.log"
sed -n '1,30p' "$B/postcts_evaluation_20261009_1010/scan_point.tcl"
sed -n '1,3p' "$B/delivery_v5/hardware_comparison.csv"

# 14 ns 报告
cat "$B/postcts_evaluation_20261009_1010/period_scan/H1/14.000ns/setup_wns.rpt"
cat "$B/postcts_evaluation_20261009_1010/period_scan/H1/14.000ns/hold_wns.rpt"
```

## 6. 不要误读的四条

1. **14 ns 不是 Fmax**：它是固定 post-CTS 实现上的共同评价点；`hardware_evaluation_summary.md` 明确写“不是路由后 Fmax 或实际芯片频率”。
2. **placement RC 不是 SPEF**：`constraints_and_assumptions.md` 明确“没有 global-route/详细布线寄生提取”；论文写“placement-based parasitic estimates”才准确。
3. **post-CTS 面积不是 route 后面积**：面积是 post-CTS 数据库的单元面积；不要写成 post-route/layout 面积。
4. **两套 PPA 不要混用**：`logs_hkem/p256fold_20260928T085338Z` 是早期 Yosys + OpenSTA、8 ns 的消融数据；论文的 post-CTS/14 ns/4.62% 来自 `postcts_evaluation_20261009_1010`。
