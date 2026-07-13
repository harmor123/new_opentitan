/*
 * Name:        poly_getnoise_eta1
 *
 * Description: Sample a polynomial deterministically from a seed and a nonce,
 *              with output polynomial close to centered binomial distribution
 *              with parameter KYBER_ETA1
 *
 * Arguments:   - poly *r: pointer to output polynomial
 *              - const uint8_t *seed: pointer to input seed (of length KYBER_SYMBYTES bytes)
 *              - uint8_t nonce: one-byte input nonce
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10: dptr_input, dmem pointer to input seed
 * @param[in]  x13: STACK_NONCE
 * @param[in]  x6: dmem_ptr to SHAKE256 results
 * @param[in]  w31: all-x0
 * @param[out] x11: dptr_output, dmem pointer to output polynomial
 *
 * clobbered registers: x4-x30, w0-w31
 */

.globl poly_getnoise_eta_1
poly_getnoise_eta_1:
  addi x2, x2, -12
  sw   x11, 4(x2)
  sw   x6, 0(x2)

  /* Initialize a SHAKE256 operation. */
  add x3, x0, x10
  add x9, fp, x13
  add x20, x0, x6

  /*  初始化 SHAKE256 (Mode 3) */
  addi x10, x0, 3       
  jal  x1, kmac_init 

  /*  吸收 Seed (32 字节) */
  add  x10, x0, x3 
  addi x11, x0, 32
  jal  x1, keccak_send_message

  /*  吸收 Nonce (1 字节) */
  add  x10, x0, x9 
  addi x11, x0, 1
  jal  x1, keccak_send_message

  /*  结束 Absorb，进入 Squeeze */
  /*  1次直接挤出 + 3次循环挤出 */
  add  x10, x0, x20
  jal  x1, kmac_squeeze_after_process

  addi x9, x0, 32

  LOOPI 3, 3
    add  x10, x9, x20
    jal  x1, kmac_squeeze_32B
    addi x9, x9, 32

  /*  释放 KMAC 硬件回到 IDLE */
  jal  x1, kmac_done
      
  lw     x10, 0(x2)
  lw     x11, 4(x2)
  bn.add w8, w0, w0

  jal x1, cbd2


  addi x2, x2, 12
  ret

/*
 * Name:        poly_getnoise_eta2
 *
 * Description: Sample a polynomial deterministically from a seed and a nonce,
 *              with output polynomial close to centered binomial distribution
 *              with parameter KYBER_ETA2
 *
 * Arguments:   - poly *r: pointer to output polynomial
 *              - const uint8_t *seed: pointer to input seed (of length KYBER_SYMBYTES bytes)
 *              - uint8_t nonce: one-byte input nonce
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10: dptr_input, dmem pointer to input seed
 * @param[in]  x13: STACK_NONCE
 * @param[in]  x6: dmem_ptr to SHAKE256 results
 * @param[in]  w31: all-x0
 * @param[out] x11: dptr_output, dmem pointer to output polynomial
 *
 * clobbered registers: x4-x30, w0-w31
 */

.globl poly_getnoise_eta_2
poly_getnoise_eta_2:
  addi x2, x2, -12
  sw   x11, 4(x2)
  sw   x6, 0(x2)

  /* Initialize a SHAKE256 operation. */
  add x3, x0, x10
  add x9, fp, x13
  add x20, x0, x6

  /*  初始化 SHAKE256 (Mode 3) */
  addi x10, x0, 3       
  jal  x1, kmac_init 

  /*  吸收 Seed (32 字节) */
  add  x10, x0, x3 
  addi x11, x0, 32
  jal  x1, keccak_send_message

  /*  吸收 Nonce (1 字节) */
  add  x10, x0, x9 
  addi x11, x0, 1
  jal  x1, keccak_send_message

  /*  结束 Absorb，进入 Squeeze */
  /*  1次直接挤出 + 3次循环挤出 */
  add  x10, x0, x20
  jal  x1, kmac_squeeze_after_process

  addi x9, x0, 32

  LOOPI 3, 3
    add  x10, x9, x20
    jal  x1, kmac_squeeze_32B
    addi x9, x9, 32

  /*  释放 KMAC 硬件回到 IDLE */
  jal  x1, kmac_done
      
  lw     x10, 0(x2)
  lw     x11, 4(x2)
  bn.add w8, w0, w0
  jal    x1, cbd2

  addi x2, x2, 12
  ret



/*
 * Name:        poly_frommsg
 *
 * Description: Convert 32-byte message to polynomial
 *
 * Arguments:   - uint8_t r: input byte array (KYBER_SYMBYTES=32 bytes)
 *              - poly a: output polynomial, n=256, q=3329
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  w31: all-zero
 * @param[in]  x10: dptr_input, dmem pointer to input byte array
 * @param[in]  x11: dptr_modulus_over_2
 * @param[out] x12: dptr_output, dmem pointer to output
 *
 * clobbered registers: x4-x6, w0-w3
 * clobbered flag groups: None
 */

.globl poly_frommsg
poly_frommsg:
  /* Set up wide registers for input and output */
  li x4, 0
  li x5, 1
  li x6, 3

  /* Load input */
  bn.lid x4, 0(x10)
  bn.lid x6, 0(x11)
  
  LOOPI 16, 7
    LOOPI 16, 3
      bn.rshi w1, w0, w1 >> 1
      bn.rshi w1, w31, w1 >> 15
      bn.rshi w0, w31, w0 >> 1
    bn.subv.16H w1, w31, w1 
    bn.and      w1, w1, w3
    bn.sid      x5, 0(x12++)

  ret

