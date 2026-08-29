/**
 * @file p256_proj_to_affine_control.s
 * @brief Matching control for P-256 projective-to-affine profiling.
 */

.section .text.start

.globl _start

_start:
  /*
   * Same zero-register initialization.
   */
  bn.xor    w31, w31, w31


  /*
   * Same finite-field setup.
   */
  jal       x1, setup_modp


  /*
   * Same input point initialization:
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
   * No proj_to_affine call.
   *
   * Everything else matches the profiling binary.
   */

  ecall
