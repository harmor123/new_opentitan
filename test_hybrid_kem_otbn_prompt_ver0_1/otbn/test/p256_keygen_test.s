/* Copyright lowRISC contributors (OpenTitan project). */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/**
 * Standalone P-256 public-key generation test.
 *
 * Computes Q = d * G using the p256_keygen wrapper. The output symbols pk_x
 * and pk_y are checked by the .dexp file.
 */

.section .text.start

.globl main
main:
  jal      x1, p256_keygen
  ecall

.data

/* Secret key d in arithmetic shares. */
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
  .zero 32

.globl d1
.balign 32
d1:
  .zero 64