/*
 * Name:        poly_tomsg
 *
 * Description: Convert polynomial to 32-byte message
 *
 * Arguments:   - uint8_t r: output byte array (KYBER_SYMBYTES=32 bytes)
 *              - poly a: input polynomial, n=256, q=3329
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  w31: all-zero
 * @param[in]  x10: dptr_input, dmem pointer to input polynomial
 * @param[in]  x11: modulus_over_2
 * @param[in]  x13: const_1290167
 * @param[out] x12: dptr_output, dmem pointer to output byte array
 *
 * clobbered registers: x4-x8, w0-w4
 * clobbered flag groups: None
 */

.globl poly_tomsg
poly_tomsg:
  /* Set up registers for input and output */
  li x4, 0
  li x5, 2
  li x7, 16

  /* Load const */
  bn.lid x5++, 0(x11) /* w2 = (0x681)^16 */
  bn.lid x7, 0(x13) /* w16 = 1290167 */
  
  /* Multiply the constant 80635 with 2**4 so that later we shift to the right
   * 32 bits instead of 28 bits. This means we can return the high parts of
   * the 64-bit products within the multiplication instruction. */
  bn.subi w16, w16, 7 /* w16 = 1290160 = 80635 << 4 */
  /* Zeroize w31 */
  bn.xor  w31, w31, w31
  LOOPI 16, 14
    bn.lid               x4, 0(x10++)  /* Load input */
    bn.shv.16H           w0, w0 << 1   /* <= 1 */ 
    bn.addv.16H          w0, w0, w2    /* += 1665 */
    bn.trn1.16H          w1, w0, w31 /* Put even coeffs in 32-bit slots */
    bn.mulv.l.8S.even.hi w1, w1, sw0.0 /* >> 32 is taking the high parts of 64-bit products */
    bn.mulv.l.8S.odd.hi  w1, w1, sw0.0 /* >> 32 is taking the high parts of 64-bit products */
    bn.trn2.16H          w0, w0, w31 /* Put odd coeffs to 32-bit slots */
    bn.mulv.l.8S.even.hi w0, w0, sw0.0 /* >> 32 is taking the high parts of 64-bit products */
    bn.mulv.l.8S.odd.hi  w0, w0, sw0.0 /* >> 32 is taking the high parts of 64-bit products */
    bn.trn1.16H          w0, w1, w0 /* Interleaving the results to original order */
    LOOPI 16, 2
      bn.rshi w3, w0, w3 >> 1
      bn.rshi w0, w31, w0 >> 16
    NOP
  bn.sid x5, 0(x12)

  ret

/*
 * Name:        poly_add
 *
 * Description: Add 2 vectors
 *
 * Arguments:   - 
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10: dptr_input, dmem pointer to first poly
 * @param[in]  x11: dptr_input, dmem pointer to second poly
 * @param[in]  x12: dptr_output, dmem pointer to output polynomial
 *
 * clobbered registers: x4-x30, w0-w31
 * clobbered flag groups: None
 */
.globl poly_add
poly_add:
  li x4, 1

  LOOPI 16, 4
    bn.lid       x0, 0(x10++)
    bn.lid       x4, 0(x11++)
    bn.addvm.16H w0, w0, w1
    bn.sid       x0, 0(x12++)
  ret

/*
 * Name:        poly_sub
 *
 * Description: Sub 2 vectors
 *
 * Arguments:   - 
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10: dptr_input, dmem pointer to first poly
 * @param[in]  x11: dptr_input, dmem pointer to second poly
 * @param[out] x12: dptr_output, dmem pointer to output polynomial
 *
 * clobbered registers: x4-x30, w0-w31
 * clobbered flag groups: None
 */
.globl poly_sub
poly_sub:
  li x4, 1

  LOOPI 16, 4
    bn.lid       x0, 0(x10++)
    bn.lid       x4, 0(x11++)
    bn.subvm.16H w0, w0, w1
    bn.sid       x0, 0(x12++)
  ret

/*
 * Name:        poly_tomont
 *
 * Description: Put the input polynomial out of Montgomery domain
 *
 * Arguments:   - 
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in/out]  x10: dptr_input, dmem pointer to first poly
 * @param[in]      x11: ptr to const_tomont = 2^32 % Q
 * @param[in]      w16: sw0, where sw0.2 = Q^-1 mod 2^32, sw0.0 = Q
 * @param[in]      w31: all-zero
 *
 * clobbered registers: x4-x30, w0-w31
 * clobbered flag groups: None
 */
.globl poly_tomont
poly_tomont:
  /* Load const_tomont */
  li     x4, 0
  bn.lid x4++, 0(x11)

  LOOPI 16, 6
    bn.lid               x4, 0(x10)
    bn.mulv.16H.acc.z.lo w1, w0, w1
    bn.mulv.l.16H.lo     w1, w1, sw0.2
    bn.mulv.l.16H.acc.hi w1, w1, sw0.0
    bn.addvm.16H         w1, w1, w31
    bn.sid               x4, 0(x10++)
  ret
