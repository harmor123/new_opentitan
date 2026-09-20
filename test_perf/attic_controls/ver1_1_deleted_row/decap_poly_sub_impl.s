.section .text

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
