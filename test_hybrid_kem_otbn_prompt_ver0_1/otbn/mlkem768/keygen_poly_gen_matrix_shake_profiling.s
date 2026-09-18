.section .text.start

.globl main
main:
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

  /*
   * Software stack.
   * fp-64 : matrix index buffer
   * fp-32 : SHAKE output buffer
   */
  la   x2, stack
  li   x3, 4096
  add  x2, x2, x3
  addi fp, x2, 0


  /* Matrix index 0x0000: 15 x 32-byte squeezes */
  li   x12, 0x0000
  sw   x12, -64(fp)

  /* SHAKE128 init */
  la   x10, context
  li   x11, 16
  jal  x1, sha3_init

  /* Absorb rho: 32 bytes */
  la   x10, context
  la   x11, rho
  li   x12, 32
  jal  x1, sha3_update

  /* Absorb j || i: 2 bytes */
  la   x10, context
  addi x11, fp, -64
  li   x12, 2
  jal  x1, sha3_update

  /* Finalize SHAKE absorb phase */
  la   x10, context
  jal  x1, shake_xof

  /* squeeze 1/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 2/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 3/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 4/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 5/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 6/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 7/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 8/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 9/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 10/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 11/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 12/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 13/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 14/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 15/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out

  /* Matrix index 0x0001: 16 x 32-byte squeezes */
  li   x12, 0x0001
  sw   x12, -64(fp)

  /* SHAKE128 init */
  la   x10, context
  li   x11, 16
  jal  x1, sha3_init

  /* Absorb rho: 32 bytes */
  la   x10, context
  la   x11, rho
  li   x12, 32
  jal  x1, sha3_update

  /* Absorb j || i: 2 bytes */
  la   x10, context
  addi x11, fp, -64
  li   x12, 2
  jal  x1, sha3_update

  /* Finalize SHAKE absorb phase */
  la   x10, context
  jal  x1, shake_xof

  /* squeeze 1/16 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 2/16 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 3/16 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 4/16 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 5/16 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 6/16 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 7/16 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 8/16 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 9/16 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 10/16 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 11/16 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 12/16 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 13/16 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 14/16 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 15/16 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 16/16 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out

  /* Matrix index 0x0002: 15 x 32-byte squeezes */
  li   x12, 0x0002
  sw   x12, -64(fp)

  /* SHAKE128 init */
  la   x10, context
  li   x11, 16
  jal  x1, sha3_init

  /* Absorb rho: 32 bytes */
  la   x10, context
  la   x11, rho
  li   x12, 32
  jal  x1, sha3_update

  /* Absorb j || i: 2 bytes */
  la   x10, context
  addi x11, fp, -64
  li   x12, 2
  jal  x1, sha3_update

  /* Finalize SHAKE absorb phase */
  la   x10, context
  jal  x1, shake_xof

  /* squeeze 1/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 2/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 3/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 4/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 5/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 6/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 7/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 8/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 9/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 10/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 11/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 12/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 13/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 14/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 15/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out

  /* Matrix index 0x0100: 15 x 32-byte squeezes */
  li   x12, 0x0100
  sw   x12, -64(fp)

  /* SHAKE128 init */
  la   x10, context
  li   x11, 16
  jal  x1, sha3_init

  /* Absorb rho: 32 bytes */
  la   x10, context
  la   x11, rho
  li   x12, 32
  jal  x1, sha3_update

  /* Absorb j || i: 2 bytes */
  la   x10, context
  addi x11, fp, -64
  li   x12, 2
  jal  x1, sha3_update

  /* Finalize SHAKE absorb phase */
  la   x10, context
  jal  x1, shake_xof

  /* squeeze 1/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 2/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 3/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 4/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 5/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 6/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 7/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 8/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 9/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 10/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 11/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 12/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 13/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 14/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 15/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out

  /* Matrix index 0x0101: 16 x 32-byte squeezes */
  li   x12, 0x0101
  sw   x12, -64(fp)

  /* SHAKE128 init */
  la   x10, context
  li   x11, 16
  jal  x1, sha3_init

  /* Absorb rho: 32 bytes */
  la   x10, context
  la   x11, rho
  li   x12, 32
  jal  x1, sha3_update

  /* Absorb j || i: 2 bytes */
  la   x10, context
  addi x11, fp, -64
  li   x12, 2
  jal  x1, sha3_update

  /* Finalize SHAKE absorb phase */
  la   x10, context
  jal  x1, shake_xof

  /* squeeze 1/16 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 2/16 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 3/16 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 4/16 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 5/16 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 6/16 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 7/16 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 8/16 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 9/16 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 10/16 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 11/16 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 12/16 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 13/16 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 14/16 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 15/16 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 16/16 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out

  /* Matrix index 0x0102: 15 x 32-byte squeezes */
  li   x12, 0x0102
  sw   x12, -64(fp)

  /* SHAKE128 init */
  la   x10, context
  li   x11, 16
  jal  x1, sha3_init

  /* Absorb rho: 32 bytes */
  la   x10, context
  la   x11, rho
  li   x12, 32
  jal  x1, sha3_update

  /* Absorb j || i: 2 bytes */
  la   x10, context
  addi x11, fp, -64
  li   x12, 2
  jal  x1, sha3_update

  /* Finalize SHAKE absorb phase */
  la   x10, context
  jal  x1, shake_xof

  /* squeeze 1/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 2/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 3/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 4/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 5/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 6/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 7/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 8/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 9/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 10/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 11/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 12/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 13/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 14/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 15/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out

  /* Matrix index 0x0200: 15 x 32-byte squeezes */
  li   x12, 0x0200
  sw   x12, -64(fp)

  /* SHAKE128 init */
  la   x10, context
  li   x11, 16
  jal  x1, sha3_init

  /* Absorb rho: 32 bytes */
  la   x10, context
  la   x11, rho
  li   x12, 32
  jal  x1, sha3_update

  /* Absorb j || i: 2 bytes */
  la   x10, context
  addi x11, fp, -64
  li   x12, 2
  jal  x1, sha3_update

  /* Finalize SHAKE absorb phase */
  la   x10, context
  jal  x1, shake_xof

  /* squeeze 1/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 2/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 3/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 4/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 5/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 6/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 7/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 8/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 9/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 10/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 11/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 12/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 13/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 14/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 15/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out

  /* Matrix index 0x0201: 15 x 32-byte squeezes */
  li   x12, 0x0201
  sw   x12, -64(fp)

  /* SHAKE128 init */
  la   x10, context
  li   x11, 16
  jal  x1, sha3_init

  /* Absorb rho: 32 bytes */
  la   x10, context
  la   x11, rho
  li   x12, 32
  jal  x1, sha3_update

  /* Absorb j || i: 2 bytes */
  la   x10, context
  addi x11, fp, -64
  li   x12, 2
  jal  x1, sha3_update

  /* Finalize SHAKE absorb phase */
  la   x10, context
  jal  x1, shake_xof

  /* squeeze 1/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 2/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 3/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 4/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 5/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 6/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 7/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 8/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 9/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 10/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 11/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 12/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 13/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 14/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 15/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out

  /* Matrix index 0x0202: 15 x 32-byte squeezes */
  li   x12, 0x0202
  sw   x12, -64(fp)

  /* SHAKE128 init */
  la   x10, context
  li   x11, 16
  jal  x1, sha3_init

  /* Absorb rho: 32 bytes */
  la   x10, context
  la   x11, rho
  li   x12, 32
  jal  x1, sha3_update

  /* Absorb j || i: 2 bytes */
  la   x10, context
  addi x11, fp, -64
  li   x12, 2
  jal  x1, sha3_update

  /* Finalize SHAKE absorb phase */
  la   x10, context
  jal  x1, shake_xof

  /* squeeze 1/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 2/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 3/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 4/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 5/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 6/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 7/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 8/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 9/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 10/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 11/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 12/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 13/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 14/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out
  /* squeeze 15/15 */
  la   x10, context
  addi x11, fp, -32
  li   x12, 32
  jal  x1, shake_out

  ecall


.section .data
.balign 32

stack:
  .zero 4096

/*
 * rho = SHA3-512(d || 0x03)[0:32]
 */
.balign 32
rho:
  .word 0x98c02e16
  .word 0x2db100a9
  .word 0xfbbbfad8
  .word 0x1dcbe83f
  .word 0x5f31e8c4
  .word 0x2fd3f02a
  .word 0x13ae1700
  .word 0x28f0196e
