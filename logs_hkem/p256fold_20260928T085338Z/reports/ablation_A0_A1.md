# P4 消融表：A0（serial） vs A1（overlap）

> A0/A1 共享同一 RTL datapath（同一 Fold Unit、同一 260-bit CPA、同一寄存位宽、同一接口、同一安全处理），
> 只通过受控模式选择调度（`p256_serial` = 1/0）。因此下表中的差值只能归因于 overlap 本身。

| 项 | A0 serial（P3） | A1 overlap（P4） | 差 | 证据 |
|---|---|---|---|---|
| 指令执行段（首写拍 → 退休拍） | 28 拍 | 22 拍 | **-6** | `rtl/p4_{serial,overlap}_trace_acc.txt` |
| 含 ret + fetch 的帧（旧口径 +2） | 30 | 24 | **-6** | `reports/p4_frame.json` |
| 该指令的 S 拍 | 27 | 21 | **-6** | `reports/p4_stall.md` |
| 三条指令的程序级 | 564 | 546 | **-18**（= 3 x -6） | runner 的 `Executed cycles` |
| 结果（32 GPR + 32 WDR） | 基准 | **逐字节相同** | 0 | 同一金标、两版均 PASS |
| `micro_mul` / `fold_row` / `fold_seed` / `fold_merge` / `fold_quot` / `fold_corr` | 16/8/1/1/1/1 | 16/8/1/1/1/1 | 0 | `rtl/p4_{serial,overlap}_events.csv` |
| `overlap_cycle_count` | 0 | 6（= c10…c15） | +6 | 同上 |
| chip 锚点（OTBN 指令数） | 0x8c1e2 / 0x8c1e2 / 0x8dfe7 / 0x8dfe7 | 同左（默认 serial；overlap 未在 chip 层跑） | 0 | `bazel test` 的 test.log |
| app 层投影 | — | 9,602 x 6 = 57,612 拍 | — | **未在 app 层实测**（本阶段只做 OTBN 侧、单 ELF 对照） |

## 说明

- chip 锚点这一行是**默认模式（serial）**下跑的：P4 的默认值保持 serial，overlap 只在 co-sim 层显式打开。
  若要 chip 层量 overlap，改 runner/plusarg 后再跑一次即可（本阶段未做，不混入口径）。
- `9,602 x 6 = 57,612` 是 PDF §8 行 46 的**解析投影**，不是本阶段实测值；app 层收益留到 P5/P6。
