# stall 三级独立复核 · ver0_1

> 全部数字由 `test_perf/tools/diag/verify_stall_levels.py` **从 RTL trace 重算**；
> ①=每条动态指令自己的 stall，②=同 opcode 求和，③=kernel 总 stall（停滞+取指等待）。

## keygen

| kernel | 作用域 | ① 每条 stall（分布） | ② 逐 opcode 合计 | ③ kernel 总 stall | 帧数 | 总拍 == Σ帧跨度 |
|---|---|---|---|---:|---:|---|
| `mul_modp` | 叶 | 0 种指令， … |  … | 0 | 0 | — |
| `basemul` | 叶 | 18 种指令，`bn.mulqacc.wo` 5376×0；`bn.rshi` 2706×0；`bn.and` 2304×0 … | `bn.mulqacc.wo` 0、`bn.rshi` 0、`bn.and` 0、`bn.add` 0、`bn.addm` 0、`bn.subm` 0、`bn.lid` 150、`addi` 0、`bn.sid` 48、`bn.or` 0、 … | 204 | 3 | ✓ |
| `basemul_acc` | 叶 | 18 种指令，`bn.mulqacc.wo` 10752×0；`bn.rshi` 5412×0；`bn.and` 4608×0 … | `bn.mulqacc.wo` 0、`bn.rshi` 0、`bn.and` 0、`bn.add` 0、`bn.addm` 0、`bn.lid` 396、`bn.subm` 0、`addi` 0、`bn.sid` 96、`bn.or` 0、 … | 504 | 6 | ✓ |
| `NTT` | 子树 | 20 种指令，`bn.mulqacc.wo` 10752×0；`bn.rshi` 8316×0；`bn.and` 8310×0 … | `bn.mulqacc.wo` 0、`bn.rshi` 0、`bn.and` 0、`bn.add` 0、`bn.subm` 0、`bn.addm` 0、`bn.lid` 1,044、`lw` 582、`bn.sid` 462、`sw` 0、 … | 2,094 | 6 | ✓ |
| `INTT` | 子树 | 0 种指令， … |  … | 0 | 0 | — |

**核对**：A(与 kernel_stat 全等) {'mul_modp': None, 'basemul': True, 'basemul_acc': True, 'NTT': True, 'INTT': None}；B(与 RTL 符号行全等) {'mul_modp': None, 'basemul': True, 'basemul_acc': True, 'NTT': None, 'INTT': None}；C 总拍==Σ帧跨度 `mul_modp` 0 == 0 (0 帧, 最深嵌套 0) —；`basemul` 13,812 == 13,812 (3 帧, 最深嵌套 0) ✓；`basemul_acc` 27,924 == 27,924 (6 帧, 最深嵌套 0) ✓；`NTT` 48,798 == 48,798 (6 帧, 最深嵌套 1) ✓；`INTT` 0 == 0 (0 帧, 最深嵌套 0) —

## encap

