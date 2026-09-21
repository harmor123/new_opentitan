# IBEX(chip) 实测 · 三版对照（宿主分段 + 与 ISS / RTL 两层的逐行对接）

> 生成：`python3 test_perf/tools/gen/gen_ibex_doc.py --write --archive <实验数据/>`（数字全部从 `logs_hkem/<版本>/*.uart0.log` 与 RTL 的 JSON 生成，**不手抄**）。
> 口径：**宿主** Ibex `mcycle`（含总线/驱动/等待）与 **OTBN 硬件计数器 `INSN_CNT`**；
> 三层只做「**周期比周期**（`execute_wait` ↔ ISS `macro` ↔ RTL 跨度）」与「**指令比指令**（`INSN_CNT` ↔ ISS `insn` ↔ RTL Σ`E`）」的对接 ——
> 三层口径不同，**相减得不出实现差异**；区别与联系见 `实验数据/README.md`。

## 1. ML-KEM 单 op：三层并排（这一组三层都能对上）

| 版本 / op | ① IBEX `INSN_CNT` | ② ISS `insn`（①−②） | ③ RTL Σ`E` | ① 宿主 `execute_wait` | ② ISS `macro`（①−②） | ③ RTL 跨度（③−②） |
|---|---:|---:|---:|---:|---:|---:|
| ver0_1 / `keygen` | 511,152 | 511,152（+0） | 511,152 | 559,817 | 559,021（+796，+0.14%） | 559,008（-13，-0.00%） |
| ver0_1 / `encap` | 558,624 | 558,624（+0） | 558,624 | 608,890 | 608,161（+729，+0.12%） | 608,148（-13，-0.00%） |
| ver0_1 / `decap` | 617,113 | 617,113（+0） | 617,113 | 669,463 | 668,676（+787，+0.12%） | 668,663（-13，-0.00%） |
| ver0_2 / `keygen` | 157,624 | 157,644（-20） | 157,624 | 176,494 | 175,792（+702，+0.40%） | 175,751（-41，-0.02%） |
| ver0_2 / `encap` | 196,446 | 196,401（+45） | 196,446 | 216,355 | 215,467（+888，+0.41%） | 215,517（+50，+0.02%） |
| ver0_2 / `decap` | 255,383 | 255,328（+55） | 255,383 | 277,372 | 276,530（+842，+0.30%） | 276,594（+64，+0.02%） |
| ver1_1 / `keygen` | 97,301 | 96,826（+475） | 97,301 | 139,551 | 138,140（+1,411，+1.02%） | 138,792（+652，+0.47%） |
| ver1_1 / `encap` | 118,979 | 118,439（+540） | 118,979 | 171,728 | 170,235（+1,493，+0.88%） | 170,978（+743，+0.44%） |
| ver1_1 / `decap` | 145,323 | 144,773（+550） | 145,323 | 217,226 | 215,707（+1,519，+0.70%） | 216,464（+757，+0.35%） |

> 读法：**①−②** 是 chip 与 ISS 的差（ver0_1 全 0；KMAC 版 = 轮询圈数差）；**①−②（周期）** 是宿主 `execute_wait` 与 ISS `macro` 的差（调用/等待开销，+0.70%～+1.02%）；**③−②** 是 RTL 真机跨度与 ISS 模型 `macro` 的差（KMAC 模型差，见 `RTL实测_三版对照.md` §4）。

## 2. 协议阶段（`phase1_keygen` / `phase2_*`）：宿主分段 + 三个 OTBN app

> 协议里 **OTBN 被调用三次**：ML-KEM、P-256 ECDH、HKDF —— 各自的指令数由宿主读出打印；
> 宿主分段（`HKEM_PROF`）就是协议里每一段花的 mcycle。RTL 层对这三者的真实周期见 §1（ML-KEM）与 §3。

### ver0_1（软件 Keccak）

**phase1_keygen_test**：宿主分段：

| 阶段（宿主 mcycle） | 拍 |
|---|---:|
| `p256_keygen_total` | 719,454 |
| `mlkem_keypair_load` | 445,027 |
| `mlkem_keypair_write_inputs` | 1,750 |
| `mlkem_keypair_execute_wait` | 559,817 |
| `mlkem_keypair_read_outputs` | 55,528 |
| `wipe_after_mlkem_keypair` | 1,288 |
| `protocol_total` | 1,782,864 |
| `scope_total` | 2,156,430 |
| `accounted_total` | 1,798,303 |
| `unaccounted_total` | 358,127 |

**phase2_alice_encap_test**：OTBN 指令数 `p256_ecdh` 581,607；宿主分段：

