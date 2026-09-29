# P4 一页证明（打开 overlap）

## 判据 1：与 serial 版结果逐位一致

- 两版用**同一 ELF、同一金标**：`run_p256_fold.sh`（serial）与 `run_p256_fold.sh overlap` 均 `P256 FOLD TEST PASS for program p256_fold_test`；
- runner 的判据就是「最终转储 == 金标」⇒ 两版最终转储逐字节相同（32 个 GPR + 32 个 WDR）；
- 逐拍层面：三条指令各 16 次 ACC 写与模型 `mac()` 的 `acc_after` **逐拍相等**（见 `p4_percycle.md` / `p4_overlap_trace_acc.txt`）。

## 判据 2：相同附加开销下，函数执行段恰好减少 6 拍

逐条指令（同一 ELF）：

| 指令 | serial 首写→退休 | overlap 首写→退休 | 差 |
|---|---|---|---|
| d0*x @0x1c | 251 → 278 | 251 → 272 | **-6** |
| x*y @0x30 | 284 → 311 | 278 → 299 | **-6** |
| (p-1)^2 @0x44 | 317 → 344 | 305 → 326 | **-6** |

程序级：`Executed cycles` 564 → 546 = 3 x 6（同一 ELF 含 3 条该指令）。

## §5.2 内部事件计数（信号级观察，不从退休 E 反推）

| 计数 | 期望（主方案一次） | overlap 实测 | serial 实测 |
|---|---|---|---|
| `micro_mul` | 16 | 16 | 16 |
| `fold_row` | 8 | 8 | 8 |
| `fold_seed` | 1 | 1 | 1 |
| `fold_merge` | 1 | 1 | 1 |
| `fold_quot` | 1 | 1 | 1 |
| `fold_corr` | 1 | 1 | 1 |
| `overlap` | 6 | 6 | 0 |
| `wb` | 1 | 1 | 1 |
| `err` | 0 | 0 | 0 |

`overlap_cycle_count` 的六个周期号 = **c10…c15**（不是别的六拍），见 CSV 与 §5.1 页。
两条独立互证：`fold_f_changed` 在 c11…c20 全部为 1（F 每次 row/tail 更新都真的改变了值），而 `wdr_we` 在 c10…c15 恒为 0。

## 产物索引

| 判据/证据 | 落点 |
|---|---|
| 逐拍（两版） | `p4_overlap_trace_acc.txt` / `p4_serial_trace_acc.txt` |
| 逐拍值（模型比对） | `p4_percycle.md` / `p4_percycle.csv` |
| 事件计数与四元组 | `p4_overlap_events.csv` / `p4_serial_events.csv` |
| 波形页（本目录） | `p4_overlap_wave.md` |
| 逐条指令拍号 | 本页判据 2 表 |
