# stall 三级独立复核 · ver1_1

> 全部数字由 `test_perf/tools/diag/verify_stall_levels.py` **从 RTL trace 重算**；
> ①=每条动态指令自己的 stall，②=同 opcode 求和，③=kernel 总 stall（停滞+取指等待）。

## keygen

| kernel | 作用域 | ① 每条 stall（分布） | ② 逐 opcode 合计 | ③ kernel 总 stall | 帧数 | 总拍 == Σ帧跨度 |
|---|---|---|---|---:|---:|---|
| `mul_modp` | 叶 | 0 种指令， … |  … | 0 | 0 | — |
| `basemul` | 叶 | 14 种指令，`bn.mulvm` 384×11；`bn.rshi` 384×0；`bn.lid` 288×1 … | `bn.mulvm` 4,224、`bn.rshi` 0、`bn.lid` 288、`bn.addvm` 0、`bn.and` 0、`bn.or` 0、`bn.sid` 96、`addi` 0、`sw` 0、`lw` 18、`bn.not` … | 4,629 | 3 | ✓ |
| `basemul_acc` | 叶 | 14 种指令，`bn.rshi` 1440×0；`bn.lid` 1152×1；`bn.mulvm` 1152×11 … | `bn.rshi` 0、`bn.lid` 1,152、`bn.mulvm` 12,672、`bn.addvm` 0、`bn.and` 0、`bn.or` 0、`bn.sid` 288、`addi` 0、`sw` 0、`lw` 72、`bn. … | 14,193 | 9 | ✓ |
| `NTT` | 子树 | 15 种指令，`bn.addvm` 1344×0；`bn.subvm` 672×0；`bn.trn1` 576×0 … | `bn.addvm` 0、`bn.subvm` 0、`bn.trn1` 0、`bn.trn2` 0、`bn.lid` 486、`bn.mulvml` 5,280、`bn.sid` 384、`addi` 0、`bn.mulvm` 2,112、 … | 8,532 | 6 | ✓ |
| `INTT` | 子树 | 0 种指令， … |  … | 0 | 0 | — |

**核对**：A(与 kernel_stat 全等) {'mul_modp': None, 'basemul': True, 'basemul_acc': True, 'NTT': True, 'INTT': None}；B(与 RTL 符号行全等) {'mul_modp': None, 'basemul': True, 'basemul_acc': True, 'NTT': None, 'INTT': None}；C 总拍==Σ帧跨度 `mul_modp` 0 == 0 (0 帧, 最深嵌套 0) —；`basemul` 6,354 == 6,354 (3 帧, 最深嵌套 0) ✓；`basemul_acc` 20,601 == 20,601 (9 帧, 最深嵌套 0) ✓；`NTT` 13,866 == 13,866 (6 帧, 最深嵌套 1) ✓；`INTT` 0 == 0 (0 帧, 最深嵌套 0) —

## encap

| kernel | 作用域 | ① 每条 stall（分布） | ② 逐 opcode 合计 | ③ kernel 总 stall | 帧数 | 总拍 == Σ帧跨度 |
|---|---|---|---|---:|---:|---|
| `mul_modp` | 叶 | 0 种指令， … |  … | 0 | 0 | — |
| `basemul` | 叶 | 14 种指令，`bn.mulvm` 384×11；`bn.rshi` 384×0；`bn.lid` 288×1 … | `bn.mulvm` 4,224、`bn.rshi` 0、`bn.lid` 288、`bn.addvm` 0、`bn.and` 0、`bn.or` 0、`bn.sid` 96、`addi` 0、`sw` 0、`lw` 18、`bn.not` … | 4,629 | 3 | ✓ |
| `basemul_acc` | 叶 | 14 种指令，`bn.rshi` 1920×0；`bn.lid` 1536×1；`bn.mulvm` 1536×11 … | `bn.rshi` 0、`bn.lid` 1,536、`bn.mulvm` 16,896、`bn.addvm` 0、`bn.and` 0、`bn.or` 0、`bn.sid` 384、`addi` 0、`sw` 0、`lw` 96、`bn. … | 18,924 | 12 | ✓ |
| `NTT` | 子树 | 15 种指令，`bn.addvm` 672×0；`bn.subvm` 336×0；`bn.trn1` 288×0 … | `bn.addvm` 0、`bn.subvm` 0、`bn.trn1` 0、`bn.trn2` 0、`bn.lid` 243、`bn.mulvml` 2,640、`bn.sid` 192、`addi` 0、`bn.mulvm` 1,056、 … | 4,266 | 3 | ✓ |
| `INTT` | 子树 | 15 种指令，`bn.addvm` 1024×0；`bn.subvm` 448×0；`bn.mulvml` 448×11 … | `bn.addvm` 0、`bn.subvm` 0、`bn.mulvml` 4,928、`bn.trn1` 0、`bn.trn2` 0、`bn.lid` 324、`bn.sid` 256、`addi` 0、`bn.mulvm` 1,408、 … | 7,100 | 4 | ✓ |

**核对**：A(与 kernel_stat 全等) {'mul_modp': None, 'basemul': True, 'basemul_acc': True, 'NTT': True, 'INTT': True}；B(与 RTL 符号行全等) {'mul_modp': None, 'basemul': True, 'basemul_acc': True, 'NTT': None, 'INTT': None}；C 总拍==Σ帧跨度 `mul_modp` 0 == 0 (0 帧, 最深嵌套 0) —；`basemul` 6,354 == 6,354 (3 帧, 最深嵌套 0) ✓；`basemul_acc` 27,468 == 27,468 (12 帧, 最深嵌套 0) ✓；`NTT` 6,933 == 6,933 (3 帧, 最深嵌套 1) ✓；`INTT` 10,936 == 10,936 (4 帧, 最深嵌套 1) ✓

