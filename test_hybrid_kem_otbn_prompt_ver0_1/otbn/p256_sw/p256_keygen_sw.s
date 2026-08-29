/* Copyright lowRISC contributors (OpenTitan project). */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/**
 * @file p256_keygen_sw.s
 *
 * Plain-software P-256 public-key generation wrapper for OTBN profiling.
 *
 * Computes:
 *
 *     Q = d * G
 *
 * where:
 *     d is a single unmasked 256-bit private scalar,
 *     G is the standard P-256 base point,
 *     Q is returned in affine coordinates.
 *
 * This wrapper intentionally excludes:
 *   - scalar masking / secret sharing
 *   - scalar reblinding
 *   - randomized projective coordinates
 *   - fault-injection countermeasures
 *
 * It is intended only as the pure-software profiling baseline.
 */


/* Public interface. */
.globl p256_keygen_sw

.text


/**
 * Plain P-256 public-key generation.
 *
 * Input:
 *   dmem[scalar]:
 *       256-bit private scalar d.
 *
 * Output:
 *   dmem[pk_x]:
 *       affine x-coordinate of Q = dG.
 *
 *   dmem[pk_y]:
 *       affine y-coordinate of Q = dG.
 *
 * Uses:
 *   scalar_mult_sw
 *   proj_to_affine
 *   p256_gx
 *   p256_gy
 *
 * Register interface of scalar_mult_sw:
 *   w0  = scalar d
 *   x21 = pointer to affine input point x-coordinate
 *   x22 = pointer to affine input point y-coordinate
 *
 * scalar_mult_sw returns:
 *   w8  = projective X
 *   w9  = projective Y
 *   w10 = projective Z
 *
 * proj_to_affine returns:
 *   w11 = affine x-coordinate
 *   w12 = affine y-coordinate
 */
p256_keygen_sw:

  /*
   * Initialize the architectural all-zero wide register used throughout
   * the P-256 arithmetic routines.
   *
   *   w31 = 0
   */
  bn.xor    w31, w31, w31


  /*
   * Load the plain 256-bit private scalar from DMEM.
   *
   *   w0 = dmem[scalar]
   *
   * scalar contains exactly one 256-bit value, so one bn.lid is enough.
   */
  la        x16, scalar
  li        x2, 0
  bn.lid    x2, 0(x16)


  /*
   * Select the standard P-256 generator G as the input point.
   *
   * scalar_mult_sw expects:
   *
   *   x21 -> affine x-coordinate
   *   x22 -> affine y-coordinate
   *
   * Therefore:
   *
   *   P = G = (p256_gx, p256_gy)
   */
  la        x21, p256_gx
  la        x22, p256_gy


  /*
   * Compute:
   *
   *   Q = d * G
   *
   * Result is returned in projective coordinates:
   *
   *   w8  = X
   *   w9  = Y
   *   w10 = Z
   */
  jal       x1, scalar_mult_sw


  /*
   * Convert projective result:
   *
   *   (X, Y, Z)
   *
   * to affine:
   *
   *   x = X / Z mod p
   *   y = Y / Z mod p
   *
   * Outputs:
   *
   *   w11 = affine x
   *   w12 = affine y
   */
  jal       x1, proj_to_affine


  /*
   * Store affine public-key x-coordinate.
   *
   *   dmem[pk_x] = w11
   */
  la        x16, pk_x
  li        x2, 11
  bn.sid    x2, 0(x16)


  /*
   * Store affine public-key y-coordinate.
   *
   *   dmem[pk_y] = w12
   */
  la        x16, pk_y
  li        x2, 12
  bn.sid    x2, 0(x16)


  ret


/*
 * --------------------------------------------------------------------------
 * DMEM interface
 * --------------------------------------------------------------------------
 *
 * Keep only the data that belongs specifically to the KeyGen application.
 *
 * Constants such as:
 *
 *   p256_p
 *   p256_b
 *   p256_r448
 *   p256_gx
 *   p256_gy
 *
 * are defined in p256_base_sw.s.
 */


.section .bss


/*
 * Plain 256-bit private scalar d.
 *
 * This is deliberately NOT represented as:
 *
 *   d0
 *   d1
 *
 * because this software baseline does not use masking/sharing.
 */
.globl scalar
.balign 32
scalar:
  .zero 32


/*
 * Affine x-coordinate of generated public key Q=dG.
 */
.globl pk_x
.balign 32
pk_x:
  .zero 32


/*
 * Affine y-coordinate of generated public key Q=dG.
 */
.globl pk_y
.balign 32
pk_y:
  .zero 32