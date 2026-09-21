# RTL 实测 · 三版逐函数对照（方法 A）

> 数据来源：`logs_hkem/<版本>/rtl/rtl_trace_{keygen,encap,decap}.json`（由 `test_perf/tools/diag/rtl_trace_attr.py` 从 RTL trace 生成）。
> 口径：表中数字是 **含被调拍 = 帧跨度 `[C1, C2)`**（C1 = 进入函数第一拍，C2 = 调用方恢复执行的那一拍）；叶函数等于「自身拍」；「自身拍」= 退役 + 停滞 + 取指等待，逐函数相加 == 整段跨度。

## keygen

| 函数 | ver0_1（软件 Keccak） 拍 | ver0_2（KMAC 硬件哈希） 拍 | ver1_1（官方向量指令 + KMAC） 拍 |
|---|---:|---:|---:|
| `(框架容器) crypto_kem_keypair` | 550,763 | 167,506 | 130,907 |
| `(框架容器) indcpa_keypair` | 482,218 | 165,074 | 128,022 |
| `poly_gen_matrix` | 307,372 | 47,088 | 46,315 |
| `shake_out` | 228,951 | — | — |
| `keccakf` | 190,146 | — | — |
| `_shake_out_skip` | 117,024 | — | — |
| `ntt` | 48,798 | 48,798 | 13,866 |
| `poly_getnoise_eta_1` | 65,106 | 13,278 | — |
| `sha3_update` | 77,034 | — | — |
| `basemul_acc` | 27,924 | 27,924 | 20,601 |
| `_poly_uniform_inner_loop` | 33,987 | 33,317 | — |
| `shake_xof` | 66,795 | — | — |
| `cbd2` | 10,074 | 10,074 | 15,714 |
| `basemul` | 13,812 | 13,812 | 6,354 |
| `sample_ntt_poly` | — | — | 33,049 |
| `_sample_ntt_loop` | — | — | 32,536 |
| `poly_tobytes` | 3,666 | 3,666 | 21,072 |
| `(无符号区间)` | 8,245 | 8,245 | 7,885 |
| `poly_getnoise_eta_2` | — | — | 19,014 |
| `xof_squeeze32` | — | 6,075 | 9,378 |
| `_rej_sample_loop` | 11,181 | 2,541 | — |
| `poly_reduce` | 5,673 | 5,673 | — |
| `_xof_rsp_valid_poll` | — | 3,754 | 5,986 |
| `_ntt_layers_loop` | — | — | 9,120 |
| `sha3_final` | 9,034 | — | — |
| *其余 38 个函数（自身拍合计）* | 18,237 | 21,288 | 19,288 |

## encap

| 函数 | ver0_1（软件 Keccak） 拍 | ver0_2（KMAC 硬件哈希） 拍 | ver1_1（官方向量指令 + KMAC） 拍 |
|---|---:|---:|---:|
| `(框架容器) crypto_kem_enc` | 599,901 | 207,270 | 162,067 |
| `(框架容器) indcpa_enc` | 525,383 | 204,628 | — |
| `poly_gen_matrix` | 307,372 | 47,088 | 46,315 |
| `shake_out` | 232,707 | — | — |
| `keccakf` | 194,568 | — | — |
| `(框架容器) _encrypt_core` | — | — | 147,503 |
| `_shake_out_skip` | 119,968 | — | — |
| `basemul_acc` | 37,232 | 37,232 | 27,468 |
| `intt` | 35,084 | 35,084 | 10,936 |
| `sha3_update` | 78,580 | — | — |
| `poly_getnoise_eta_2` | 43,404 | 8,852 | 22,183 |
| `shake_xof` | 71,248 | — | — |
| `_poly_uniform_inner_loop` | 33,987 | 33,317 | — |
| `ntt` | 24,399 | 24,399 | 6,933 |
| `basemul` | 18,416 | 18,416 | 6,354 |
| `cbd2` | 11,753 | 11,753 | 18,333 |
| `poly_getnoise_eta_1` | 32,553 | 6,639 | — |
| `sample_ntt_poly` | — | — | 33,049 |
| `_sample_ntt_loop` | — | — | 32,536 |
| `poly_frombytes` | 1,857 | 1,857 | 22,416 |
| `(无符号区间)` | 8,247 | 8,247 | 8,911 |
| `pack_ciphertext` | 8,817 | 8,817 | — |
| `xof_squeeze32` | — | 6,199 | 9,502 |
| `poly_add` | 6,995 | 6,995 | 1,240 |
| `poly_reduce` | 7,564 | 7,564 | — |
| *其余 48 个函数（自身拍合计）* | 35,659 | 31,238 | 39,207 |

## decap

| 函数 | ver0_1（软件 Keccak） 拍 | ver0_2（KMAC 硬件哈希） 拍 | ver1_1（官方向量指令 + KMAC） 拍 |
|---|---:|---:|---:|
| `(框架容器) crypto_kem_dec` | 660,418 | 268,349 | 200,227 |
| `(框架容器) indcpa_enc` | 525,383 | 204,628 | — |
| `poly_gen_matrix` | 307,372 | 47,088 | 46,315 |
| `shake_out` | 233,646 | — | — |
| `keccakf` | 194,568 | — | — |
| `(框架容器) indcpa_enc_uncompressed` | — | — | 134,992 |
| `basemul_acc` | 46,540 | 46,540 | 34,335 |
| `(框架容器) indcpa_dec` | 60,718 | 60,713 | — |
| `_shake_out_skip` | 120,704 | — | — |
| `ntt` | 48,798 | 48,798 | 13,866 |
| `intt` | 43,855 | 43,855 | 13,670 |
| `sha3_update` | 77,054 | — | — |
| `shake_xof` | 75,701 | — | — |
| `poly_getnoise_eta_2` | 43,404 | 8,852 | 22,183 |
| `_poly_uniform_inner_loop` | 33,987 | 33,317 | — |
| `basemul` | 23,020 | 23,020 | 12,708 |
| `(框架容器) _decrypt_core` | — | — | 48,728 |
| `cbd2` | 11,753 | 11,753 | 18,333 |
| `poly_getnoise_eta_1` | 32,553 | 6,639 | — |
| `sample_ntt_poly` | — | — | 33,049 |
| `(无符号区间)` | 8,245 | 8,245 | 16,237 |
| `_sample_ntt_loop` | — | — | 32,536 |
| `poly_frombytes` | 3,714 | 3,714 | 22,416 |
| `poly_reduce` | 9,455 | 9,455 | — |
| `pack_ciphertext` | 8,817 | 8,817 | — |
| *其余 62 个函数（自身拍合计）* | 52,381 | 49,575 | 65,041 |

