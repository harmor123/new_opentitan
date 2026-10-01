## 1. 版本定义与口径

### 1.1 组件构成

| 组件 | ver1_2 实现 |
|---|---|
| ML-KEM-768 | **与 ver1_1 逐字节相同**（官方 mlkem1024 移植到 768：`bn.mulqacc`/`bn.addvm` 等向量指令 + 掩码）；**哈希 = KMAC 硬件** |
| P-256 | **本版折叠指令**（域乘 = 一条 `bn.p256mul`，见本版树 `otbn/p256/`）；**不在 §2–§6**（那两节的阶段表只覆盖 ML-KEM）—— P-256 走 harness 的 **apps-only 专表条目** `p256_ver1_2`（app 级 ISS 数 + 逐符号 `exec_insn`，见 §1.4 命令） |
| HKDF-SHA3-256 | KMAC 硬件（与 ver1_1 相同） |
| Q | 3,329（KYBER_Q）；k = 3；pk 1,184 B / sk 2,400 B / ct 1,088 B |

**版本树的来历**：ver1_2 = ver1_1 基线（`2d87e79bee` 状态）的**逐字节副本**，只有 P-256 与包路径不同
（生成器 `logs_hkem/p256fold_20260928T085338Z/rtl/p5_make_ver1_2.py`；`--provenance` 可复核：
新增 7 个文件、与基线不同 7 个、其余 124 个逐字节相同）。因此**本表每一行都应与 ver1_1 相同** ——
本版的作用是把 P-256 的折叠指令放进同一条真实会话里量，而不是改 ML-KEM。

### 1.2 口径标签

| 标签 | 含义 |
|---|---|
| `Direct` | 用真实输入直接测量该阶段（`Δ = profiling − control`） |
| `Exact-real-input` | 用 app 真实中间值作输入并直接测量 |

**无任何 `Reuse-*` / `Estimated` 行**：37 个阶段全部现场实测（与 ver1_1 同一套）。

### 1.3 本版数据的变更（相对 ver1_1）

| # | 变更 | 影响 |
|---|---|---|
| 1 | ML-KEM / HKDF 内核与 22 对剖面目标：**逐字节同 ver1_1**（只改包路径，见本版 `otbn/mlkem768/`） | 阶段行与 app 调用点与 ver1_1 一一对应，两表可直接并列 |
| 2 | **P-256**：域乘换成本版折叠指令（serial 档 **30 拍/次**、overlap **24 拍**，对照旧实现 **54 拍**） | 不进 §2–§6 的 ML-KEM 表；走 harness **专表条目** `p256_ver1_2`（`--version p256_ver1_2`，apps-only：app 级 ISS 数 + 逐符号 `exec_insn`）。设备口径实测：Keygen `0x14ac7`=84,679、ECDH `0x166f5`=91,893 条指令（vs 上游 app 573,922 / 581,607）；**对照基准取 ver0_1**（专表条目 `p256_ver0_1`，与 ver1_2 是**同一支测试程序**，唯一差别是域乘实现） |

### 1.4 测量环境与复现

```bash
cd ~/new_pqc/opentitan
bazel build //test_hybrid_kem_otbn_prompt_ver1_2/otbn/mlkem768:all
python3 test_perf/harness.py --config test_perf/harness_config.yaml --version ver1_2 \
        --csv  logs_hkem/ver1_2_profiling/re_ver1_2.csv \
        --json logs_hkem/ver1_2_profiling/re_ver1_2.json \
        --markdown logs_hkem/ver1_2_profiling/re_ver1_2.md

# P-256 专表（apps-only 条目，每版一条；CSV 因无阶段行而跳过，数据在 JSON 的 apps 里）
# 旧/新对照 = p256_ver0_1 的 ecdh ↔ p256_ver1_2 的 ecdh（同一支测试程序）
for V in p256_ver0_1 p256_ver1_2; do
  python3 test_perf/harness.py --config test_perf/harness_config.yaml --version $V \
          --json     logs_hkem/${V}_profiling/re_${V}.json \
          --markdown logs_hkem/${V}_profiling/re_${V}.md
done
```

### 1.5 与 ver1_1 的关系（一句话）

**同表**：ML-KEM / HKDF 逐字节相同 ⇒ 分层表应与 ver1_1 **逐行相同**（同为 ISS 口径）；
本版唯一的新东西是 P-256（设备口径与 ISS 专表口径分别实测，见 §1.3 第 2 行）。

### 1.6 残差构成

应为与 ver1_1 相同（内核逐字节相同）。ver1_1 的实测值供对照：

| 清零量（8 KiB 级） | keygen | encap | decap |
|---|---|---|---|
| 清零循环迭代数 ×4 B | 1,970 (≈8 KiB) | 2,220 (≈8.7 KiB) | 4,050 (≈16 KiB) |
| = 迭代 × 3 指令 | 5,910 | 6,660 | 12,150 |
| 实测残差（+ 胶水） | **7,636**（5.53%） | **9,761**（5.73%） | **18,558**（8.60%） |

本版的实测值以生成出来的表为准（`logs_hkem/ver1_2_profiling/re_ver1_2.md`）。