| kernel | 作用域 | ① 每条 stall（分布） | ② 逐 opcode 合计 | ③ kernel 总 stall | 帧数 | 总拍 == Σ帧跨度 |
|---|---|---|---|---:|---:|---|
| `mul_modp` | 叶 | 0 种指令， … |  … | 0 | 0 | — |
| `basemul` | 叶 | 18 种指令，`bn.mulqacc.wo` 7168×0；`bn.rshi` 3608×0；`bn.and` 3072×0 … | `bn.mulqacc.wo` 0、`bn.rshi` 0、`bn.and` 0、`bn.add` 0、`bn.addm` 0、`bn.subm` 0、`bn.lid` 200、`addi` 0、`bn.sid` 64、`bn.or` 0、 … | 272 | 4 | ✓ |
| `basemul_acc` | 叶 | 18 种指令，`bn.mulqacc.wo` 14336×0；`bn.rshi` 7216×0；`bn.and` 6144×0 … | `bn.mulqacc.wo` 0、`bn.rshi` 0、`bn.and` 0、`bn.add` 0、`bn.addm` 0、`bn.lid` 528、`bn.subm` 0、`addi` 0、`bn.sid` 128、`bn.or` 0 … | 672 | 8 | ✓ |
| `NTT` | 子树 | 20 种指令，`bn.mulqacc.wo` 5376×0；`bn.rshi` 4158×0；`bn.and` 4155×0 … | `bn.mulqacc.wo` 0、`bn.rshi` 0、`bn.and` 0、`bn.add` 0、`bn.subm` 0、`bn.addm` 0、`bn.lid` 522、`lw` 291、`bn.sid` 231、`sw` 0、`a … | 1,047 | 3 | ✓ |
| `INTT` | 子树 | 20 种指令，`bn.mulqacc.wo` 8192×0；`bn.rshi` 6056×0；`bn.and` 6052×0 … | `bn.mulqacc.wo` 0、`bn.rshi` 0、`bn.and` 0、`bn.add` 0、`bn.subm` 0、`bn.addm` 0、`bn.lid` 696、`lw` 388、`bn.sid` 308、`sw` 0、`a … | 1,396 | 4 | ✓ |

**核对**：A(与 kernel_stat 全等) {'mul_modp': None, 'basemul': True, 'basemul_acc': True, 'NTT': True, 'INTT': True}；B(与 RTL 符号行全等) {'mul_modp': None, 'basemul': True, 'basemul_acc': True, 'NTT': None, 'INTT': None}；C 总拍==Σ帧跨度 `mul_modp` 0 == 0 (0 帧, 最深嵌套 0) —；`basemul` 18,416 == 18,416 (4 帧, 最深嵌套 0) ✓；`basemul_acc` 37,232 == 37,232 (8 帧, 最深嵌套 0) ✓；`NTT` 24,399 == 24,399 (3 帧, 最深嵌套 1) ✓；`INTT` 35,084 == 35,084 (4 帧, 最深嵌套 1) ✓

## decap

