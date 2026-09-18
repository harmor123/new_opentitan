.section .text.start

.globl main
main:
  /* Deterministic WDR initialization */
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

  /* Stack */
  la   x2, stack
  li   x3, 4096
  add  x2, x2, x3
  addi fp, x2, 0

  /*
   * ML-KEM-768 KeyGen:
   *
   * for each of 3 output polynomials:
   *   basemul     once
   *   basemul_acc twice
   *
   * total:
   *   basemul     x3
   *   basemul_acc x6
   */
  .rept 3

    /* First product */
    la   x29, input_sk
    la   x11, input_matrix
    la   x13, output_acc
    la   x28, twiddles_ntt
    jal  x1, basemul

    /* Second product + accumulation */
    la   x29, input_sk
    la   x11, input_matrix
    la   x13, output_acc
    la   x28, twiddles_ntt
    jal  x1, basemul_acc

    /* Third product + accumulation */
    la   x29, input_sk
    la   x11, input_matrix
    la   x13, output_acc
    la   x28, twiddles_ntt
    jal  x1, basemul_acc

  .endr

  ecall


.section .data
.balign 32

stack:
  .zero 4096

/* One NTT-domain polynomial = 256 × 16 bit = 512 B */
.balign 32
input_sk:
  .zero 512

.balign 32
input_matrix:
  .zero 512

.balign 32
output_acc:
  .zero 512
