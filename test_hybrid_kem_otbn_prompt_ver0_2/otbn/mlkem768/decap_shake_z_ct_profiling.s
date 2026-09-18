.section .text.start

.globl main
main:
  /* Deterministic WDR initialization. */
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

  /* SHAKE256 init. */
  la   x10, context
  li   x11, 32
  jal  x1, sha3_init

  /* Absorb z: 32 B. */
  la   x10, context
  la   x11, z_input
  li   x12, 32
  jal  x1, sha3_update

  /* Absorb ciphertext: 1088 B. */
  la   x10, context
  la   x11, ciphertext
  li   x12, 1088
  jal  x1, sha3_update

  /* Finalize SHAKE. */
  la   x10, context
  jal  x1, shake_xof

  /* Squeeze 32-byte shared-secret candidate. */
  la   x10, context
  la   x11, output
  li   x12, 32
  jal  x1, shake_out

  ecall


.section .data
.balign 32

z_input:
  .zero 32

.balign 32
ciphertext:
  .zero 1088

.balign 32
output:
  .zero 32
