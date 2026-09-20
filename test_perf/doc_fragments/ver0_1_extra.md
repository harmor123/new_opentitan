### 6.3 本次修正：`rc` 轮常量表尾缺 24 B（否则会静默产出错值）

- **症状**：`encap_h_ek` 只测到 7,677 拍（应 ≈68,354）、`decap_hash_g_reuse` 5,985（应 6,114）；报告里 Keccak-f 闭环显示 Encaps 差 **+8**。
- **根因**：`keccakf` 的 IOTA 步每轮 `bn.lid x31, 0(x6++)` **整 32 B** 读一个 rc 槽（低 64 位 = 常量、高 192 位 = 0），而 rc 表 24 条的最后一条后面**没有 `.balign 32`**（实际只有 744 B）。当 `rc` 恰是已下装 DMEM 镜像的**最后一个符号**时，最后一轮那次整字读越过镜像 ⇒ 未下装字 integrity 位无效 ⇒ ISS 报 `DMEM_INTG_VIOLATION` 当场中止。
- **修复**：ver0_1 的 5 个文件表尾补 `.balign 32`（`keygen_sha3_context_rc_data.s` + `mlkem_base_{keypair,encap,decap}_test.s` + `sha3_shake_test.s`）。**只有 ver0_1 有软件 `keccakf`**，ver0_2/ver1_1 走 KMAC，不受影响。
- **加固**：`harness.py` 现在记录并检查每行的 `ERR_BITS / pending_halt / fsm / 是否执行到自己的 ecall`，报告单列 `[运行健康检查]`；诊断工具 `test_perf/tools/diag/iss_diag.py`（打印中止状态、循环/调用栈残留、最后执行的指令、DMEM 有效范围）。

## 7. `poly_gen_matrix` 内部（桩法分解，不参与 Σ）

| 组件 | Cycles | 占比（/307,390） | 说明 |
|---|---:|---:|---|
| `_shake`（XOF 路径） | 254,583 | **82.8%** | 9 个 (ρ, nonce) 会话；**每会话 squeeze 15 次**（= ISS 实测需求） |
| `_rejection`（候选提取 + 拒绝采样） | 52,807 | **17.2%** | 桩替换 SHAKE 后的纯采样循环（54,976 − 2,169） |
| `_stub_overhead`（校准） | 2,169 | — | 桩自身固定开销（9 × 15 = **135** 次调用） |
| 合成 vs 直接测量 | 254,583 + 54,976 − 2,169 = **307,390** vs **307,390** | **差 +0（0.00%）** | 桩法与直接法**精确互证** |

> **2026-09-20 修正**：上表旧值为 266,007 / 55,731 / 2,199、合成 319,539（差 3.95%）。原因有二，均已修：
> ① 流文件是**旧 ρ 时代**那份（三版曾逐字节相同）；② `_shake` 行还写着当时的逐会话计数 15/16/15/15/16/15/15/15/15 = **137**，而父行（阶段行）实测 **135** ⇒ 多 2 次 `shake_out` ⇒ 多 2 次 `keccakf`。
> 现流由 `test_perf/tools/gen/gen_xof_stream_from_rho.py` 从 ρ 确定性生成（Python `SHAKE128(ρ‖j‖i)`，已与 ISS 抓取的真流逐字节比对），三行计数与父行逐一相等（判定工具 `test_perf/tools/check/audit_fidelity.py` 的 ②''）。

**该阶段指令归因（Δ 后 Top 5）**：`bn.rshi` 50,830 · `bn.and` 27,694 · `bn.xor` 25,551 · `addi` 23,829 · `andi` 16,705
⇒ 软件 Keccak 的开销集中在**位旋转 + 位逻辑**（θ/χ/ρ 步），非算术单元。
