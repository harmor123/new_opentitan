## 7. P-256（本版唯一的新东西；不进上面的 ML-KEM Σ）

§2–§6 是 ML-KEM/HKDF 的分解（内核与 ver1_1 逐字节相同）。本节单列本版**唯一的新东西**：
P-256 的域乘改成折叠指令 —— 一条 `bn.p256mul`（本版树 `otbn/p256/p256_base.s` 的 `mul_modp` 函数体）
替代原先 53 条指令的软件实现。

**口径**：设备路径（chip sim）跑同一个测试 `test_p256_only`（Keygen A/B + ECDH A/B 四个会话），
打印的是 RTL 的 OTBN `INSN_CNT`（退休指令数）与宿主侧 `mcycle` 跨度。
**对照基准 = ver0_1** —— 唯一同样自带本地 P-256 实现的版本；它的 P-256 是软件实现，
四个指令数与上游 / P0 锚点（`0x8c1e2` / `0x8dfe7`）逐位一致，因此这条对照就是"软件 → 折叠指令"的净效果。

| 会话 | ver0_1（软件 P-256）INSN_CNT | ver1_2（折叠指令）INSN_CNT | Δ | ver0_1 跨度 | ver1_2 跨度 | Δ |
|---|---:|---:|---:|---:|---:|---:|
| Keygen A | `0x8c1e2` = 573,922 | `0x14ac7` = 84,679 | −85.3% | 767,992 | 499,648 | −34.9% |
| Keygen B | 573,922 | 84,679 | −85.3% | 766,456 | 498,402 | −35.0% |
| ECDH A | `0x8dfe7` = 581,607 | `0x166f5` = 91,893 | −84.2% | 796,568 | 528,693 | −33.6% |
| ECDH B | 581,607 | 91,893 | −84.2% | 796,179 | 528,195 | −33.7% |

- 数据来源：ver0_1 = `logs_hkem/ver0_1/test_p256_only.uart0.log`；ver1_2 = `logs_hkem/p256fold_20260928T085338Z/rtl/p5_device_evidence.ver1_2.txt`（采集脚本同目录 `p5_collect_device_evidence.sh`）。两次都是同一测试、同一 chip 模型档位（serial，无 `+p256_serial` 覆盖）。
- **跨度降幅小于指令降幅是口径使然**：跨度里含与 app 实现无关的宿主固定开销（装 app、写/读 dmem、轮询、擦除，约 214k 拍），两种实现都要付；扣掉后 OTBN 活跃周期约减半（该分解属推断，依据是实测跨度差、实测 fold 条数与逐帧实测 30 拍）。
- **逐指令事件**（本版实现共 38,371 行 `P256EV`）：每条指令 `rows=27`、`err=0`、`wb=1`、`micro_mul=16`，serial 档 `overlap=0` —— 五个分布**全单键** ⇒ 定长性与写回不变式在设备路径上成立。
- **每次域乘的帧长**：serial **30 拍**、overlap **24 拍**（对照软件实现 **54 拍**）⇒ 每次 −24 / −30 拍。
- `crypto/p256.c` 里的 `kModeKeygenInsCnt = 84679`、`kModeEcdhInsCnt = 91893` 是**运行期断言**（cryptolib 的 `HARDENED_CHECK_EQ(otbn_instruction_count_get(), 常量)`，见 `p256.c:264/453-457`）⇒ 设备测试 `PASS` 本身就证明"本版 app 每次恰好退休这么多条指令"（定长性）。
- 上游 `sw/` 的 P-256 实现与 cryptolib 源码**一字未动**：设备侧只用 label 引用上游 `.c/.h`，把 app 依赖指向本版 `otbn/p256:run_p256`；唯一复制过来改的是 `crypto/p256.c`，差异只有上面那两个常量 + 说明块（生成器 `logs_hkem/p256fold_20260928T085338Z/rtl/p5_gen_p256_c.py`，`--check` 可复核）。
