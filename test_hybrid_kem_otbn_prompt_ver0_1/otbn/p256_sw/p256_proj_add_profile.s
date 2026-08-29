/**
 * @file p256_proj_add_profile.s
 * @brief Standalone profiling entry for P-256 projective point addition.
 *
 * Profiling structure:
 *
 *   setup_modp
 *      ↓
 *   load b
 *      ↓
 *   P = G
 *   Q = G
 *      ↓
 *   256 × proj_add
 *      ↓
 *   ecall
 *
 * proj_add is a complete constant-time point-addition routine.
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
   * proj_add additionally requires:
   *
   *   w27 = curve parameter b
   */
  li        x2, 27
  la        x3, p256_b
  bn.lid    x2, 0(x3)


  /*
   * Initialize P = G = (Gx, Gy, 1).
   *
   * w8  = Xp
   * w9  = Yp
   * w10 = Zp
   */

  la        x16, p256_gx
  li        x2, 8
  bn.lid    x2, 0(x16)

  la        x16, p256_gy
  li        x2, 9
  bn.lid    x2, 0(x16)

  bn.addi   w10, w31, 1


  /*
   * Initialize Q = G = (Gx, Gy, 1).
   *
   * w11 = Xq
   * w12 = Yq
   * w13 = Zq
   */
  bn.mov    w11, w8
  bn.mov    w12, w9
  bn.addi   w13, w31, 1


  /*
   * Execute 256 point additions.
   *
   * First iteration:
   *   G + G = 2G
   *
   * Next:
   *   G + 2G = 3G
   *
   * Then:
   *   G + 3G = 4G
   *
   * ...
   *
   * P remains in w8/w9/w10.
   * Result Q is updated in-place in w11/w12/w13.
   *
   * NOP is required because JAL must not be the final
   * instruction of an OTBN hardware-loop body.
   */
  loopi     256, 2
    jal       x1, proj_add
    addi      x0, x0, 0


  ecall
