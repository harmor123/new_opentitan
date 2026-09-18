.section .text.start

.globl main
main:
  /*
   * Same deterministic WDR initialization as the full ML-KEM wrapper.
   */
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

  /*
   * Reproduce KeyGen stack layout.
   */
  la   x2, stack
  li   x3, 4096
  add  x2, x2, x3
  addi fp, x2, 0

  /*
   * ------------------------------------------------------------
   * NTT(s): 3 polynomials
   *
   * Same caller structure as mlkem_keypair.s lines 65-73.
   * x10 = input pointer
   * x12 = output pointer
   * ntt advances the polynomial pointers internally.
   * ------------------------------------------------------------
   */
  li   x10, -3712
  add  x10, fp, x10
  add  x12, x0, x10

  .rept 3
    la  x11, twiddles_ntt
    jal x1, ntt
  .endr

  /*
   * ------------------------------------------------------------
   * NTT(e): 3 polynomials
   *
   * KeyGen later resets the polynomial base to fp-3712,
   * exactly as reproduced here.
   * ------------------------------------------------------------
   */
  li   x10, -3712
  add  x10, fp, x10
  add  x12, x0, x10

  .rept 3
    la  x11, twiddles_ntt
    jal x1, ntt
  .endr

  ecall


.section .data
.balign 32

/*
 * Work area.
 *
 * The NTT input region starts at fp-3712.
 * 3 polynomials × 512 B = 1536 B.
 *
 * Data contents do not affect the dynamic NTT control flow;
 * this buffer is initialized to zero for deterministic profiling.
 */
stack:
  .zero 4096
stack_end:
