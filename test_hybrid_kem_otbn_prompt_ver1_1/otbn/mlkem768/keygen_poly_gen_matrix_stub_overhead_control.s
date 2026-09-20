/*
 * ver1_1 剖面（子分解）：keygen_poly_gen_matrix_stub_overhead
 * 校准项：只调桩 API（与 χOF 重放同次数），量桩自身开销。
 *
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


  /* 流指针必须先有效（桩的 xof_squeeze32 会读它） */
  la   x6, rejection_stream_ptr
  la   x7, rejection_stream_0000
  sw   x7, 0(x6)

  la   x21, expand_buf
  li   x20, 34
  addi x22, x0, 0
  la   x20, shake_out
  .rept 21
    bn.xor w0, w29, w30
    bn.sid x0, 0(x20++)
  .endr

  la   x21, expand_buf
  li   x20, 34
  addi x22, x0, 0
  la   x20, shake_out
  .rept 21
    bn.xor w0, w29, w30
    bn.sid x0, 0(x20++)
  .endr

  la   x21, expand_buf
  li   x20, 34
  addi x22, x0, 0
  la   x20, shake_out
  .rept 21
    bn.xor w0, w29, w30
    bn.sid x0, 0(x20++)
  .endr

  la   x21, expand_buf
  li   x20, 34
  addi x22, x0, 0
  la   x20, shake_out
  .rept 21
    bn.xor w0, w29, w30
    bn.sid x0, 0(x20++)
  .endr

  la   x21, expand_buf
  li   x20, 34
  addi x22, x0, 0
  la   x20, shake_out
  .rept 21
    bn.xor w0, w29, w30
    bn.sid x0, 0(x20++)
  .endr

  la   x21, expand_buf
  li   x20, 34
  addi x22, x0, 0
  la   x20, shake_out
  .rept 21
    bn.xor w0, w29, w30
    bn.sid x0, 0(x20++)
  .endr

  la   x21, expand_buf
  li   x20, 34
  addi x22, x0, 0
  la   x20, shake_out
  .rept 21
    bn.xor w0, w29, w30
    bn.sid x0, 0(x20++)
  .endr

  la   x21, expand_buf
  li   x20, 34
  addi x22, x0, 0
  la   x20, shake_out
  .rept 21
    bn.xor w0, w29, w30
    bn.sid x0, 0(x20++)
  .endr

  la   x21, expand_buf
  li   x20, 34
  addi x22, x0, 0
  la   x20, shake_out
  .rept 21
    bn.xor w0, w29, w30
    bn.sid x0, 0(x20++)
  .endr

  ecall


.section .data
.balign 32
expand_buf:
  .zero 64
.balign 32
shake_out:
  .zero 672
/* 栈由 common_data.s 提供（链接它，避免与其它行重复定义 stack） */
