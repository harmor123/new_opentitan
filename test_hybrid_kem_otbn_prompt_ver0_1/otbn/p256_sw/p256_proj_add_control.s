/**
 * @file p256_proj_add_control.s
 * @brief Matching control for P-256 proj_add profiling.
 */

.section .text.start

.globl _start

_start:
  /*
   * Same zero-register setup.
   */
  bn.xor    w31, w31, w31


  /*
   * Same field setup.
   */
  jal       x1, setup_modp


  /*
   * Same curve parameter b setup.
   */
  li        x2, 27
  la        x3, p256_b
  bn.lid    x2, 0(x3)


  /*
   * Same P = G initialization.
   */
  la        x16, p256_gx
  li        x2, 8
  bn.lid    x2, 0(x16)

  la        x16, p256_gy
  li        x2, 9
  bn.lid    x2, 0(x16)

  bn.addi   w10, w31, 1


  /*
   * Same Q = G initialization.
   */
  bn.mov    w11, w8
  bn.mov    w12, w9
  bn.addi   w13, w31, 1


  /*
   * Matching 256-iteration loop.
   *
   * No ECC operation.
   */
  loopi     256, 1
    addi      x0, x0, 0


  ecall
