/**
 * @file p256_scalar_mult_profile.s
 * @brief Standalone profiling entry for plain P-256 scalar multiplication.
 *
 * Computes:
 *
 *   Q = d * G
 *
 * using scalar_mult_sw only.
 *
 * Input:
 *   scalar : 256-bit scalar in DMEM
 *
 * The projective result remains in:
 *   w8  = X
 *   w9  = Y
 *   w10 = Z
 */

.section .text.start

.globl _start

_start:
  /*
   * Load 256-bit scalar d into w0.
   */
  la        x16, scalar
  li        x2, 0
  bn.lid    x2, 0(x16)

  /*
   * Explicitly establish the zero WDR used by scalar_mult_sw.
   */
  bn.xor    w31, w31, w31

  /*
   * Use the standard P-256 generator:
   *
   *   P = G
   */
  la        x21, p256_gx
  la        x22, p256_gy

  /*
   * Compute:
   *
   *   Q = d * G
   *
   * Return:
   *   w8  = X
   *   w9  = Y
   *   w10 = Z
   */
  jal       x1, scalar_mult_sw

  ecall


.section .bss

.balign 32
.globl scalar
scalar:
  .zero 32
