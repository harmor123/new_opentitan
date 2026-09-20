## 1. 版本定义与口径

### 1.1 组件构成

| 组件 | ver1_1 实现 |
|---|---|
| ML-KEM-768 | **官方 mlkem1024 移植到 768**（官方向量指令 + 掩码：`bn.mulqacc`/`bn.addvm` 等）；**哈希 = KMAC 硬件** |
| P-256 | 官方 API（不参与本文对照） |
| HKDF-SHA3-256 | KMAC 硬件 |
| Q | 3,329（KYBER_Q）；k = 3；pk 1,184 B / sk 2,400 B / ct 1,088 B |

### 1.2 口径标签

| 标签 | 含义 |
|---|---|
| `Direct` | 用真实输入直接测量该阶段（`Δ = profiling − control`） |
| `Exact-real-input` | 用 app 真实中间值作输入并直接测量 |

**无任何 `Reuse-*` / `Estimated` 行**：37 个阶段全部现场实测。

### 1.3 本版数据的变更（累计）

| # | 变更 | 影响 |
|---|---|---|
| 1 | 22 对 harness 按 **ver1_1 内核调用约定**重写（`x2`–`x6` + `x31` 栈指针 + MOD CSR；`common_data.s` 提供 `mlkem768_const_params`/`stack`/`_expand_buf` 等） | 阶段行与 app 的真实调用点一致（含 6 次 `poly_frombytes`、3 次标度 `basemul`） |
| 2 | `mlkem_encap.s` 两处 `loopi` 体长声明修正（`3,21`→`3,20`、`3,20`→`3,19`） | 去掉对 fall-through 的隐式依赖（功能无变化） |
| 3 | **全部行改为现场实测** + harness 加**运行健康检查** | 残缺运行会当场打 ⚠ |

### 1.4 测量环境与复现

```bash
cd ~/new_pqc/opentitan
bazel build //test_hybrid_kem_otbn_prompt_ver1_1/otbn/mlkem768:all
python3 test_perf/harness.py --config test_perf/harness_config.yaml --version ver1_1 \
        --csv logs_hkem/ver1_1_profiling/re_ver1_1.csv \
        --json logs_hkem/ver1_1_profiling/re_ver1_1.json \
        --markdown logs_hkem/ver1_1_profiling/re_ver1_1.md
```

### 1.5 与 ver0_2 的关系（一句话）

**算术内核换成官方向量实现**（`ntt` 48,830 → 13,902、`intt×4` 35,092 → 10,944、`poly_add` 7,005 → 1,250、`poly_reduce` 融进 `basemul_acc` 后消失），
但**打包/解包与 CBD 采样变贵**（`unpack_pk` 1,879 → 23,093、`unpack_sk_pk` 3,758 → 22,428、`pack_pk/sk` ≈1,850 → ≈10,800、`noise_x7` 14,868 → 21,560）
⇒ 这是它相对 ver0_2 只快 1.27×（encap）的原因。

### 1.6 残差构成

| 清零量（8 KiB 级） | keygen | encap | decap |
|---|---|---|---|
| 清零循环迭代数 ×4 B | 1,970 (≈8 KiB) | 2,220 (≈8.7 KiB) | 4,050 (≈16 KiB) |
| = 迭代 × 3 指令 | 5,910 | 6,660 | 12,150 |
| 实测残差（+ 胶水） | **7,636**（5.53%） | **9,761**（5.73%） | **18,558**（8.60%） |
