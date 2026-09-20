.section .text

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

