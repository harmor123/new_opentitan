/**
 * @file p256_mul_modp_profile.s
 * @brief Standalone profiling entry for P-256 modular multiplication.
 *
 * Structure:
 *
 *   setup_modp
 *      ↓
 *   a = Gx
 *   b = Gy
 *      ↓
 *   256 × mul_modp
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
   * Initialize P-256 field context:
   *
   * MOD = p
   * w28 = r256
   * w29 = r448
   */
  jal       x1, setup_modp


  /*
   * Keep two fixed valid field operands in registers
   * that are NOT clobbered by mul_modp.
   *
   * w8 = Gx
   * w9 = Gy
   */
  la        x16, p256_gx
  li        x2, 8
  bn.lid    x2, 0(x16)

  la        x16, p256_gy
  li        x2, 9
  bn.lid    x2, 0(x16)


  /*
   * Execute 256 independent modular multiplications.
   *
   * mul_modp requires:
   *   w24 = a
   *   w25 = b
   *
   * Since mul_modp clobbers w24/w25, restore them
   * from w8/w9 before every call.
   *
   * The final NOP ensures JAL is not the last
   * instruction in the OTBN hardware-loop body.
   */
  loopi     256, 4
    bn.mov    w24, w8
    bn.mov    w25, w9
    jal       x1, mul_modp
    addi      x0, x0, 0


  ecall
