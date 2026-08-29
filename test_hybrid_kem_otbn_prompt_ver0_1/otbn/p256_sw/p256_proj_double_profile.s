/**
 * @file p256_proj_double_profile.s
 * @brief Standalone profiling entry for P-256 projective point doubling.
 *
 * Profiling structure:
 *
 *   setup_modp
 *      ↓
 *   P = G = (Gx, Gy, 1)
 *      ↓
 *   256 × proj_double
 *      ↓
 *   ecall
 *
 * This profile measures the dynamic cost of 256 consecutive
 * projective point doublings.
 */

.section .text.start

.globl _start

_start:
  /*
   * Establish the zero WDR explicitly.
   *
   * proj_double expects:
   *   w31 = 0
   */
  bn.xor    w31, w31, w31


  /*
   * Initialize the P-256 finite-field arithmetic context.
   *
   * setup_modp prepares:
   *   MOD = p
   *   w28 = r256
   *   w29 = r448
   */
  jal       x1, setup_modp


  /*
   * Initialize the projective input point:
   *
   *   P = G = (Gx, Gy, 1)
   *
   * proj_double expects:
   *   w8  = X
   *   w9  = Y
   *   w10 = Z
   */

  /* w8 = Gx */
  la        x16, p256_gx
  li        x2, 8
  bn.lid    x2, 0(x16)

  /* w9 = Gy */
  la        x16, p256_gy
  li        x2, 9
  bn.lid    x2, 0(x16)

  /* w10 = 1 */
  bn.addi   w10, w31, 1


  /*
   * Perform exactly 256 projective point doublings.
   *
   * Iteration 1:
   *   G -> 2G
   *
   * Iteration 2:
   *   2G -> 4G
   *
   * ...
   *
   * proj_double updates w8/w9/w10 in place.
   */
  loopi     256, 2
    jal       x1, proj_double
    addi      x0, x0, 0

  ecall