## decap

| kernel | 作用域 | ① 每条 stall（分布） | ② 逐 opcode 合计 | ③ kernel 总 stall | 帧数 | 总拍 == Σ帧跨度 |
|---|---|---|---|---:|---:|---|
| `mul_modp` | 叶 | 0 种指令， … |  … | 0 | 0 | — |
| `basemul` | 叶 | 14 种指令，`bn.mulvm` 768×11；`bn.rshi` 768×0；`bn.lid` 576×1 … | `bn.mulvm` 8,448、`bn.rshi` 0、`bn.lid` 576、`bn.addvm` 0、`bn.and` 0、`bn.or` 0、`bn.sid` 192、`addi` 0、`sw` 0、`lw` 36、`bn.not … | 9,258 | 6 | ✓ |
| `basemul_acc` | 叶 | 14 种指令，`bn.rshi` 2400×0；`bn.lid` 1920×1；`bn.mulvm` 1920×11 … | `bn.rshi` 0、`bn.lid` 1,920、`bn.mulvm` 21,120、`bn.addvm` 0、`bn.and` 0、`bn.or` 0、`bn.sid` 480、`addi` 0、`sw` 0、`lw` 120、`bn … | 23,655 | 15 | ✓ |
| `NTT` | 子树 | 15 种指令，`bn.addvm` 1344×0；`bn.subvm` 672×0；`bn.trn1` 576×0 … | `bn.addvm` 0、`bn.subvm` 0、`bn.trn1` 0、`bn.trn2` 0、`bn.lid` 486、`bn.mulvml` 5,280、`bn.sid` 384、`addi` 0、`bn.mulvm` 2,112、 … | 8,532 | 6 | ✓ |
| `INTT` | 子树 | 15 种指令，`bn.addvm` 1280×0；`bn.subvm` 560×0；`bn.mulvml` 560×11 … | `bn.addvm` 0、`bn.subvm` 0、`bn.mulvml` 6,160、`bn.trn1` 0、`bn.trn2` 0、`bn.lid` 405、`bn.sid` 320、`addi` 0、`bn.mulvm` 1,760、 … | 8,875 | 5 | ✓ |

**核对**：A(与 kernel_stat 全等) {'mul_modp': None, 'basemul': True, 'basemul_acc': True, 'NTT': True, 'INTT': True}；B(与 RTL 符号行全等) {'mul_modp': None, 'basemul': True, 'basemul_acc': True, 'NTT': None, 'INTT': None}；C 总拍==Σ帧跨度 `mul_modp` 0 == 0 (0 帧, 最深嵌套 0) —；`basemul` 12,708 == 12,708 (6 帧, 最深嵌套 0) ✓；`basemul_acc` 34,335 == 34,335 (15 帧, 最深嵌套 0) ✓；`NTT` 13,866 == 13,866 (6 帧, 最深嵌套 1) ✓；`INTT` 13,670 == 13,670 (5 帧, 最深嵌套 1) ✓

**判据 B（P-256，逐会话）**：与 `rtl_trace_p256.json` 的 `mul_modp` 符号行 (retire/stall/fetch_wait) 比对 —— Keygen A ✓、Keygen B ✓、ECDH A ✓、ECDH B ✓。

## P-256（`mul_modp`）逐会话

| 会话 | 动态指令 | stall | 逐 opcode（③） | 帧数 |
|---|---:|---:|---|---:|
| Keygen A | 508429 | 9593 | `bn.mulqacc` 191860×(0+0)、`bn.addm` 76744×(0+0)、`bn.add` 67151×(0+0)、`bn.sub` 47965×(0+0)、`bn.mulqacc.wo` 38372×(0+0)、`bn.rshi` 28779×(0+0)、`bn.mulqacc.so` 19186×(0+0)、`bn.addc` 9593×(0+0)、`bn.subb` 9593×(0+0)、`bn.subm` 9593×(0+0)、`jalr` 9593×(0+9593) | 9593 |
| Keygen B | 508429 | 9593 | `bn.mulqacc` 191860×(0+0)、`bn.addm` 76744×(0+0)、`bn.add` 67151×(0+0)、`bn.sub` 47965×(0+0)、`bn.mulqacc.wo` 38372×(0+0)、`bn.rshi` 28779×(0+0)、`bn.mulqacc.so` 19186×(0+0)、`bn.addc` 9593×(0+0)、`bn.subb` 9593×(0+0)、`bn.subm` 9593×(0+0)、`jalr` 9593×(0+9593) | 9593 |
| ECDH A | 508906 | 9602 | `bn.mulqacc` 192040×(0+0)、`bn.addm` 76816×(0+0)、`bn.add` 67214×(0+0)、`bn.sub` 48010×(0+0)、`bn.mulqacc.wo` 38408×(0+0)、`bn.rshi` 28806×(0+0)、`bn.mulqacc.so` 19204×(0+0)、`bn.addc` 9602×(0+0)、`bn.subb` 9602×(0+0)、`bn.subm` 9602×(0+0)、`jalr` 9602×(0+9602) | 9602 |
| ECDH B | 508906 | 9602 | `bn.mulqacc` 192040×(0+0)、`bn.addm` 76816×(0+0)、`bn.add` 67214×(0+0)、`bn.sub` 48010×(0+0)、`bn.mulqacc.wo` 38408×(0+0)、`bn.rshi` 28806×(0+0)、`bn.mulqacc.so` 19204×(0+0)、`bn.addc` 9602×(0+0)、`bn.subb` 9602×(0+0)、`bn.subm` 9602×(0+0)、`jalr` 9602×(0+9602) | 9602 |

**总判定**：全部 ✓

