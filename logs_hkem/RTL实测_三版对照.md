# RTL 实测 · 三版逐函数对照（方法 A）

> 数据来源：`logs_hkem/<版本>/rtl/rtl_trace_{keygen,encap,decap}.json`（由 `test_perf/tools/diag/rtl_trace_attr.py` 从 RTL trace 生成）。
> 口径：表中数字是 **含被调拍**（从进入函数到离开函数的整段，图上 `C2 − C1`）；「自身拍」= 退役 + 停滞 + 取指等待，逐函数相加 == 整段跨度。

## keygen

| 函数 | ver0_1（软件 Keccak） 拍 | ver0_2（KMAC 硬件哈希） 拍 | ver1_1（官方向量指令 + KMAC） 拍 |
|---|---:|---:|---:|
| `keccakf` | 190,146 | — | — |
| `_shake_out_skip` | 117,024 | — | — |
| `ntt` | 48,798 | 48,798 | 90 |
| `basemul_acc` | 27,924 | 27,924 | 20,601 |
| `_poly_uniform_inner_loop` | 30,637 | 30,369 | — |
| `sha3_update` | 39,838 | — | — |
| `cbd2` | 10,074 | 10,074 | 15,714 |
| `basemul` | 13,812 | 13,812 | 6,354 |
| `_sample_ntt_loop` | — | — | 32,536 |
| `shake_out` | 31,854 | — | — |
| `poly_tobytes` | 3,666 | 3,666 | 21,072 |
| `(无符号区间)` | 8,245 | 8,245 | 7,885 |
| `_rej_sample_loop` | 11,181 | 2,541 | — |
| `poly_reduce` | 5,673 | 5,673 | — |
| `_ntt_layers_loop` | — | — | 9,120 |
| `poly_add` | 4,197 | 4,197 | — |
| `_xof_squeeze32_recharge` | — | 3,564 | 4,752 |
| `_skip_store2` | 5,997 | 1,677 | — |
| `_xof_rsp_valid_poll_time_remaining` | — | 2,726 | 4,328 |
| `_skip_store1` | 3,350 | 2,948 | — |
| `xof_squeeze32` | — | 1,512 | 2,025 |
| `xof_absorb` | — | 1,515 | 1,471 |
| `_xof_ready_poll_time_remaining` | — | 1,470 | 1,470 |
| `_xof_rsp_valid_poll` | — | 1,028 | 1,658 |
| `_sha3_update_skip` | 1,721 | — | — |
| *其余 38 个函数（自身拍合计）* | 4,871 | 4,012 | 9,716 |

## encap

| 函数 | ver0_1（软件 Keccak） 拍 | ver0_2（KMAC 硬件哈希） 拍 | ver1_1（官方向量指令 + KMAC） 拍 |
|---|---:|---:|---:|
| `keccakf` | 194,568 | — | — |
| `_shake_out_skip` | 119,968 | — | — |
| `basemul_acc` | 37,232 | 37,232 | 27,468 |
| `intt` | 35,084 | 35,084 | 8,920 |
| `_poly_uniform_inner_loop` | 30,637 | 30,369 | — |
| `ntt` | 24,399 | 24,399 | 45 |
| `basemul` | 18,416 | 18,416 | 6,354 |
| `cbd2` | 11,753 | 11,753 | 18,333 |
| `sha3_update` | 41,317 | — | — |
| `shake_out` | 32,654 | — | — |
| `_sample_ntt_loop` | — | — | 32,536 |
| `poly_frombytes` | 1,857 | 1,857 | 22,416 |
| `(无符号区间)` | 8,247 | 8,247 | 8,911 |
| `poly_add` | 6,995 | 6,995 | 1,240 |
| `poly_reduce` | 7,564 | 7,564 | — |
| `_rej_sample_loop` | 11,181 | 2,541 | — |
| `polyvec_compress_16` | 5,520 | 5,520 | — |
| `encode_10` | — | — | 8,982 |
| `_xof_squeeze32_recharge` | — | 3,652 | 4,840 |
| `_skip_store2` | 5,997 | 1,677 | — |
| `_xof_rsp_valid_poll_time_remaining` | — | 2,877 | 4,479 |
| `_skip_store1` | 3,350 | 2,948 | — |
| `_ntt_layers_loop` | — | — | 4,560 |
| `polyvec_compress` | 1,888 | 1,888 | — |
| `poly_frommsg` | 1,353 | 1,353 | 958 |
| *其余 48 个函数（自身拍合计）* | 8,168 | 11,145 | 20,936 |

## decap

| 函数 | ver0_1（软件 Keccak） 拍 | ver0_2（KMAC 硬件哈希） 拍 | ver1_1（官方向量指令 + KMAC） 拍 |
|---|---:|---:|---:|
| `keccakf` | 194,568 | — | — |
| `basemul_acc` | 46,540 | 46,540 | 34,335 |
| `_shake_out_skip` | 120,704 | — | — |
| `intt` | 43,855 | 43,855 | 11,150 |
| `ntt` | 48,798 | 48,798 | 90 |
| `_poly_uniform_inner_loop` | 30,637 | 30,369 | — |
| `basemul` | 23,020 | 23,020 | 12,708 |
| `cbd2` | 11,753 | 11,753 | 18,333 |
| `sha3_update` | 39,852 | — | — |
| `shake_out` | 32,854 | — | — |
| `(无符号区间)` | 8,245 | 8,245 | 16,237 |
| `_sample_ntt_loop` | — | — | 32,536 |
| `poly_frombytes` | 3,714 | 3,714 | 22,416 |
| `poly_reduce` | 9,455 | 9,455 | — |
| `poly_add` | 6,995 | 6,995 | 1,240 |
| `_rej_sample_loop` | 11,181 | 2,541 | — |
| `polyvec_compress_16` | 5,520 | 5,520 | — |
| `decode_10` | — | — | 9,654 |
| `polyvec_decompress_16` | 4,752 | 4,752 | — |
| `_ntt_layers_loop` | — | — | 9,120 |
| `encode_10` | — | — | 8,982 |
| `_xof_squeeze32_recharge` | — | 3,652 | 4,840 |
| `_skip_store2` | 5,997 | 1,677 | — |
| `_xof_rsp_valid_poll_time_remaining` | — | 2,882 | 4,484 |
| `_skip_store1` | 3,350 | 2,948 | — |
| *其余 62 个函数（自身拍合计）* | 16,873 | 19,878 | 30,339 |

