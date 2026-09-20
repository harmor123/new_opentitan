/*
 * ver0_2 剖面（实测行）：decap_pack_ciphertext_control
 * decap 比较前的再压缩：1 次 pack_ciphertext（与 encap 同一内核与调用点）。
 *
 * 本文件由 test_perf/gen_harness.py 生成（--version ver0_2）。
 * 与同 row 的另一个目标逐条对应，仅差调用 —— Δcycles = profiling − control。
 */
.section .text.start

.globl main
main:
  /* 与 app（mlkem_decap.s）一致的确定性 WDR 初始化 */
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

  /* 独立栈：ver0_2 内核用 fp 相对寻址（与 app 的 wrapper 同布局） */
  la   x2, stack
  li   x3, 4096
  add  x2, x2, x3
  addi fp, x2, 0

la   x10, b_polyvec
la   x11, v_poly
la   x12, ciphertext
la   x13, const_1290167
la   x14, modulus_bn
la   x15, modulus_over_2

  ecall


.section .data
.balign 32
b_polyvec:
  .zero 1536

.balign 32
v_poly:
  .zero 512

.balign 32
ciphertext:
  .zero 1088
stack:
  .zero 4096
