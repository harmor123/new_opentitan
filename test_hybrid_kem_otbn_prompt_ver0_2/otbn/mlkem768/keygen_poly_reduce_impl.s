.section .text

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

