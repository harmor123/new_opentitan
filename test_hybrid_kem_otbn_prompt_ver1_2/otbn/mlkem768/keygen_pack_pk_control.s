/*
 * ver1_1 对照：keygen_pack_pk（与 profiling 逐条对应，仅少 4 条 jal）
 *
 * Δcycles = keygen_pack_pk_profiling − 本目标。
 */
.section .text.start

.globl main
main:
  /* 与 app（mlkem_keypair.s）一致的确定性 WDR 初始化 */
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

  /* 栈指针 x31 ← stack（app 的 crypto_kem_keypair 入口同样写法；内核压栈用 0(x31)） */
  la   x31, stack
  bn.xor w31, w31, w31

  /* MOD CSR ← {q = 3329, mu = -q^-1 mod 2^32}，与 app 一致 */
  la   x2, mlkem768_const_params
  bn.lid x0, 0(x2)
  bn.wsrw MOD, w0

  /* 与 profiling 相同的操作数准备，但不发起调用 */
  la   x2, src_poly
  la   x3, input_pk

  la   x2, src_poly
  la   x3, input_pk
  addi x3, x3, 384

  la   x2, src_poly
  la   x3, input_pk
  addi x3, x3, 768

  la   x10, input_pk
  la   x11, pk_rho
  la   x13, output_pk

  ecall


.section .data
.balign 32

/* 源 t_hat[i]（1024 B） */
src_poly:
  .zero 1024

/* 目标 pk_t：1152 B */
.balign 32
input_pk:
  .zero 1152

/* 源 rho：32 B */
.balign 32
pk_rho:
  .zero 32

/* 目标 ek = pk_t ‖ rho = 1184 B */
.balign 32
output_pk:
  .zero 1184