| 阶段（宿主 mcycle） | 拍 |
|---|---:|
| `p256_ecdh_official_api` | 741,118 |
| `p256_unmask` | 437 |
| `mlkem_encap_load` | 422,637 |
| `mlkem_encap_write_inputs` | 22,646 |
| `mlkem_encap_execute_wait` | 608,890 |
| `mlkem_encap_read_outputs` | 18,047 |
| `wipe_after_mlkem_encap` | 1,278 |
| `hkdf_load` | 130,108 |
| `hkdf_write_params` | 1,559 |
| `hkdf_write_info_len` | 285 |
| `hkdf_assemble_ikm` | 803 |
| `hkdf_write_ikm` | 2,769 |
| `hkdf_execute_wait` | 55,561 |
| `hkdf_read_output` | 838 |
| `wipe_after_hkdf` | 1,329 |
| `protocol_total` | 2,008,305 |
| `scope_total` | 2,214,518 |
| `accounted_total` | 2,014,086 |
| `unaccounted_total` | 200,432 |

**phase2_bob_decap_test**：OTBN 指令数 `p256_ecdh` 581,607；宿主分段：

| 阶段（宿主 mcycle） | 拍 |
|---|---:|
| `mlkem_decap_load` | 455,815 |
| `mlkem_decap_write_inputs` | 64,224 |
| `mlkem_decap_execute_wait` | 669,463 |
| `mlkem_decap_read_outputs` | 944 |
| `wipe_after_mlkem_decap` | 1,269 |
| `p256_ecdh_official_api` | 743,093 |
| `p256_unmask` | 462 |
| `hkdf_load` | 130,426 |
| `hkdf_write_params` | 1,548 |
| `hkdf_write_info_len` | 310 |
| `hkdf_assemble_ikm` | 794 |
| `hkdf_write_ikm` | 2,672 |
| `hkdf_execute_wait` | 55,593 |
| `hkdf_read_output` | 942 |
| `wipe_after_hkdf` | 1,308 |
| `protocol_total` | 2,128,863 |
| `scope_total` | 2,326,704 |
| `accounted_total` | 2,130,058 |
| `unaccounted_total` | 196,646 |

### ver0_2（KMAC 硬件哈希）

**phase1_keygen_test**：宿主分段：

| 阶段（宿主 mcycle） | 拍 |
|---|---:|
| `p256_keygen_total` | 719,358 |
| `mlkem_keypair_load` | 309,989 |
| `mlkem_keypair_write_inputs` | 1,632 |
| `mlkem_keypair_execute_wait` | 176,494 |
| `mlkem_keypair_read_outputs` | 55,641 |
| `wipe_after_mlkem_keypair` | 1,268 |
| `protocol_total` | 1,264,382 |
| `scope_total` | 1,637,972 |
| `accounted_total` | 1,279,833 |
| `unaccounted_total` | 358,139 |

**phase2_alice_encap_test**：OTBN 指令数 `p256_ecdh` 581,607；宿主分段：

| 阶段（宿主 mcycle） | 拍 |
|---|---:|
| `p256_ecdh_official_api` | 741,118 |
| `p256_unmask` | 437 |
| `mlkem_encap_load` | 361,071 |
| `mlkem_encap_write_inputs` | 22,694 |
| `mlkem_encap_execute_wait` | 216,355 |
| `mlkem_encap_read_outputs` | 17,965 |
| `wipe_after_mlkem_encap` | 1,314 |
| `hkdf_load` | 86,709 |
| `hkdf_write_params` | 1,465 |
| `hkdf_write_info_len` | 271 |
| `hkdf_assemble_ikm` | 766 |
| `hkdf_write_ikm` | 2,738 |
| `hkdf_execute_wait` | 5,389 |
| `hkdf_read_output` | 856 |
| `wipe_after_hkdf` | 1,319 |
| `protocol_total` | 1,460,467 |
| `scope_total` | 1,666,356 |
| `accounted_total` | 1,466,307 |
| `unaccounted_total` | 200,049 |

**phase2_bob_decap_test**：OTBN 指令数 `p256_ecdh` 581,607；宿主分段：

| 阶段（宿主 mcycle） | 拍 |
|---|---:|
| `mlkem_decap_load` | 395,027 |
| `mlkem_decap_write_inputs` | 64,344 |
| `mlkem_decap_execute_wait` | 277,372 |
| `mlkem_decap_read_outputs` | 932 |
| `wipe_after_mlkem_decap` | 1,310 |
| `p256_ecdh_official_api` | 742,977 |
| `p256_unmask` | 441 |
| `hkdf_load` | 87,132 |
| `hkdf_write_params` | 1,482 |
| `hkdf_write_info_len` | 283 |
| `hkdf_assemble_ikm` | 798 |
| `hkdf_write_ikm` | 2,706 |
| `hkdf_execute_wait` | 5,327 |
| `hkdf_read_output` | 836 |
| `wipe_after_hkdf` | 1,281 |
| `protocol_total` | 1,582,248 |
| `scope_total` | 1,778,927 |
| `accounted_total` | 1,583,464 |
| `unaccounted_total` | 195,463 |

### ver1_1（官方向量指令 + KMAC）

**phase1_keygen_test**：宿主分段：

| 阶段（宿主 mcycle） | 拍 |
|---|---:|
| `p256_keygen_total` | 719,303 |
| `mlkem_keypair_load` | 259,362 |
| `mlkem_keypair_write_inputs` | 1,683 |
| `mlkem_keypair_execute_wait` | 139,551 |
| `mlkem_keypair_read_outputs` | 55,688 |
| `wipe_after_mlkem_keypair` | 1,265 |
| `protocol_total` | 1,176,852 |
| `scope_total` | 1,550,133 |
| `accounted_total` | 1,192,343 |
| `unaccounted_total` | 357,790 |

