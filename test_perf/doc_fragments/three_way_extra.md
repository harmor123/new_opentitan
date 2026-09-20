## 5. 2026-09-20 修正记录（影响数值的全部项）

1. **`rc` 轮常量表尾缺 24 B**（ver0_1 独有，软件 `keccakf`）：IOTA 步每轮整 32 B 读一个 rc 槽，表尾没有 `.balign 32` ⇒ 当 `rc` 恰是已下装 DMEM 镜像的最后一个符号时越界读 ⇒ ISS 报 `DMEM_INTG_VIOLATION` 当场中止、**残缺值静默进表**（`encap_h_ek` 只测到 7,677 拍，应 ≈68,354）。已给 ver0_1 的 5 个文件表尾补 `.balign 32`。
2. **control ≡ profiling − `jal`**：审计 121 对发现 27 对不满足（control 少 `la/li/add` 准备指令 ⇒ Δ 高估，小行最多 +11%）。已用 `test_perf/tools/gen/fix_controls.py` 机械重派（`jal` 在 `loopi` 体内时同步减体长）。`decap_verify_cmov` 是**内联块行**（profiling 里 0 条 `jal`），按设计跳过。
3. **ver1_1 幽灵行 `keygen_poly_add` 删除**：ver1_1 的 keygen 把 e 的加法融进 `basemul_acc` 累加器，app **从不调用** `poly_add`（ISS 实测 `exec_insn=0`、动态调用 0 次 = 死代码），而行声明 3 次调用并进 Σ ⇒ 凭空多算 **750 拍**。判定工具 `test_perf/tools/check/audit_fidelity.py`（幽灵行检查）。
4. **桩法三行的流与计数**（`keygen_poly_gen_matrix_{shake,rejection,stub_overhead}`，`closure:false` 不进 Σ）：
   - 流文件过去是**旧 ρ 时代**的一份（三版曾逐字节相同），且 ver0_1/ver0_2 的 `_shake` 行还写着当时的逐会话计数 15/16/15/15/16/15/15/15/15 = **137**（父行实测 **135**）⇒ 多 2 次挤压 / 多 2 次 `keccakf`，`shake+rejection−stub_overhead` 与直接测量差 **+10,732 拍（ver0_1）/ +274 拍（ver0_2）**。
   - 现流由 `test_perf/tools/gen/gen_xof_stream_from_rho.py` 从 ρ **确定性生成**（Python `SHAKE128(ρ‖j‖i)`；已验证与从 ISS 原样抓的真流**逐字节相同**），按 app 实际需求分块（ver0_x 每会话 15 块 = 135；ver1_1 固定 21 块/会话 = 189），并加 1 块尾部补位防线性游走越界读。
   - `_rejection` / `_stub_overhead` 行改为**按会话重指流指针**，`_shake` 行计数改为 135。
   - 结果：三版 `shake + rejection − stub_overhead` 与直接测量的 `keygen_poly_gen_matrix` **精确闭合 +0**（ver0_1 307,390；ver0_2 47,736；ver1_1 46,270）。
   - 判定工具：`test_perf/tools/check/check_stream_shape.py`（流形状/配额/replay 一致）、`audit_fidelity.py` 的 ②''（桩法三行调用次数必须等于父行）。
5. **运行健康检查进 harness**：每行记录 `ERR_BITS / pending_halt / fsm / 是否执行到自己的 ecall`，报告单列 `[运行健康检查]` ⇒ 残缺运行（被 ISS 提前中止）不再可能静默进表。诊断工具 `test_perf/tools/diag/iss_diag.py`。
6. **残差构成已实测**（2026-09-20，`test_perf/tools/diag/stall_profile.py`，生成器 `gen_residual_doc.py`）：残差（= 整 app − Σ阶段）过去只有**指令级**拆分、拍级一直靠口头解释。现在把 app 的**拍数按 PC**（ISS 的 `stats` 每步增量：退役 / 停滞）归因 ⇒ 九组（版本 × op）都给出：**匿名区（wrapper 清零循环）≈87–97%** + **框架容器（`crypto_kem_*`/`indcpa_*`）** + 其它（减法残量，含 Σ 行前导冗余，≤ ~500 拍）。
   清零循环的实测形态：每次迭代 3 条指令（`sw x0,0(x2); addi x2,x2,4; bne`）+ 1 拍取指停滞 ≈ **4 拍/4 B**；ver0_1/ver0_2 各 op ≈ 8,252 拍（= 2,048 迭代 × 8 KiB），ver1_1 keygen 7,892 / encap 8,918 / decap 16,244 拍。全部数字见 `残差构成_全实测.md`。
   **自证**：每份日志的 Σ退役/Σ停滞 必须与 JSON 里那次实测的 `insn`/`stalls` 逐位相同（9/9 通过 ✓）。
