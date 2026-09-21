# RTL 实测 · 三版逐函数对照（方法 A）

> 数据来源：`logs_hkem/<版本>/rtl/rtl_trace_{keygen,encap,decap}.json`（由 `test_perf/tools/diag/rtl_trace_attr.py` 从 RTL trace 生成）。
> 口径：表中数字是 **含被调拍**（从进入函数到离开函数的整段，图上 `C2 − C1`）；「自身拍」= 退役 + 停滞 + 取指等待，逐函数相加 == 整段跨度。

## keygen

| 函数 | ver0_1（软件 Keccak） 拍 | ver0_2（KMAC 硬件哈希） 拍 | ver1_1（官方向量指令 + KMAC） 拍 |
|---|---:|---:|---:|
| `poly_gen_matrix` | 307,354 | 47,070 | 46,297 |
| `shake_out` | 228,474 | — | — |
| `keccakf` | 190,060 | — | — |
| `_shake_out_skip` | 117,024 | — | — |
| `ntt` | 48,786 | 48,786 | 13,854 |
| `poly_getnoise_eta_1` | 65,094 | 13,266 | — |
| `sha3_update` | 76,935 | — | — |
| `basemul_acc` | 27,912 | 27,912 | 20,583 |
| `_poly_uniform_inner_loop` | 33,719 | 33,049 | — |
| `shake_xof` | 66,765 | — | — |
| `cbd2` | 10,062 | 10,062 | 15,702 |
| `basemul` | 13,806 | 13,806 | 6,348 |
| `sample_ntt_poly` | — | — | 33,031 |
| `_sample_ntt_loop` | — | — | 32,536 |
| `poly_tobytes` | 3,654 | 3,654 | 21,060 |
| `(无符号区间)` | 8,245 | 8,245 | 7,885 |
| `poly_getnoise_eta_2` | — | — | 19,002 |
| `xof_squeeze32` | — | 5,751 | 8,946 |
| `_rej_sample_loop` | 11,181 | 2,541 | — |
| `poly_reduce` | 5,667 | 5,667 | — |
| `_xof_rsp_valid_poll` | — | 3,650 | 5,864 |
| `_ntt_layers_loop` | — | — | 9,120 |
| `sha3_final` | 9,030 | — | — |
| `poly_add` | 4,191 | 4,191 | — |
| `_xof_squeeze32_recharge` | — | 3,564 | 4,752 |
| *其余 38 个函数（自身拍合计）* | 14,501 | 13,991 | 14,762 |

## encap

| 函数 | ver0_1（软件 Keccak） 拍 | ver0_2（KMAC 硬件哈希） 拍 | ver1_1（官方向量指令 + KMAC） 拍 |
|---|---:|---:|---:|
| `poly_gen_matrix` | 307,354 | 47,070 | 46,297 |
| `shake_out` | 232,218 | — | — |
| `keccakf` | 194,480 | — | — |
| `_shake_out_skip` | 119,968 | — | — |
| `basemul_acc` | 37,216 | 37,216 | 27,444 |
| `intt` | 35,076 | 35,076 | 10,928 |
| `sha3_update` | 78,478 | — | — |
| `poly_getnoise_eta_2` | 43,396 | 8,844 | 22,169 |
| `shake_xof` | 71,216 | — | — |
| `_poly_uniform_inner_loop` | 33,719 | 33,049 | — |
| `ntt` | 24,393 | 24,393 | 6,927 |
| `basemul` | 18,408 | 18,408 | 6,348 |
| `cbd2` | 11,739 | 11,739 | 18,319 |
| `poly_getnoise_eta_1` | 32,547 | 6,633 | — |
| `sample_ntt_poly` | — | — | 33,031 |
| `_sample_ntt_loop` | — | — | 32,536 |
| `poly_frombytes` | 1,851 | 1,851 | 22,404 |
| `(无符号区间)` | 8,247 | 8,247 | 8,911 |
| `pack_ciphertext` | 8,815 | 8,815 | — |
| `poly_add` | 6,985 | 6,985 | 1,230 |
| `poly_reduce` | 7,556 | 7,556 | — |
| `xof_squeeze32` | — | 5,867 | 9,062 |
| `polyvec_compress` | 7,406 | 7,406 | — |
| `_rej_sample_loop` | 11,181 | 2,541 | — |
| `compress_10` | — | — | 10,932 |
| *其余 48 个函数（自身拍合计）* | 22,969 | 27,198 | 38,440 |

## decap

| 函数 | ver0_1（软件 Keccak） 拍 | ver0_2（KMAC 硬件哈希） 拍 | ver1_1（官方向量指令 + KMAC） 拍 |
|---|---:|---:|---:|
| `poly_gen_matrix` | 307,354 | 47,070 | 46,297 |
| `shake_out` | 233,154 | — | — |
| `keccakf` | 194,480 | — | — |
| `basemul_acc` | 46,520 | 46,520 | 34,305 |
| `_shake_out_skip` | 120,704 | — | — |
| `ntt` | 48,786 | 48,786 | 13,854 |
| `intt` | 43,845 | 43,845 | 13,660 |
| `sha3_update` | 76,949 | — | — |
| `shake_xof` | 75,667 | — | — |
| `poly_getnoise_eta_2` | 43,396 | 8,844 | 22,169 |
| `_poly_uniform_inner_loop` | 33,719 | 33,049 | — |
| `basemul` | 23,010 | 23,010 | 12,696 |
| `cbd2` | 11,739 | 11,739 | 18,319 |
| `poly_getnoise_eta_1` | 32,547 | 6,633 | — |
| `sample_ntt_poly` | — | — | 33,031 |
| `(无符号区间)` | 8,245 | 8,245 | 16,237 |
| `_sample_ntt_loop` | — | — | 32,536 |
| `poly_frombytes` | 3,702 | 3,702 | 22,404 |
| `poly_reduce` | 9,445 | 9,445 | — |
| `pack_ciphertext` | 8,815 | 8,815 | — |
| `unpack_ciphertext` | 8,260 | 8,260 | — |
| `poly_add` | 6,985 | 6,985 | 1,230 |
| `xof_squeeze32` | — | 5,867 | 9,062 |
| `polyvec_compress` | 7,406 | 7,406 | — |
| `_rej_sample_loop` | 11,181 | 2,541 | — |
| *其余 62 个函数（自身拍合计）* | 33,138 | 37,431 | 63,060 |