**phase2_alice_encap_test**：OTBN 指令数 `p256_ecdh` 581,607；宿主分段：

| 阶段（宿主 mcycle） | 拍 |
|---|---:|
| `p256_ecdh_official_api` | 741,264 |
| `p256_unmask` | 444 |
| `mlkem_encap_load` | 260,380 |
| `mlkem_encap_write_inputs` | 22,745 |
| `mlkem_encap_execute_wait` | 171,728 |
| `mlkem_encap_read_outputs` | 18,019 |
| `wipe_after_mlkem_encap` | 1,298 |
| `hkdf_load` | 87,112 |
| `hkdf_write_params` | 1,422 |
| `hkdf_write_info_len` | 282 |
| `hkdf_assemble_ikm` | 783 |
| `hkdf_write_ikm` | 2,737 |
| `hkdf_execute_wait` | 5,291 |
| `hkdf_read_output` | 886 |
| `wipe_after_hkdf` | 1,331 |
| `protocol_total` | 1,315,722 |
| `scope_total` | 1,521,685 |
| `accounted_total` | 1,321,591 |
| `unaccounted_total` | 200,094 |

**phase2_bob_decap_test**：OTBN 指令数 `p256_ecdh` 581,607；宿主分段：

| 阶段（宿主 mcycle） | 拍 |
|---|---:|
| `mlkem_decap_load` | 355,541 |
| `mlkem_decap_write_inputs` | 64,321 |
| `mlkem_decap_execute_wait` | 217,226 |
| `mlkem_decap_read_outputs` | 985 |
| `wipe_after_mlkem_decap` | 1,287 |
| `p256_ecdh_official_api` | 742,789 |
| `p256_unmask` | 469 |
| `hkdf_load` | 86,761 |
| `hkdf_write_params` | 1,593 |
| `hkdf_write_info_len` | 275 |
| `hkdf_assemble_ikm` | 816 |
| `hkdf_write_ikm` | 2,626 |
| `hkdf_execute_wait` | 5,337 |
| `hkdf_read_output` | 889 |
| `wipe_after_hkdf` | 1,259 |
| `protocol_total` | 1,482,174 |
| `scope_total` | 1,678,677 |
| `accounted_total` | 1,483,328 |
| `unaccounted_total` | 195,349 |

## 3. 单 app 测试：P-256 / HKDF（宿主 cycles ↔ **RTL 真机跨度**）

> 这两个 app 的 RTL 数据在 `RTL实测_三版对照.md` §3b；这里给宿主的 `cycles`（= `profile_start/end`，**宿主 mcycle**）与 RTL 跨度的对照 —— 差 = 总线搬运 + 驱动等待 + 中断等宿主开销。
> P-256 行：宿主 `cycles` 与 RTL 列都取**第一次调用（Keygen A）**；ECDH 的 RTL 跨度 603,474 拍见 §3b.2。

| 版本 / 测试 | 宿主 `cycles` | 宿主读数（OTBN 指令数） | RTL Σ`E` | RTL 跨度 | 宿主 − RTL 跨度 |
|---|---:|---|---:|---:|---:|
| ver0_1 / `test_p256_only` | 767,992 | 573,922 ×2、581,607 ×2 | 573,922 | 595,979 | +172,013 |
| ver0_1 / `test_hkdf_only` | 55,538 | 51,145（合计） | 51,145 | 54,810 | +728 |
| ver0_2 / `test_p256_only` | 767,441 | 573,922 ×2、581,607 ×2 | 573,922 | 595,979 | +171,462 |
| ver0_2 / `test_hkdf_only` | 5,254 | 3,374（合计） | 3,374 | 4,563 | +691 |
| ver1_1 / `test_p256_only` | 767,972 | 573,922 ×2、581,607 ×2 | 573,922 | 595,979 | +171,993 |
| ver1_1 / `test_hkdf_only` | 5,311 | 3,374（合计） | 3,374 | 4,563 | +748 |

> P-256 的三版**指令数逐位相同**（Keygen 573,922 / ECDH 581,607）⇒ 同一个官方 app；
> HKDF 的 ver0_2 与 ver1_1 相同（3,374），ver0_1 是软件 Keccak 版（51,145）。

## 4. 三版 × 全部 OTBN app：指令数矩阵（都来自 chip 日志）

| app | ver0_1 | ver0_2 | ver1_1 |
|---|---:|---:|---:|
| ML-KEM keypair | 511,152 | 157,624 | 97,301 |
| ML-KEM encap | 558,624 | 196,446 | 118,979 |
| ML-KEM decap | 617,113 | 255,383 | 145,323 |
| P-256 ECDH（`test_p256_only`） | 581,607 | 581,607 | 581,607 |
| HKDF（`test_hkdf_only`） | 51,145 | 3,374 | 3,374 |

