/*
 * ver1_1 对照：decap_unpack_ciphertext（与 profiling 逐条对应，仅少 4 条 jal）
 *
 * Δcycles = decap_unpack_ciphertext_profiling − 本目标。
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

  /* 栈指针 x31 ← stack（app 的 crypto_kem_dec 入口同样写法；内核压栈用 0(x31)） */
  la   x31, stack
  bn.xor w31, w31, w31

  /* MOD CSR ← {q = 3329, mu = -q^-1 mod 2^32}，与 app 一致 */
  la   x2, mlkem768_const_params
  bn.lid x0, 0(x2)
  bn.wsrw MOD, w0

  /* 与 profiling 相同的操作数准备，但不发起调用 */
  la   x2, ct_u
  la   x3, poly_out

  la   x2, ct_u
  addi x2, x2, 320
  la   x3, poly_out

  la   x2, ct_u
  addi x2, x2, 640
  la   x3, poly_out

  la   x2, ct_v
  la   x3, poly_out

  ecall


.section .data
.balign 32

/* 密文 u 段：3 × 320 B = 960 B */
ct_u:
  .zero 960

/* 密文 v 段：128 B */
.balign 32
ct_v:
  .zero 128

/* 输出多项式 = 256 × 32 bit = 1024 B */
.balign 32
poly_out:
  .zero 1024
