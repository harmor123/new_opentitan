## 1. 版本定义与口径

### 1.1 组件构成

| 组件 | ver0_2 实现 |
|---|---|
| ML-KEM-768 | 自写标量实现（与 ver0_1 同一套算术内核：Plantard 标量 + `ntt`/`basemul`/`intt`）；**哈希 = KMAC 硬件**（`xof_*` 驱动 API） |
| P-256 | 官方 API（不参与本文对照） |
| HKDF-SHA3-256 | KMAC 硬件 |
| Q | 3,329（KYBER_Q）；k = 3；pk 1,184 B / sk 2,400 B / ct 1,088 B |

### 1.2 口径标签

| 标签 | 含义 |
|---|---|
| `Direct` | 用真实输入直接测量该阶段（`Δ = profiling − control`） |
| `Exact-real-input` | 用 app 真实中间值作输入（矩阵生成：统一为 app 真实 ρ）并直接测量 |
| `Calibration` | 桩法校准项，非 FIPS 步骤，不进 Σ |

**无任何 `Reuse-*` / `Estimated` 行**：42 个阶段全部现场实测（行名与旧版一致）。

### 1.3 本版数据的变更（累计）

| # | 变更 | 影响 |
|---|---|---|
| 1 | 测试向量统一（第 1 条 KAT）、harness ρ 统一为 app 真实值 | `poly_gen_matrix` 三操作统一；**KMAC 驱动 API 调用闭环 +0** |
| 2 | wrapper 清零循环保持 `sw` 形式（8 KiB ÷ 4 = 2,048 迭代 × 3 指令 = 6,144 拍） | 残差 = 6,144 + 胶水 ≈ **8,517–8,599**（3.1–4.9%） |
| 3 | **全部行改为现场实测** + harness 加**运行健康检查**（ERR_BITS / 是否执行到 ecall） | 每行都是直接测量；残缺运行会当场打 ⚠ |

### 1.4 测量环境与复现

```bash
cd ~/new_pqc/opentitan
bazel build //test_hybrid_kem_otbn_prompt_ver0_2/otbn/mlkem768:all
python3 test_perf/harness.py --config test_perf/harness_config.yaml --version ver0_2 \
        --csv logs_hkem/ver0_2_profiling/re_ver0_2.csv \
        --json logs_hkem/ver0_2_profiling/re_ver0_2.json \
        --markdown logs_hkem/ver0_2_profiling/re_ver0_2.md
```

### 1.5 与 ver0_1 的关系（一句话）

算术阶段**逐位相同**（`ntt` 48,830 · `basemul_acc` 55,672 · `intt×4` 35,092 …），差异**全部来自哈希与采样路径的硬件化** —— 见 `ver0_1_vs_ver0_2_对照表.md` §3。
