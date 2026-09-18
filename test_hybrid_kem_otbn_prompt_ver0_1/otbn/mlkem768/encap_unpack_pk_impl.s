.section .text

poly_frombytes:
  LOOPI 4, 35
    /* Load inputs */
    bn.lid x4, 0(x10++)
    bn.lid x5, 0(x10++)
    bn.lid x6, 0(x10++) 

    /* First 16 coeffs = 24 bytes */
    LOOPI 16, 2
      bn.rshi w4, w0, w4 >> 16
      bn.rshi w0, w31, w0 >> 12 
    bn.and w4, w4, w3
    bn.sid x8, 0(x12++)

    /* Second 16 coeffs = 24 bytes (8 bytes w0 + 16 bytes w1)*/
    LOOPI 5, 2
      bn.rshi w4, w0, w4 >> 16
      bn.rshi w0, w31, w0 >> 12 
    bn.rshi w4, w0, w4 >> 4
    bn.rshi w4, w1, w4 >> 12
    bn.rshi w1, w31, w1 >> 8
    LOOPI 10, 2
      bn.rshi w4, w1, w4 >> 16
      bn.rshi w1, w31, w1 >> 12 
    bn.and w4, w4, w3
    bn.sid x8, 0(x12++)

    /* Third 16 coeffs = 24 bytes (16 bytes w1 + 8 bytes w2) */
    LOOPI 10, 2
      bn.rshi w4, w1, w4 >> 16
      bn.rshi w1, w31, w1 >> 12
    bn.rshi w4, w1, w4 >> 8
    bn.rshi w4, w2, w4 >> 8
    bn.rshi w2, w31, w2 >> 4
    LOOPI 5, 2
      bn.rshi w4, w2, w4 >> 16
      bn.rshi w2, w31, w2 >> 12
    bn.and w4, w4, w3
    bn.sid x8, 0(x12++)

    /* Fourth 16 coeffs = 24 bytes (24 bytes w2) */
    LOOPI 16, 2
      bn.rshi w4, w2, w4 >> 16
      bn.rshi w2, w31, w2 >> 12
    bn.and w4, w4, w3
    bn.sid x8, 0(x12++)
  ret

/*
 * Name:        unpack_pk
 *
 * Description: De-serialize public key from a byte array;
 *              approximate inverse of pack_pk 
 *
 * Arguments:   - polyvec *pk: pointer to output public-key polynomial vector
 *              - uint8_t *seed: pointer to output seed to generate matrix A
 *              - const uint8_t *packedpk: pointer to input serialized public key
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10: dptr_input, dmem pointer to input serialized pk
 * @param[out] x12: dptr_output, dmem pointer to output polyvec pk 
 * @param[in]  x13: dptr_const_0x0fff
 * @param[in]  w31: all-zero
 *
 * clobbered registers: x4-x8, w0-w5, w31
 */

.globl unpack_pk
unpack_pk:
  /* Save callee registers */
  addi sp, sp, -8
  sw   x8, 0(sp)

  /* Set up wide registers for input and output */
  li x4, 0
  li x5, 1
  li x6, 2
  li x7, 3
  li x8, 4

  /* Load constant */
  bn.lid x7, 0(x13)

  /* Unpack pk */
  .rept 3
    jal x1, poly_frombytes
  .endr 

  /* Unpack seed */
  /* There's no need to unpack seed. Once pk is sent, client 
     only needs to unpack pk to polynomials and use the attached
     seed directly for matrix generation. */
  /* Restore registers and return */
  lw   x8, 0(sp)
  addi sp, sp, 8
  ret
