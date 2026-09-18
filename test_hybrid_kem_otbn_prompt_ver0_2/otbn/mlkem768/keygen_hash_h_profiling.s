.section .text.start

.globl main
main:
  /* Deterministic WDR initialization */
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
  bn.xor w31, w31, w31

  /*
   * Software stack.
   * Use stack + 4096 instead of stack_end to avoid
   * the OTBN end-of-section symbol issue seen earlier.
   */
  la   x2, stack
  li   x3, 4096
  add  x2, x2, x3
  addi fp, x2, 0

  /*
   * H(pk) = SHA3-256(pk)
   *
   * sha3_init:
   *   x10 = context
   *   x11 = output length = 32
   */
  la   x10, context
  li   x11, 32
  jal  x1, sha3_init

  /*
   * sha3_update:
   *   x10 = context
   *   x11 = pk
   *   x12 = 1184 bytes
   */
  la   x10, context
  la   x11, input_pk
  li   x12, 1184
  jal  x1, sha3_update

  /*
   * sha3_final:
   *   x10 = context
   *   x11 = 32-byte output
   */
  la   x10, context
  la   x11, output_hash
  jal  x1, sha3_final

  ecall


.section .data
.balign 32

stack:
  .zero 4096

/* ML-KEM-768 encoded public key */
.balign 32
input_pk:
  .zero 1184

/* SHA3-256 output */
.balign 32
output_hash:
  .zero 32