| kernel | 作用域 | ① 每条 stall（分布） | ② 逐 opcode 合计 | ③ kernel 总 stall | 帧数 | 总拍 == Σ帧跨度 |
|---|---|---|---|---:|---:|---|
| `mul_modp` | 叶 | 0 种指令， … |  … | 0 | 0 | — |
| `basemul` | 叶 | 18 种指令，`bn.mulqacc.wo` 8960×0；`bn.rshi` 4510×0；`bn.and` 3840×0 … | `bn.mulqacc.wo` 0、`bn.rshi` 0、`bn.and` 0、`bn.add` 0、`bn.addm` 0、`bn.subm` 0、`bn.lid` 250、`addi` 0、`bn.sid` 80、`bn.or` 0、 … | 340 | 5 | ✓ |
| `basemul_acc` | 叶 | 18 种指令，`bn.mulqacc.wo` 17920×0；`bn.rshi` 9020×0；`bn.and` 7680×0 … | `bn.mulqacc.wo` 0、`bn.rshi` 0、`bn.and` 0、`bn.add` 0、`bn.addm` 0、`bn.lid` 660、`bn.subm` 0、`addi` 0、`bn.sid` 160、`bn.or` 0 … | 840 | 10 | ✓ |
| `NTT` | 子树 | 20 种指令，`bn.mulqacc.wo` 10752×0；`bn.rshi` 8316×0；`bn.and` 8310×0 … | `bn.mulqacc.wo` 0、`bn.rshi` 0、`bn.and` 0、`bn.add` 0、`bn.subm` 0、`bn.addm` 0、`bn.lid` 1,044、`lw` 582、`bn.sid` 462、`sw` 0、 … | 2,094 | 6 | ✓ |
| `INTT` | 子树 | 20 种指令，`bn.mulqacc.wo` 10240×0；`bn.rshi` 7570×0；`bn.and` 7565×0 … | `bn.mulqacc.wo` 0、`bn.rshi` 0、`bn.and` 0、`bn.add` 0、`bn.subm` 0、`bn.addm` 0、`bn.lid` 870、`lw` 485、`bn.sid` 385、`sw` 0、`a … | 1,745 | 5 | ✓ |

**核对**：A(与 kernel_stat 全等) {'mul_modp': None, 'basemul': True, 'basemul_acc': True, 'NTT': True, 'INTT': True}；B(与 RTL 符号行全等) {'mul_modp': None, 'basemul': True, 'basemul_acc': True, 'NTT': None, 'INTT': None}；C 总拍==Σ帧跨度 `mul_modp` 0 == 0 (0 帧, 最深嵌套 0) —；`basemul` 23,020 == 23,020 (5 帧, 最深嵌套 0) ✓；`basemul_acc` 46,540 == 46,540 (10 帧, 最深嵌套 0) ✓；`NTT` 48,798 == 48,798 (6 帧, 最深嵌套 1) ✓；`INTT` 43,855 == 43,855 (5 帧, 最深嵌套 1) ✓

**判据 B（P-256，逐会话）**：与 `rtl_trace_p256.json` 的 `mul_modp` 符号行 (retire/stall/fetch_wait) 比对 —— Keygen A ✓、Keygen B ✓、ECDH A ✓、ECDH B ✓。

## P-256（`mul_modp`）逐会话

| 会话 | 动态指令 | stall | 逐 opcode（③） | 帧数 |
|---|---:|---:|---|---:|
| Keygen A | 508429 | 9593 | `bn.mulqacc` 191860×(0+0)、`bn.addm` 76744×(0+0)、`bn.add` 67151×(0+0)、`bn.sub` 47965×(0+0)、`bn.mulqacc.wo` 38372×(0+0)、`bn.rshi` 28779×(0+0)、`bn.mulqacc.so` 19186×(0+0)、`bn.addc` 9593×(0+0)、`bn.subb` 9593×(0+0)、`bn.subm` 9593×(0+0)、`jalr` 9593×(0+9593) | 9593 |
| Keygen B | 508429 | 9593 | `bn.mulqacc` 191860×(0+0)、`bn.addm` 76744×(0+0)、`bn.add` 67151×(0+0)、`bn.sub` 47965×(0+0)、`bn.mulqacc.wo` 38372×(0+0)、`bn.rshi` 28779×(0+0)、`bn.mulqacc.so` 19186×(0+0)、`bn.addc` 9593×(0+0)、`bn.subb` 9593×(0+0)、`bn.subm` 9593×(0+0)、`jalr` 9593×(0+9593) | 9593 |
| ECDH A | 508906 | 9602 | `bn.mulqacc` 192040×(0+0)、`bn.addm` 76816×(0+0)、`bn.add` 67214×(0+0)、`bn.sub` 48010×(0+0)、`bn.mulqacc.wo` 38408×(0+0)、`bn.rshi` 28806×(0+0)、`bn.mulqacc.so` 19204×(0+0)、`bn.addc` 9602×(0+0)、`bn.subb` 9602×(0+0)、`bn.subm` 9602×(0+0)、`jalr` 9602×(0+9602) | 9602 |
| ECDH B | 508906 | 9602 | `bn.mulqacc` 192040×(0+0)、`bn.addm` 76816×(0+0)、`bn.add` 67214×(0+0)、`bn.sub` 48010×(0+0)、`bn.mulqacc.wo` 38408×(0+0)、`bn.rshi` 28806×(0+0)、`bn.mulqacc.so` 19204×(0+0)、`bn.addc` 9602×(0+0)、`bn.subb` 9602×(0+0)、`bn.subm` 9602×(0+0)、`jalr` 9602×(0+9602) | 9602 |

**总判定**：全部 ✓

