/* Copyright lowRISC contributors (OpenTitan project). */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/**
 * P-256 fused multiply test (P3 of the fold-unit work).
 *
 * Exercises the new instruction BN.P256MUL on **large** operands taken from the
 * official P-256 test vectors (sw/otbn/crypto/tests/p256_ecdh_shared_key_test.s):
 * the example ECDH scalar d0 and the example curve point coordinates x and y.
 * A (p-1) case is added so the conditional correction is exercised with an
 * all-ones input as well.
 *
 * Expected results (verified three ways off-line: the bit-exact hardware model
 * p256_fold_model.py, the Python ISS, and a big-integer reference):
 *   w19 = d0 * x     mod p = 0x324403c896178c4823de7d41b90f7aa55e144423bd55484a2f181c21f158856e
 *   w20 = x  * y     mod p = 0x773de4339a9b373eff6740f4f7953d6993b288f32eff55fbbdc3b753b31dccb6
 *   w21 = (p-1)^2    mod p = 0x0000000000000000000000000000000000000000000000000000000000000001
 *
 * The runner uses otbn_top_sim, which co-simulates the RTL against the Python
 * ISS and compares their traces instruction by instruction: if the RTL and the
 * ISS disagree about this instruction the run aborts with a mismatch error.
 */

.section .text.start

  /* w24 = d0, w25 = x  (both from the .data section, little-endian words) */
  li        x2, 24
  la        x3, d0
  bn.lid    x2++, 0(x3)
  la        x3, x
  bn.lid    x2, 0(x3)

  /* w19 = d0 * x mod p */
  bn.p256mul w19, w24, w25

  /* w26 = y, w20 = x * y mod p */
  li        x2, 26
  la        x3, y
  bn.lid    x2, 0(x3)
  bn.p256mul w20, w25, w26

  /* w27 = p - 1, w21 = (p - 1)^2 mod p = 1 */
  li        x2, 27
  la        x3, p_m1
  bn.lid    x2, 0(x3)
  bn.p256mul w21, w27, w27

  ecall

.section .data

/* Example ECDH scalar from the official P-256 test vector set (low word first). */
.globl d0
.balign 32
d0:
  .word 0xfe6d1071
  .word 0x21d0a016
  .word 0xb0b2c781
  .word 0x9590ef5d
  .word 0x3fdfa379
  .word 0x1b76ebe8
  .word 0x74210263
  .word 0x1420fc41

/* Example curve point x-coordinate from the same vector set. */
.globl x
.balign 32
x:
  .word 0xbfa8c334
  .word 0x9773b7b3
  .word 0xf36b0689
  .word 0x6ec0c0b2
  .word 0xdb6c8bf3
  .word 0x1628ce58
  .word 0xfacdc546
  .word 0xb5511a6a

/* Example curve point y-coordinate from the same vector set. */
.globl y
.balign 32
y:
  .word 0x9e008c2e
  .word 0xa8707058
  .word 0xab9c6924
  .word 0x7f7a11d0
  .word 0xb53a17fa
  .word 0x43dd09ea
  .word 0x1f31c143
  .word 0x42a1c697

/* p - 1, the largest value below the P-256 prime (low word first). */
.globl p_m1
.balign 32
p_m1:
  .word 0xfffffffe
  .word 0xffffffff
  .word 0xffffffff
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000001
  .word 0xffffffff
