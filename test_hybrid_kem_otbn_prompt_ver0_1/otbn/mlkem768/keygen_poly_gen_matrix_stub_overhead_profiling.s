.section .text.start

.globl main
main:
  /*
   * Keep the same deterministic WDR initialization used
   * by the other standalone microbenchmarks.
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
   * Initialize the precomputed stream pointer.
   *
   * 137 * 32 B = 4384 B.
   * The existing rejection_streams file contains 9 * 640 B
   * = 5760 B of contiguous aligned stream storage, which is
   * sufficient for this calibration.
   */
  la   x3, rejection_stream_ptr
  la   x4, rejection_stream_0000
  sw   x4, 0(x3)

  /*
   * shake_out stub writes 32 bytes to x11.
   * Reusing the same destination buffer is sufficient here,
   * because we only measure stub overhead.
   */
  la   x11, calibration_output

  /*
   * Exact dynamic call counts observed in the real
   * poly_gen_matrix ×9 execution.
   */

  /* sha3_init ×9 */
  .rept 9
    jal x1, sha3_init
  .endr

  /* sha3_update ×18 */
  .rept 18
    jal x1, sha3_update
  .endr

  /* shake_xof ×9 */
  .rept 9
    jal x1, shake_xof
  .endr

  /* shake_out ×137 */
  .rept 137
    jal x1, shake_out
  .endr

  ecall


.section .data
.balign 32

calibration_output:
  .zero 32
