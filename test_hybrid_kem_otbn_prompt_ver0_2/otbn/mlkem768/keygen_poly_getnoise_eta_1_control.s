.section .text.start

.globl main
main:
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

  la   x2, stack_end
  addi fp, x2, 0

  /* Same sigma preload as profiling harness. */
  la      x5, sigma
  li      x4, 0
  bn.lid  x4, 0(x5)
  addi    x6, fp, -96
  bn.sid  x4, 0(x6)

  ecall


.section .data
.balign 32

stack:
  .zero 4096
stack_end:

.balign 32
sigma:
  .word 0x57ddc0da
  .word 0x1f1d31b5
  .word 0xd1f8e431
  .word 0xe4af4512
  .word 0xd1c7007e
  .word 0xd4b60641
  .word 0xc3d9efc1
  .word 0xa6c93175
