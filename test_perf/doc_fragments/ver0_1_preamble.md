## 1. 版本定义与口径

### 1.1 组件构成

| 组件 | ver0_1 实现 |
|---|---|
| ML-KEM-768 | 自写标量实现；模约减 = Plantard 标量；**哈希 = 纯软件 Keccak**（`sha3_shake.s`） |
| P-256 | 自写（不参与本文对照） |
| HKDF-SHA3-256 | 自写（不参与本文对照） |
| Q | 3,329（KYBER_Q）；k = 3；pk 1,184 B / sk 2,400 B / ct 1,088 B |

### 1.2 口径标签

| 标签 | 含义 | v3 是否还有 |
|---|---|---|
| `Direct` | 用真实输入直接测量该阶段（`Δ = profiling − control`） | ✅ 绝大多数行 |
| `Exact-real-input` | 用 app 真实中间值作输入（矩阵生成：统一为 app 真实 ρ）并直接测量 | ✅ `poly_gen_matrix` |
| `Calibration` | 桩法校准项，非 FIPS 步骤，不进 Σ | ✅ `*_stub_overhead` |
| ~~`Reuse-identical` / `Reuse-fixed` / `Estimated`~~ | 旧版按"同一函数复用 / 按调用次数换算"填的行 | ❌ **v3 已全部取消**（对应行改为现场实测，行名不变） |

### 1.3 本版数据的变更（累计）

| # | 变更 | 影响 |
|---|---|---|
| 1 | **测试向量统一**：app 的 `coins`/`pk`/`ct` 统一为 `assets/ML-KEM-768` 第 1 条 KAT（`d = 7c9935a0…`） | macro 全部更新（更早文档的 562,282 / 617,093 / 694,375 出自另一套旧向量，已作废） |
| 2 | **harness ρ 统一**：矩阵原型的 `rho:` 改为 app 真实值 `98c02e16…`（= `SHA3-512(coins[0:32]‖0x03)[:32]`） | `poly_gen_matrix` 统一为 **307,390**；Keccak-f 调用闭环 −2/−3/−6 → **+0** |
| 3 | ~~wrapper 清零循环 `sw` → `bn.sid x31, 0(x2++)`~~ **已回退（2026-09-19）** | v2 表 macro 曾因此各 −7,168 拍；**v3 全部按 `sw` 口径** |
| 4 | **17 条 reuse 行 → 现场实测**（行名不变） | **本表每个数都是实测**；与旧"换算值"差异逐条可见（`getnoise×7` 旧 76,016 → 实测 **75,971**；`ntt×3` 旧 24,415 → 实测 **24,405**） |
| 5 | **修 `rc` 表尾缺 24 B 补位** + harness 加**运行健康检查** | `encap_h_ek` 由残缺运行的 7,677 → **68,354**（与 `hash_h` 逐位相同 ✓）；见 §6.3 |

### 1.4 测量环境与复现

```bash
cd ~/new_pqc/opentitan
bazel build //test_hybrid_kem_otbn_prompt_ver0_1/otbn/mlkem768:all
python3 test_perf/harness.py --config test_perf/harness_config.yaml --version ver0_1 \
        --csv logs_hkem/ver0_1_profiling/re_ver0_1.csv \
        --json logs_hkem/ver0_1_profiling/re_ver0_1.json \
        --markdown logs_hkem/ver0_1_profiling/re_ver0_1.md
```

产物：`re_ver0_1.{csv,json,md}` + `run.log`（含每行的 ISS 结束状态：`[运行健康检查]` 段）。
