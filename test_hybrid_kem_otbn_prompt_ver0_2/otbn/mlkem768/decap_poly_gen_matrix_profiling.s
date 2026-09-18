.section .text.start

.globl main
main:
  /* Same deterministic WDR initialization as full ML-KEM wrapper. */
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
   * Do not use stack_end directly because of the OTBN linker issue
   * encountered in the NTT benchmark.
   */
  la   x2, stack
  li   x3, 4096
  add  x2, x2, x3
  addi fp, x2, 0

  /*
   * Nine real ML-KEM-768 matrix coordinates.
   *
   * x10 = rho
   * x11 = output polynomial
   * x12 = encoded j || i
   */

  /*
   * Exact matrix-generation order used by mlkem_encap.s.
   *
   * x10 = rho
   * x11 = output polynomial
   * x12 = encoded two-byte matrix index
   */

  /* x12 = 0x0000 */
  la   x10, rho
  la   x11, output_poly
  li   x12, 0x0000
  jal  x1, poly_gen_matrix

  /* x12 = 0x0100 */
  la   x10, rho
  la   x11, output_poly
  li   x12, 0x0100
  jal  x1, poly_gen_matrix

  /* x12 = 0x0200 */
  la   x10, rho
  la   x11, output_poly
  li   x12, 0x0200
  jal  x1, poly_gen_matrix

  /* x12 = 0x0001 */
  la   x10, rho
  la   x11, output_poly
  li   x12, 0x0001
  jal  x1, poly_gen_matrix

  /* x12 = 0x0101 */
  la   x10, rho
  la   x11, output_poly
  li   x12, 0x0101
  jal  x1, poly_gen_matrix

  /* x12 = 0x0201 */
  la   x10, rho
  la   x11, output_poly
  li   x12, 0x0201
  jal  x1, poly_gen_matrix

  /* x12 = 0x0002 */
  la   x10, rho
  la   x11, output_poly
  li   x12, 0x0002
  jal  x1, poly_gen_matrix

  /* x12 = 0x0102 */
  la   x10, rho
  la   x11, output_poly
  li   x12, 0x0102
  jal  x1, poly_gen_matrix

  /* x12 = 0x0202 */
  la   x10, rho
  la   x11, output_poly
  li   x12, 0x0202
  jal  x1, poly_gen_matrix

  ecall


.section .data
.balign 32

stack:
  .zero 4096

/*
 * One generated polynomial = 256 coefficients × 16 bits = 512 B.
 * We reuse the same buffer because only timing is measured.
 */
.balign 32
output_poly:
  .zero 512

/*
 * rho = final 32 bytes of the real ACVP ML-KEM-768 Encap
 * encapsulation key (ek).
 *
 * bytes:
 * 49 7e cf f0 9d 0b bc a4
 * f7 e6 f9 db 9e 10 c6 43
 * d2 37 01 bd 63 85 e1 63
 * cf 71 c1 e9 19 a6 e2 0a
 *
 * Stored as little-endian 32-bit words.
 */
.balign 32
rho:
  .word 0xcb9323e0
  .word 0x82a56989
  .word 0xec4555d5
  .word 0x0411a639
  .word 0xf05b2eba
  .word 0x57d9d082
  .word 0x26cc8839
  .word 0x27229b08
