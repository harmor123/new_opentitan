/*
 * ver1_1 对照：decap_shake_z_ct（同样的前奏，不发起 KMAC 驱动调用）
 *
 * Δcycles = decap_shake_z_ct_profiling − 本目标。
 */
.section .text.start

.globl main
main:
  /* 与 app（mlkem_decap.s）一致的确定性 WDR 初始化 */
  bn.xor w0,  w0,  w0
  bn.xor w1,  w1,  w1
  bn.xor w2,  w2,  w2
  bn.xor w3,  w3,  w3
  bn.xor w4,  w4,  w4
  bn.xor w5,  w5,  w5
  bn.xor w6,  w6,  w6
  bn.xor w7,  w7,  w7
  bn.xor w8,  w8,  w8
  bn.xor w9,  w9,  w9
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

  /* 栈指针 x31 ← stack（app 的 crypto_kem_dec 入口同样写法） */
  la   x31, stack
  bn.xor w31, w31, w31

  /* 与 profiling 相同的操作数准备，但不发起调用 */
  la   x21, input_z
  la   x22, input_z_share1
  li   x20, 32

  la   x21, input_ct_u
  li   x20, 960
  li   x22, 0

  la   x21, input_ct_v
  li   x20, 128
  li   x22, 0

  ecall


.section .data
.balign 32

/* 隐式拒绝密钥 z（share0 = 真实值，32 B） */
input_z:
  .zero 32

/* z 的第二个份额（全 0，32 B） */
.balign 32
input_z_share1:
  .zero 32

/* 密文 u 段：3 × 320 B = 960 B */
.balign 32
input_ct_u:
  .zero 960

/* 密文 v 段：128 B */
.balign 32
input_ct_v:
  .zero 128
