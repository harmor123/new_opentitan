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

  la   x2, stack
  li   x3, 4096
  add  x2, x2, x3
  addi fp, x2, 0

  la x10, rho
  la x11, output_poly
  li x12, 0x0000

  la x10, rho
  la x11, output_poly
  li x12, 0x0001

  la x10, rho
  la x11, output_poly
  li x12, 0x0002

  la x10, rho
  la x11, output_poly
  li x12, 0x0100

  la x10, rho
  la x11, output_poly
  li x12, 0x0101

  la x10, rho
  la x11, output_poly
  li x12, 0x0102

  la x10, rho
  la x11, output_poly
  li x12, 0x0200

  la x10, rho
  la x11, output_poly
  li x12, 0x0201

  la x10, rho
  la x11, output_poly
  li x12, 0x0202

  ecall


.section .data
.balign 32

stack:
  .zero 4096

.balign 32
output_poly:
  .zero 512

.balign 32
rho:
  .word 0xc1d37364
  .word 0xb4afd359
  .word 0x0db487b6
  .word 0xa971f3fb
  .word 0x604b64c2
  .word 0x1ab78751
  .word 0x864cbc14
  .word 0x4782fe78
