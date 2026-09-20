/*
 * ver1_1 剖面（子分解）：keygen_poly_gen_matrix_shake
 * XOF 路径 = 按 app 的会话模式重放 χOF 调用（9 会话 × 25 次），不含采样。
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


  /* 会话 nonce 0x0000（i=0, j=0）：输入 = ρ(32) ‖ j ‖ i = 34 B
     （与 app 的 poly_gen_matrix 逐字一致：LE32 = (i<<8)+j 存到偏移 32） */
  la   x21, expand_buf
  li   x20, 0
  sw   x20, 32(x21)
  li   x20, 34
  addi x22, x0, 0
  jal  x1, xof_shake128_init
  jal  x1, xof_absorb
  jal  x1, xof_process
  la   x20, shake_out
  .rept 21
    jal  x1, xof_squeeze32
    bn.xor w0, w29, w30
    bn.sid x0, 0(x20++)
  .endr
  jal  x1, xof_finish

  /* 会话 nonce 0x0001（i=0, j=1）：输入 = ρ(32) ‖ j ‖ i = 34 B
     （与 app 的 poly_gen_matrix 逐字一致：LE32 = (i<<8)+j 存到偏移 32） */
  la   x21, expand_buf
  li   x20, 1
  sw   x20, 32(x21)
  li   x20, 34
  addi x22, x0, 0
  jal  x1, xof_shake128_init
  jal  x1, xof_absorb
  jal  x1, xof_process
  la   x20, shake_out
  .rept 21
    jal  x1, xof_squeeze32
    bn.xor w0, w29, w30
    bn.sid x0, 0(x20++)
  .endr
  jal  x1, xof_finish

  /* 会话 nonce 0x0002（i=0, j=2）：输入 = ρ(32) ‖ j ‖ i = 34 B
     （与 app 的 poly_gen_matrix 逐字一致：LE32 = (i<<8)+j 存到偏移 32） */
  la   x21, expand_buf
  li   x20, 2
  sw   x20, 32(x21)
  li   x20, 34
  addi x22, x0, 0
  jal  x1, xof_shake128_init
  jal  x1, xof_absorb
  jal  x1, xof_process
  la   x20, shake_out
  .rept 21
    jal  x1, xof_squeeze32
    bn.xor w0, w29, w30
    bn.sid x0, 0(x20++)
  .endr
  jal  x1, xof_finish

  /* 会话 nonce 0x0100（i=1, j=0）：输入 = ρ(32) ‖ j ‖ i = 34 B
     （与 app 的 poly_gen_matrix 逐字一致：LE32 = (i<<8)+j 存到偏移 32） */
  la   x21, expand_buf
  li   x20, 256
  sw   x20, 32(x21)
  li   x20, 34
  addi x22, x0, 0
  jal  x1, xof_shake128_init
  jal  x1, xof_absorb
  jal  x1, xof_process
  la   x20, shake_out
  .rept 21
    jal  x1, xof_squeeze32
    bn.xor w0, w29, w30
    bn.sid x0, 0(x20++)
  .endr
  jal  x1, xof_finish

  /* 会话 nonce 0x0101（i=1, j=1）：输入 = ρ(32) ‖ j ‖ i = 34 B
     （与 app 的 poly_gen_matrix 逐字一致：LE32 = (i<<8)+j 存到偏移 32） */
  la   x21, expand_buf
  li   x20, 257
  sw   x20, 32(x21)
  li   x20, 34
  addi x22, x0, 0
  jal  x1, xof_shake128_init
  jal  x1, xof_absorb
  jal  x1, xof_process
  la   x20, shake_out
  .rept 21
    jal  x1, xof_squeeze32
    bn.xor w0, w29, w30
    bn.sid x0, 0(x20++)
  .endr
  jal  x1, xof_finish

  /* 会话 nonce 0x0102（i=1, j=2）：输入 = ρ(32) ‖ j ‖ i = 34 B
     （与 app 的 poly_gen_matrix 逐字一致：LE32 = (i<<8)+j 存到偏移 32） */
  la   x21, expand_buf
  li   x20, 258
  sw   x20, 32(x21)
  li   x20, 34
  addi x22, x0, 0
  jal  x1, xof_shake128_init
  jal  x1, xof_absorb
  jal  x1, xof_process
  la   x20, shake_out
  .rept 21
    jal  x1, xof_squeeze32
    bn.xor w0, w29, w30
    bn.sid x0, 0(x20++)
  .endr
  jal  x1, xof_finish

  /* 会话 nonce 0x0200（i=2, j=0）：输入 = ρ(32) ‖ j ‖ i = 34 B
     （与 app 的 poly_gen_matrix 逐字一致：LE32 = (i<<8)+j 存到偏移 32） */
  la   x21, expand_buf
  li   x20, 512
  sw   x20, 32(x21)
  li   x20, 34
  addi x22, x0, 0
  jal  x1, xof_shake128_init
  jal  x1, xof_absorb
  jal  x1, xof_process
  la   x20, shake_out
  .rept 21
    jal  x1, xof_squeeze32
    bn.xor w0, w29, w30
    bn.sid x0, 0(x20++)
  .endr
  jal  x1, xof_finish

  /* 会话 nonce 0x0201（i=2, j=1）：输入 = ρ(32) ‖ j ‖ i = 34 B
     （与 app 的 poly_gen_matrix 逐字一致：LE32 = (i<<8)+j 存到偏移 32） */
  la   x21, expand_buf
  li   x20, 513
  sw   x20, 32(x21)
  li   x20, 34
  addi x22, x0, 0
  jal  x1, xof_shake128_init
  jal  x1, xof_absorb
  jal  x1, xof_process
  la   x20, shake_out
  .rept 21
    jal  x1, xof_squeeze32
    bn.xor w0, w29, w30
    bn.sid x0, 0(x20++)
  .endr
  jal  x1, xof_finish

  /* 会话 nonce 0x0202（i=2, j=2）：输入 = ρ(32) ‖ j ‖ i = 34 B
     （与 app 的 poly_gen_matrix 逐字一致：LE32 = (i<<8)+j 存到偏移 32） */
  la   x21, expand_buf
  li   x20, 514
  sw   x20, 32(x21)
  li   x20, 34
  addi x22, x0, 0
  jal  x1, xof_shake128_init
  jal  x1, xof_absorb
  jal  x1, xof_process
  la   x20, shake_out
  .rept 21
    jal  x1, xof_squeeze32
    bn.xor w0, w29, w30
    bn.sid x0, 0(x20++)
  .endr
  jal  x1, xof_finish

  ecall


.section .data
.balign 32
rho:
  .zero 32
.balign 32
expand_buf:
  .zero 64
.balign 32
shake_out:
  .zero 672
/* 栈由 common_data.s 提供（链接它，避免与其它行重复定义 stack） */
