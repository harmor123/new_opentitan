/**
 * @file p256_proj_double_control.s
 * @brief Matching control for proj_double profiling.
 *
 * Same setup and loop count as p256_proj_double_profile,
 * but without calling proj_double.
 */

.section .text.start

.globl _start

_start:
  /* Explicit zero WDR. */
  bn.xor    w31, w31, w31

  /* Same P-256 field setup as the real profile. */
  jal       x1, setup_modp

  /* Same Gx load. */
  la        x16, p256_gx
  li        x2, 8
  bn.lid    x2, 0(x16)

  /* Same Gy load. */
  la        x16, p256_gy
  li        x2, 9
  bn.lid    x2, 0(x16)

  /* Same Z = 1 initialization. */
  bn.addi   w10, w31, 1

  /*
   * Matching 256-iteration control loop.
   *
   * The NOP matches the NOP in the real profiling loop.
   */
  loopi     256, 1
    addi      x0, x0, 0

  ecall
