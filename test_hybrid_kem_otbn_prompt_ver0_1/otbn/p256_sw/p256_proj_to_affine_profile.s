/**
 * @file p256_proj_to_affine_profile.s
 * @brief Standalone profiling entry for P-256 projective-to-affine conversion.
 *
 * Profiling structure:
 *
 *   setup_modp
 *      ↓
 *   P = G = (Gx, Gy, 1)
 *      ↓
 *   proj_to_affine
 *      ↓
 *   ecall
 */

.section .text.start

.globl _start

_start:
  /*
   * Explicit zero WDR.
   */
  bn.xor    w31, w31, w31


  /*
   * Initialize P-256 finite-field context:
   *
   *   MOD = p
   *   w28 = r256
   *   w29 = r448
   */
  jal       x1, setup_modp


  /*
   * Initialize projective input point:
   *
   *   w8  = X
   *   w9  = Y
   *   w10 = Z
   *
   * Use the generator:
   *
   *   P = (Gx, Gy, 1)
   */

  la        x16, p256_gx
  li        x2, 8
  bn.lid    x2, 0(x16)

  la        x16, p256_gy
  li        x2, 9
  bn.lid    x2, 0(x16)

  bn.addi   w10, w31, 1


  /*
   * Convert:
   *
   *   (X, Y, Z)
   *
   * to:
   *
   *   x_a = X * Z^(-1)
   *   y_a = Y * Z^(-1)
   *
   * Outputs:
   *   w11 = x_a
   *   w12 = y_a
   *   w14 = Z^(-1)
   */
  jal       x1, proj_to_affine


  ecall
