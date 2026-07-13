/* Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

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
 * @param[in]  x10: dptr_input, dmem pointer to input byte array
 * @param[in]  x11: dptr_modulus_over_2
 * @param[out] x12: dptr_output, dmem pointer to output
 * @param[in]  w31: all-zero
 *
 * clobbered registers: x4-x30, w0-w31
 */

.globl poly_frommsg
poly_frommsg:
  /* Set up wide registers for input and output */
  li x4, 2
  li x5, 3

  /* Load input */
  bn.lid x0, 0(x10)
  bn.lid x5, 0(x11)
  
  LOOPI 16, 8
    LOOPI 16, 5
      bn.rshi w1, w0, w31 >> 1
      bn.rshi w1, w31, w1 >> 255
      bn.sub  w1, w31, w1 
      bn.rshi w2, w1, w2 >> 16
      bn.rshi w0, w31, w0 >> 1
    bn.and w2, w2, w3
    bn.sid x4, 0(x12++)

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
 * clobbered registers: x4-x30, w0-w31
 */

.globl poly_tomsg
poly_tomsg:
  /* Set up registers for input and output */
  li x4, 2

  /* Load const */
  bn.lid x4++, 0(x11)
  bn.lid x4++, 0(x13)
  
  bn.xor  w31, w31, w31
  bn.rshi w3, w31, w3 >> 4 /* 80635 */
  bn.addi w5, w31, 1
  bn.rshi w5, w5, w31 >> 240
  bn.subi w5, w5, 1 /* mask = 0xffff */
  LOOPI 16, 10
    bn.lid  x0, 0(x10++)  /* Load input */
    bn.rshi w0, w0, w31 >> 255 /* <= 1 */
    bn.add  w0, w0, w2
    LOOPI 16, 5
      bn.and          w1, w0, w5          
      bn.mulqacc.wo.z w1, w1.0, w3.0, 0 /* *80635 */
      bn.rshi         w1, w31, w1 >> 28  /* >= 28 */
      bn.rshi         w4, w1, w4 >> 1   /* save one bit */
      bn.rshi         w0, w31, w0 >> 16 /* shift out used coeff */
    NOP
  bn.sid x4, 0(x12)

  ret

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

  /* Initialize SHAKE256 (Mode 3) */
  addi x10, x0, 3       
  jal  x1, kmac_init 

  /* Absorb Seed (32 bytes) */
  add  x10, x0, x3 
  addi x11, x0, 32
  jal  x1, keccak_send_message

  /* Absorb Nonce (1 byte) */
  add  x10, x0, x9 
  addi x11, x0, 1
  jal  x1, keccak_send_message

  /* End Absorb, enter Squeeze */
  /* 1 time direct squeeze + 3 times loop squeeze */
  add  x10, x0, x20
  jal  x1, kmac_squeeze_after_process

  addi x9, x0, 32

  LOOPI 3, 3
    add  x10, x9, x20
    jal  x1, kmac_squeeze_32B
    addi x9, x9, 32

  /* Release KMAC hardware back to IDLE */
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

  /* Initialize SHAKE256 (Mode 3) */
  addi x10, x0, 3       
  jal  x1, kmac_init 

  /* Absorb Seed (32 bytes) */
  add  x10, x0, x3 
  addi x11, x0, 32
  jal  x1, keccak_send_message

  /* Absorb Nonce (1 byte) */
  add  x10, x0, x9 
  addi x11, x0, 1
  jal  x1, keccak_send_message

  /* End Absorb, enter Squeeze */
  /* 1 time direct squeeze + 3 times loop squeeze */
  add  x10, x0, x20
  jal  x1, kmac_squeeze_after_process

  addi x9, x0, 32

  LOOPI 3, 3
    add  x10, x9, x20
    jal  x1, kmac_squeeze_32B
    addi x9, x9, 32

  /* Release KMAC hardware back to IDLE */
  jal  x1, kmac_done
      
  lw     x10, 0(x2)
  lw     x11, 4(x2)
  bn.add w8, w0, w0
  jal    x1, cbd2

  addi x2, x2, 12
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
 * @param[out] x12: dptr_output, dmem pointer to output polynomial
 * @param[in]  w31: all-zero
 *
 * clobbered registers: x4-x30, w0-w31
 */
.globl poly_add
poly_add:
  li x4, 1

  bn.addi w2, w31, 1
  bn.rshi w2, w2, w31 >> 240
  bn.subi w2, w2, 1 /* mask = 0xffff */

  LOOPI 16, 9
    bn.lid x0, 0(x10++)
    bn.lid x4, 0(x11++)
    LOOPI 16, 5
      bn.and  w3, w0, w2 
      bn.and  w4, w1, w2 
      bn.addm w3, w3, w4
      bn.rshi w0, w3, w0 >> 16
      bn.rshi w1, w31, w1 >> 16
    bn.sid x0, 0(x12++)
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
 * @param[in]  w31: all-zero
 *
 * clobbered registers: x4-x30, w0-w31
 */
.globl poly_sub
poly_sub:
  li x4, 1
  li x5, 2

  la     x6, modulus_bn
  bn.lid x5, 0(x6)
  
  LOOPI 16, 5
    bn.lid x0, 0(x10++)
    bn.lid x4, 0(x11++)
    bn.add w0, w0, w2 
    bn.sub w0, w0, w1
    bn.sid x0, 0(x12++)
  ret

/*
 * Name:        poly_reduce
 *
 * Description: Inplace Plantard reduction
 *
 * Arguments:   - 
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in/out]  x10: dptr_input/output, dmem pointer to input/output poly
 * @param[in]  w31: all-zero
 *
 * clobbered registers: x4-x30, w0-w31
 */
.globl poly_reduce
poly_reduce:
  li x4, 5

  bn.lid  x4, 0(x12)
  bn.addi w5, w5, 1
  bn.addi w2, w31, 1
  bn.rshi w2, w2, w31 >> 224
  bn.subi w2, w2, 1 /* mask = 0xffffffff */

  /* Set second WLEN/4 quad word to modulus */
  la     x5, modulus
  li     x6, 20 /* Load q to w6.2*/
  bn.lid x6, 0(x5)
  bn.or  w6, w31, w20 << 128
  /* Load alpha to w6.1 */
  bn.addi w20, w31, 8
  bn.or   w6, w6, w20 << 64
  /* Load mask to w6.3 */
  bn.or w6, w6, w2 << 192

  LOOPI 16, 10
    bn.lid x0, 0(x10)
    LOOPI 16, 7
      bn.and          w1, w0, w2 >> 16
      bn.mulqacc.wo.z w1, w1.0, w5.0, 192 /* a*bq' */
      bn.and          w1, w1, w6
      bn.add          w1, w6, w1 >> 144 /* + 2^alpha = 2^8 */
      bn.mulqacc.wo.z w1, w1.1, w6.2, 0 /* *q */
      bn.rshi         w3, w31, w1 >> 16 /* >> l */
      bn.rshi         w0, w3, w0 >> 16
    bn.sid x0, 0(x10++)
  ret
