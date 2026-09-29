# P3 增量⑤：逐拍记录（单元级 + co-sim 级）

- 结论：**PASS - 0 errors / 7 checks**
- 单元日志：`p3_unit.log`（sha256(LF) `97fde1daf5580a43162453ffb573e51a784f583c14008ed67ad2ff548e1ef6e2`，逐拍 861 行）
- 模型：`p256_fold_model.py`（sha256(LF) `704fce705660f2d48550d8442d09613c1aed84d33b81e3a87a3b8a2f49a0dbec`）
- co-sim 金标：`p256_fold_test.expected.txt`（sha256(LF) `d6cad4b2c81883e4abf18284c069f5b31bfda89f1681363e410793221d0fa0ef`）

## 对齐约定（本文档的坐标定义）

| 量 | 坐标 | 说明 |
|---|---|---|
| 单元 TB `CYC … <cycle>` | **模块自己的拍号** | 与 MAC FSM 的 `current_cycle` 同拍同号（启动脉冲在取指拍给出，比执行早一拍） |
| 模型 `light()` 的 phase | 同表 cycle | serial 模式 = 拍号 − 6（`TailShift`）；overlap 模式 = 拍号 |
| co-sim 轨迹 `<cycle>` | **指令内拍号**（c0 = 0） | `--otbn-trace-file` 的第十进制首字段 |

## 单元级：serial 逐拍要点

| 项 | 判据 | 实测 |
|---|---|---|
| 逐拍相等 | 每行 tb == model | 861 行全等 ✓ |
| c10…c15 hold | F == c3 的 seed | 0 处不符 |
| 完成拍 | serial 27 / overlap 21 | 0 处不符 |
| 向量覆盖 | 21 条 × 2 模式 | 42 组 |

逐拍全量在 `p3_percycle.csv`（861 行 + 表头）。
