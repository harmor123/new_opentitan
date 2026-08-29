/**
 * @file p256_mul_modp_control.s
 * @brief Matching control for P-256 modular multiplication profiling.
 */

.section .text.start

.globl _start

_start:
  /*
   * Same zero initialization.
   */
  bn.xor    w31, w31, w31


  /*
   * Same field setup.
   */
  jal       x1, setup_modp


  /*
   * Same fixed operands.
   */
  la        x16, p256_gx
  li        x2, 8
  bn.lid    x2, 0(x16)

  la        x16, p256_gy
  li        x2, 9
  bn.lid    x2, 0(x16)


  /*
   * Matching loop.
   *
   * Keep exactly the same operand-copy instructions
   * and NOP, but remove the mul_modp call.
   */
  loopi     256, 3
    bn.mov    w24, w8
    bn.mov    w25, w9
    addi      x0, x0, 0


  ecall
