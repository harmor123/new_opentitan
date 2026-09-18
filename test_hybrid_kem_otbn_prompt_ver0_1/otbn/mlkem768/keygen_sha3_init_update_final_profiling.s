.section .text.start

.globl main
main:
  /*
   * Match the deterministic WDR initialization used by the
   * full ML-KEM standalone wrapper.
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
   * Prepare a frame so that fp-128 etc. reproduce the addressing
   * used inside indcpa_keypair.
   */
  la   x2, stack_end
  addi fp, sp, 0

  /*
   * indcpa_keypair originally stores the input seed pointer at -16(fp).
   * Put the same pointer there.
   */
  la   x5, seed_d
  sw   x5, -16(fp)

  /*
   * Exact SHA3-512 sequence from indcpa_keypair:
   *
   * SHA3-512(d || 0x03)
   */

  la   x10, context
  li   x11, 64
  jal  x1, sha3_init

  la   x10, context
  lw   x11, -16(fp)
  li   x12, 32
  jal  x1, sha3_update

  /*
   * ML-KEM-768 k = 3.
   */
  addi x11, x0, 3
  sw   x11, -128(fp)

  la   x10, context
  addi x11, fp, -128
  addi x12, x0, 1
  jal  x1, sha3_update

  /*
   * sha3_final writes the 64-byte SHA3-512 output to fp-128.
   */
  la   x10, context
  addi x11, fp, -128
  jal  x1, sha3_final

  ecall


.section .data
.balign 32

/*
 * Stack/work buffer.
 */
stack:
  .zero 4096
stack_end:

/*
 * NIST ACVP FIPS203 ML-KEM-768 KeyGen
 * tgId=2, tcId=26
 *
 * d = first 32 bytes of the 64-byte KeyGen input seed.
 *
 * Stored as little-endian 32-bit words.
 */
.balign 32
seed_d:
  .word 0xd7b782e5
  .word 0xb0806c5e
  .word 0xa192e35a
  .word 0x53719ffc
  .word 0xfd9023b1
  .word 0x68039399
  .word 0x68a767cc
  .word 0xa0c8ebba
