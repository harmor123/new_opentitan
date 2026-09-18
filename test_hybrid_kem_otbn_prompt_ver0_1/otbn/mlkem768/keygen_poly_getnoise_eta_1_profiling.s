.section .text.start

.globl main
main:
  /*
   * Same deterministic WDR initialization as full ML-KEM wrapper.
   */
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
   * fp is the top of a 4096-byte work area.
   * This lets us reuse the exact negative offsets from mlkem_keypair.s.
   */
  la   x2, stack_end
  addi fp, x2, 0

  /*
   * Copy sigma into fp-96.
   *
   * sigma is the second 32 bytes of:
   * SHA3-512(d || 0x03)
   */
  la      x5, sigma
  li      x4, 0
  bn.lid  x4, 0(x5)
  addi    x6, fp, -96
  bn.sid  x4, 0(x6)

  /*
   * ------------------------------------------------------------
   * Generate s[0], s[1], s[2]
   * nonce = 0,1,2
   *
   * Reproduces mlkem_keypair.s lines 52-63.
   * ------------------------------------------------------------
   */
  li   x15, -2176
  li   x11, -3712
  add  x11, fp, x11
  li   x13, -64
  li   x12, 0

  LOOPI 3, 5
    add  x6, fp, x15
    addi x10, fp, -96
    sw   x12, -64(fp)
    jal  x1, poly_getnoise_eta_1
    addi x12, x12, 1

  /*
   * ------------------------------------------------------------
   * Generate e[0], e[1], e[2]
   * nonce = 3,4,5
   *
   * Reproduces mlkem_keypair.s lines 129-140.
   * ------------------------------------------------------------
   */
  li   x15, -640
  li   x11, -3712
  add  x11, fp, x11
  li   x13, -64
  li   x12, 3

  LOOPI 3, 5
    add  x6, fp, x15
    addi x10, fp, -96
    sw   x12, -64(fp)
    jal  x1, poly_getnoise_eta_1
    addi x12, x12, 1

  ecall


.section .data
.balign 32

/*
 * Large enough for the same negative fp offsets used by KeyGen:
 *   fp-3712 : polynomial output
 *   fp-2176 : SHAKE buffer for s
 *   fp-640  : SHAKE buffer for e
 *   fp-96   : sigma
 *   fp-64   : nonce
 */
stack:
  .zero 4096
stack_end:

/*
 * sigma = second half of SHA3-512(d || 0x03)
 *
 * dac0dd57 b5311d1f 31e4f8d1 1245afe4
 * 7e00c7d1 4106b6d4 c1efd9c3 7531c9a6
 *
 * Stored as little-endian 32-bit words.
 */
.balign 32
sigma:
  .word 0x57ddc0da
  .word 0x1f1d31b5
  .word 0xd1f8e431
  .word 0xe4af4512
  .word 0xd1c7007e
  .word 0xd4b60641
  .word 0xc3d9efc1
  .word 0xa6c93175
