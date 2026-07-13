# Hybrid KEM OTBN 性能测试框架

基于 OTBN ISS (`standalone.py --verbose`) 精确测量 ver0/ver1/ver2 三个版本的
周期数、指令数、代码尺寸、指令分布等指标，存入 SQLite，支持横向版本对比和纵向历史趋势。

## 原理

```
config.yaml → main.py
                ├─ bazel build <target>          → ELF
                ├─ standalone.py --verbose <elf> → trace (PC | instr | regs)
                ├─ collector.py                  → 提取 cycles/insn/stall + IMEM/DMEM + 指令分布
                ├─ db_manager.py                 → SQLite 存储 (db/ 目录)
                └─ analyzer.py                   → 8 维度报告 + 柱状图
```

## 快速开始

```bash
cd test_perf && pip install -r requirements.txt

# 单模块验证
python main.py run --versions ver0 --tests sha3

# 全量 3×7=21 测试
python main.py run

# 按需过滤
python main.py run --tests sha3,mlkem_keypair          # 只跑两个
python main.py run -V ver0,ver2 -t p256                 # 两个版本的 P-256

# 指定数据库
python main.py run --db db/my_bench.db --tests sha3

# 报告 & 图表
python main.py report                    # 最新横向对比 (可选 -o report.txt)
python main.py history --version ver0    # ver0 历史趋势

# 数据管理
python main.py delete --id 5
python main.py delete --version ver0 --before 2026-01-01
```

### 全流程
```bash
rm -rf test_perf/__pycache__ hw/ip/otbn/dv/otbnsim/sim/__pycache__
rm -f test_perf/db/v0_full_1.db
python test_perf/main.py run --db test_perf/db/v0_full_1.db
python test_perf/main.py report --db test_perf/db/v0_full_1.db -o test_perf/report_full_1.txt
```
命令行支持任意目录执行，db/logs 始终在 `test_perf/` 下生成。

## 采集指标 (8 维度)

| # | 指标 | 单位 | 意义 | 来源 |
|---|------|------|------|------|
| [1] | **周期数 & 指令数** | cycles / 条 | 核心性能指标。越低越快。ver0 SW 数万 cycles，ver1/2 KMAC 仅数千 | trace: `INSN_CNT` + 数 `(stall)` |
| [2] | **Stall & IPC** | cycles / % / ratio | Stall 低 = 流水线利用好；IPC 越接近 1 越高效 | stalls = 统计行数, IPC = insn/cycles |
| [2.5] | **代码尺寸** | bytes | IMEM 大 = 代码多；DMEM 大 = 缓冲区多。资源受限芯片关键指标 | `readelf -S` .text/.data/.bss |
| [3] | **各阶段占比** | % | 定位瓶颈：哪个操作占时间最多，优化优先级 | 各操作 cycles / 总 cycles |
| [4] | **分组汇总** | cycles / % | Hash/KDF/ECDH/KEM 各自占比，看系统级瓶颈 | 按 OP_GROUPS 合并统计 |
| [5] | **加速比 vs ver0** | × / % | ver1/2 相对纯软件的提升倍数。>1.0 即加速 | speedup = base/target |
| [6] | **吞吐量 @100MHz** | ops/sec | 每秒能执行多少次操作。越高越好 | 100M / cycles |
| [7] | **Top-10 指令明细** | 条 / % | 最热指令。bn.rshi/xor 占大头 = Keccak 密集；csrrs 多 = KMAC 轮询 | trace 指令名统计 |
| [8] | **指令类别分布** | 条 / % | 宏观视角：BN ALU 多 = 软件算法；Ctrl Flow 多 = 硬件驱动 | 68 条 OTBN 指令 → 10 大类，按版本汇总 |
| [9] | **函数调用热点** | × / 函数名 | 最热函数。`_ensure_digest` 多 = KMAC 轮询；`mul_modp` 多 = P-256 密集型 | ISS 函数调用统计 |
| [10] | **掩码 vs 非掩码对比** | Δ cycles / Δ% | DOM 掩码的**真实性能代价**。自动配对 `verX`↔`verX_masked`，无 masked 数据时自动跳过 | `analyer.py` 自动检测 `_masked` 后缀 |

### 代码尺寸影响因素

IMEM (.text) 取决于汇编代码行数和函数数量：
- SW SHA3 (`sha3_shake.s`) — Keccak-f 完整实现，约 2000B
- KMAC 驱动 (`kmac_sha3_template.s`) — 硬件寄存器操作，约 1300B
- HMAC (`hmac.s` / `hmac_sha3.s`) — 密钥处理 + 内外哈希，约 500B
- HKDF (`hkdf_sha3_256.s`) — Extract + Expand 逻辑，约 500B
- ML-KEM — NTT/intt/basemul/CBD/poly/pack 等 11 个模块，约 8-12KB
- P-256 — scalar_mult + proj_to_affine + is_on_curve，约 3-5KB

DMEM (.data) 取决于常量表和 I/O 缓冲区：
- SW SHA3: `rc`(768B 对齐) + `context`(212B) + `ipad/opad/key_buf`(~600B)
- KMAC SHA3: `hmac_ipad/opad`(160B×2) + `const_0x36/0x5c`(160B×2) + `hmac_inner/key_hashed`(32B×2)
- HKDF 额外: `ikm_buf`(1024B) + `output_okm`(256B) + `input_salt/ikm_prebuilt/info` 等
- ML-KEM 额外: `ek`(1184B) + `dk`(2400B) + `ct`(1088B) + `ss`(32B) + `coins`(64B) + `twiddles`(约2KB) 等
- P-256 额外: `d0/d1`(64B×2) + `x/y`(32B×2) + `modulus`(32B) 等

