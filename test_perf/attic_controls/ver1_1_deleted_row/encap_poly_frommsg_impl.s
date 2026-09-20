.section .text

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

