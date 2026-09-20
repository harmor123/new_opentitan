/*
 * ver1_1 harness 剖面目标的共享数据（内核常量 + 工作缓冲）
 *
 * 只放"被链接的内核 .s 在代码里真的引用"的符号 —— 用
 *     python3 test_perf/otbn_symbol_check.py --build <BUILD>
 * 静态扫出来的清单，取值与 app（test/mlkem_base_*_test.s）逐字一致。
 *
 * 引用方（ver1_1 内核）：
 *   poly.s            : _expand_buf, _compress_recip_m, _compress_offset_1664,
 *                       _compress_modulus_3329, _decompress_const_1665
 *   poly_gen_matrix.s : _expand_buf
 *   pack_ciphertext.s : _compress_recip_m, _compress_offset_1664, _compress_modulus_3329
 *   其余内核（ntt / intt / basemul / cbd / pack_keys / xof）: 无数据依赖
 *
 * 各剖面 .s 自己只用 mlkem768_const_params（装 MOD CSR）和 stack（x31）。
 */

.section .scratchpad
.balign 32

/* 栈：ver1_1 内核用 sw ..., 0(x31) 向上压栈，x31 必须有效。
 * 与 app 一样放在 scratchpad（NOLOAD，不进镜像），并留足 4096 B。 */
.globl stack
stack:
  .zero 4096

/* SHAKE 挤压缓冲（672 B = 21 WDR，与 app 的 _expand_buf 同尺寸）：
 * poly_gen_matrix（SHAKE128）、poly_getnoise_eta_1（SHAKE256）共用。 */
.balign 32
.globl _expand_buf
_expand_buf:
  .zero 672


.section .data
.balign 32

/* ML-KEM 常数：与 test/mlkem_base_decap_test.s 的取值逐字一致 */
.globl mlkem768_const_params
mlkem768_const_params:
.word 0x00000d01
.word 0x94570cff
.word 0x00000000
.word 0x00000000
.word 0x00000000
.word 0x00000000
.word 0x00000000
.word 0x00000000

.balign 32
.globl _compress_recip_m
_compress_recip_m:
.word 1290168, 0, 1290168, 1290168, 1290168, 1290168, 1290168, 1290168

.balign 32
.globl _compress_offset_1664
_compress_offset_1664:
.word 1664, 1664, 1664, 1664, 1664, 1664, 1664, 1664

.balign 32
.globl _compress_modulus_3329
_compress_modulus_3329:
.word 3329, 0x94570cff, 0, 0, 0, 0, 0, 0

.balign 32
.globl _decompress_const_1665
_decompress_const_1665:
.word 1665, 1665, 1665, 1665, 1665, 1665, 1665, 1665