DMEM (.bss) 中的栈大小：
- 各测试文件定义 `.zero N` 作为 `stack`，通常 512B~20000B
- `.bss` 段计入 DMEM 总大小（`readelf -S` 累加 .data + .bss）
- 栈越大 → DMEM 越大。但不是性能瓶颈：OTBN 有 127KB+1KB DMEM，够用即可
- co_sim 脚本不需栈（直接 `--load-elf`），ISS 测试需栈用于 jal/ret


## 目录

```
test_perf/
├── README.md
├── config.yaml          # 版本路径 + bazel targets
├── main.py              # 主入口: run/report/history/delete/plot
├── collector.py         # 指标采集: trace 解析 + ELF 尺寸 + 指令分类
├── db_manager.py        # SQLite: 建表/增删查 (级联删除)
├── analyzer.py          # 8 维度对比报告 + 柱状图 (双图)
├── requirements.txt     # pyyaml
├── kyber_py/            # ML-KEM Python 参考实现
├── db/                  # SQLite 数据库 (自动创建)
└── logs/                # 原始运行日志 (自动创建)
```

## 配置文件

```yaml
versions:
  - name: "ver2"
    label: "硬件加速"
    targets:                          # bazel otbn_binary 目标
      sha3:  "//test_hybrid_kem_otbn_prompt_ver2/otbn/hkdf:sha3_test_bin"
      ...
    tests: [sha3, hmac, hkdf, p256, mlkem_keypair, mlkem_encap, mlkem_decap]

  # 掩码变体: 通过 env 注入 OTBN_EN_MASKING=1 → DOM Keccak (97cy) + URND squeeze
  - name: "ver2_masked"
    label: "硬件加速 (masked)"
    env:
      OTBN_EN_MASKING: "1"            # 任意环境变量，ISS 读取
    targets:                          # 与 unmasked 共享相同 targets
      sha3:  "//test_hybrid_kem_otbn_prompt_ver2/otbn/hkdf:sha3_test_bin"
      ...
    tests: [sha3, hmac, hkdf, p256, mlkem_keypair, mlkem_encap, mlkem_decap]

timeout: 120
database: "db/perf_results.db"
```

增加新版本只需追加一项。`env` 字段可选，用于注入 ISS 运行时的环境变量。

## 命令一览

| 命令 | 说明 |
|------|------|
| `run` | 运行测试，每次跑一次（ISS 确定）。`-V` 版本, `-t` 测试, `--db` 指定库 |
| `run -V ver2,ver2_masked` | 同一版本跑 unmasked + masked，一键对比 |
| `report` | 最新横向对比报告（10 维度）。`-o report.txt` 保存纯文本 |
| `history -v ver0` | ver0 全部历史，每次 cycle/instr 变化 |
| `delete --id N` | 删除指定记录（级联删除指标） |
| `delete -v ver0 --before 2026-01-01` | 删除历史数据 |

## 注意事项

- **`ver2_masked` 修复**: `main.py` 中 `"ver2" in ver["name"]`（而非 `==`）确保 masked 版本正确加载 ver2 指令集（`insns-ver2.yml`）。若新增 `verX_masked` 变体，确认 `bnv` 赋值逻辑正确。
- **env 字段**: config 中通过 `env: {OTBN_EN_MASKING: "1"}` 注入掩码模式，`main.py` 自动设置/恢复环境变量，无需手动 `export`。
- **ISS 缓存**: 每次 `run_iss` 调用前按 `__file__` 路径清除 `sys.modules` 中所有 otbn/otbnsim/shared/serialize 模块，确保 `BNMULV_VER` 和 `OTBN_EN_MASKING` 切换生效。

## 数据库表结构

```sql
CREATE TABLE runs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    version TEXT NOT NULL, timestamp TEXT NOT NULL, raw_log_path TEXT);
CREATE TABLE metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    run_id INTEGER NOT NULL REFERENCES runs(id) ON DELETE CASCADE,
    operation TEXT NOT NULL, cycles INTEGER, instructions INTEGER,
    stalls INTEGER, stall_pct REAL,
    imem INTEGER, dmem INTEGER,
    instr_categories TEXT, instr_freqs TEXT);
```

## 掩码 vs 非掩码对比

掩码通过环境变量 `OTBN_EN_MASKING=1` 注入 ISS（`sim.py` → `state.py` → `kmac.py`），Keccak-f 从 24→96 cycles。config 中通过 `env` 字段声明，`main.py` 自动设置/恢复环境变量，无需手动 `export`。

```bash
# 一键跑 ver2 的 unmasked + masked 对比
python main.py run -V ver2,ver2_masked

# 报告自动包含 [10] 掩码 vs 非掩码对比
python main.py report
```

报告示例：
```
[10] 掩码 vs 非掩码对比 (DOM 24→96 cy/Keccak-f)
────────────────────────────────────────────────────────
  操作                    ver2_masked Δcyc  ver2_masked Δ%
  ML-KEM KeyGen                  +3,096       +4.2%
  ML-KEM Encap                   +3,168       +4.0%
  P-256 ECDH                         +0        0.0%
  TOTAL                           +7,209       +0.8%
```

> **原理**：KMAC 是独立硬件，Keccak-f 与 OTBN 指令流并行执行。OTBN 只在需要 digest 数据且 KMAC 未 ready 时才 stall。因此 4× Keccak-f 延迟对 ML-KEM 端到端性能的影响仅 ~4%。

## Phase 1/2 全流程测试

日常用本框架 ISS 单模块即可。发版/论文前跑一次全流程 chip sim 作为系统级数据：
```bash
CHIP="--test_timeout=2000 --cache_test_results=no"
bazel test //test_hybrid_kem_otbn_prompt_ver0:phase1_keygen_test_sim_verilator $CHIP
```
