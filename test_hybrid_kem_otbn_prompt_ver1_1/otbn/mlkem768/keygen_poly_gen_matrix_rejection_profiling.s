/*
 * ver1_1 剖面（子分解）：keygen_poly_gen_matrix_rejection
 * 真 gen_matrix ×9（i 外 j 内），χOF 由桩替换为预计算流 ⇒ 只测拒绝采样循环。
 *
 * 本文件由 test_perf/emit_stub_rows_ver1_1.py 生成；control 由 profiling 删 jal 派生。
 */
.section .text.start

.globl main
main:
  /* 与 app 一致的确定性 WDR 初始化 */
  bn.xor w0, w0, w0
  bn.xor w1, w1, w1
  bn.xor w2, w2, w2
  bn.xor w3, w3, w3
  bn.xor w4, w4, w4
  bn.xor w5, w5, w5
  bn.xor w6, w6, w6
  bn.xor w7, w7, w7
  bn.xor w8, w8, w8
  bn.xor w9, w9, w9
  bn.xor w10, w10, w10
  bn.xor w11, w11, w11
  bn.xor w12, w12, w12
  bn.xor w13, w13, w13
  bn.xor w14, w14, w14
  bn.xor w15, w15, w15
  bn.xor w16, w16, w16
  bn.xor w17, w17, w17
  bn.xor w18, w18, w18
  bn.xor w19, w19, w19
  bn.xor w20, w20, w20
  bn.xor w21, w21, w21
  bn.xor w22, w22, w22
  bn.xor w23, w23, w23
  bn.xor w24, w24, w24
  bn.xor w25, w25, w25
  bn.xor w26, w26, w26
  bn.xor w27, w27, w27
  bn.xor w28, w28, w28
  bn.xor w29, w29, w29
  bn.xor w30, w30, w30
  bn.xor w31, w31, w31

  /* app 入口同样把栈指针放 x31（内核/桩都用 0(x31) 压栈；stack 来自 common_data.s） */
  la   x31, stack


  /* A[0][0]：流指针指向本会话段 */
  la   x6, rejection_stream_ptr
  la   x7, rejection_stream_0000
  sw   x7, 0(x6)
  la   x2, rho
  li   x3, 0
  li   x4, 0
  la   x5, out_poly_0000
  jal  x1, poly_gen_matrix

  /* A[0][1]：流指针指向本会话段 */
  la   x6, rejection_stream_ptr
  la   x7, rejection_stream_0001
  sw   x7, 0(x6)
  la   x2, rho
  li   x3, 1
  li   x4, 0
  la   x5, out_poly_0001
  jal  x1, poly_gen_matrix

  /* A[0][2]：流指针指向本会话段 */
  la   x6, rejection_stream_ptr
  la   x7, rejection_stream_0002
  sw   x7, 0(x6)
  la   x2, rho
  li   x3, 2
  li   x4, 0
  la   x5, out_poly_0002
  jal  x1, poly_gen_matrix

  /* A[1][0]：流指针指向本会话段 */
  la   x6, rejection_stream_ptr
  la   x7, rejection_stream_0100
  sw   x7, 0(x6)
  la   x2, rho
  li   x3, 0
  li   x4, 1
  la   x5, out_poly_0100
  jal  x1, poly_gen_matrix

  /* A[1][1]：流指针指向本会话段 */
  la   x6, rejection_stream_ptr
  la   x7, rejection_stream_0101
  sw   x7, 0(x6)
  la   x2, rho
  li   x3, 1
  li   x4, 1
  la   x5, out_poly_0101
  jal  x1, poly_gen_matrix

  /* A[1][2]：流指针指向本会话段 */
  la   x6, rejection_stream_ptr
  la   x7, rejection_stream_0102
  sw   x7, 0(x6)
  la   x2, rho
  li   x3, 2
  li   x4, 1
  la   x5, out_poly_0102
  jal  x1, poly_gen_matrix

  /* A[2][0]：流指针指向本会话段 */
  la   x6, rejection_stream_ptr
  la   x7, rejection_stream_0200
  sw   x7, 0(x6)
  la   x2, rho
  li   x3, 0
  li   x4, 2
  la   x5, out_poly_0200
  jal  x1, poly_gen_matrix

  /* A[2][1]：流指针指向本会话段 */
  la   x6, rejection_stream_ptr
  la   x7, rejection_stream_0201
  sw   x7, 0(x6)
  la   x2, rho
  li   x3, 1
  li   x4, 2
  la   x5, out_poly_0201
  jal  x1, poly_gen_matrix

  /* A[2][2]：流指针指向本会话段 */
  la   x6, rejection_stream_ptr
  la   x7, rejection_stream_0202
  sw   x7, 0(x6)
  la   x2, rho
  li   x3, 2
  li   x4, 2
  la   x5, out_poly_0202
  jal  x1, poly_gen_matrix

  ecall


.section .data
.balign 32
rho:
  .zero 64
.balign 32
out_poly_0000:
  .zero 1024
.balign 32
out_poly_0001:
  .zero 1024
.balign 32
out_poly_0002:
  .zero 1024
.balign 32
out_poly_0100:
  .zero 1024
.balign 32
out_poly_0101:
  .zero 1024
.balign 32
out_poly_0102:
  .zero 1024
.balign 32
out_poly_0200:
  .zero 1024
.balign 32
out_poly_0201:
  .zero 1024
.balign 32
out_poly_0202:
  .zero 1024
/* 栈由 common_data.s 提供（链接它，避免重复定义 stack） */
