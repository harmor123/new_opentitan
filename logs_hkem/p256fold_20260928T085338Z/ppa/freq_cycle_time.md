# 同频 cycle 与各自 Fmax 的 time（PDF §17 清单项）

**甲、同频（125 MHz）比 cycle**：每次 `p256mul` 调用 serial **30** 拍（stalls 27）/ overlap **24** 拍（stalls 21）

**乙、各自 Fmax 比 time**（`Fmax = 1/(8 + |wns|)`）：

| 设计 | wns (ns) | Fmax (MHz) |
|---|---:|---:|
| B0 | -6.4249 | 69.3 |
| A0 | -7.0239 | 66.6 |
| A1 | -6.4325 | 69.3 |
| L1 | -3.4113 | 87.6 |

**丙、Fmax 变化对 ML-KEM time 的影响**：ML-KEM 路径**不经过 fold** ⇒ 其 OTBN 指令数与调度未变：基线 118979 / 新版 118979（实测，逐位相同 ✓）⇒ **同频下 ML-KEM time 不变**；若按各自 Fmax 折算，A1 的 Fmax 更高 ⇒ ML-KEM time 只会更好，不会更差 ✓。
