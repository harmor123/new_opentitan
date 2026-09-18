.section .text

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
