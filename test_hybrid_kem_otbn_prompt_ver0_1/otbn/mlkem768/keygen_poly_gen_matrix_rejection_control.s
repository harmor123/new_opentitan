.section .text.start

.globl main
main:
  bn.xor w0, w0, w0
  bn.xor w1, w1, w1
  bn.xor w2, w2, w2
  bn.xor w3, w3, w3
  bn.xor w4, w4, w4
  bn.xor w5, w5, w5
  bn.xor w6, w6, w6
  bn.xor w7, w7, w7
  bn.xor w8, w8, w8
  bn.xor w9, w9, w9
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


  la   x3, rejection_stream_ptr
  la   x4, rejection_stream_0000
  sw   x4, 0(x3)
  la   x10, rho
  la   x11, output_poly_0000
  li   x12, 0x0000

  la   x3, rejection_stream_ptr
  la   x4, rejection_stream_0001
  sw   x4, 0(x3)
  la   x10, rho
  la   x11, output_poly_0001
  li   x12, 0x0001

  la   x3, rejection_stream_ptr
  la   x4, rejection_stream_0002
  sw   x4, 0(x3)
  la   x10, rho
  la   x11, output_poly_0002
  li   x12, 0x0002

  la   x3, rejection_stream_ptr
  la   x4, rejection_stream_0100
  sw   x4, 0(x3)
  la   x10, rho
  la   x11, output_poly_0100
  li   x12, 0x0100

  la   x3, rejection_stream_ptr
  la   x4, rejection_stream_0101
  sw   x4, 0(x3)
  la   x10, rho
  la   x11, output_poly_0101
  li   x12, 0x0101

  la   x3, rejection_stream_ptr
  la   x4, rejection_stream_0102
  sw   x4, 0(x3)
  la   x10, rho
  la   x11, output_poly_0102
  li   x12, 0x0102

  la   x3, rejection_stream_ptr
  la   x4, rejection_stream_0200
  sw   x4, 0(x3)
  la   x10, rho
  la   x11, output_poly_0200
  li   x12, 0x0200

  la   x3, rejection_stream_ptr
  la   x4, rejection_stream_0201
  sw   x4, 0(x3)
  la   x10, rho
  la   x11, output_poly_0201
  li   x12, 0x0201

  la   x3, rejection_stream_ptr
  la   x4, rejection_stream_0202
  sw   x4, 0(x3)
  la   x10, rho
  la   x11, output_poly_0202
  li   x12, 0x0202

  ecall

.section .data
.balign 32
stack:
  .zero 4096

.balign 32
rho:
  .zero 32

.balign 32
output_poly_0000:
  .zero 512

.balign 32
output_poly_0001:
  .zero 512

.balign 32
output_poly_0002:
  .zero 512

.balign 32
output_poly_0100:
  .zero 512

.balign 32
output_poly_0101:
  .zero 512

.balign 32
output_poly_0102:
  .zero 512

.balign 32
output_poly_0200:
  .zero 512

.balign 32
output_poly_0201:
  .zero 512

.balign 32
output_poly_0202:
  .zero 512
