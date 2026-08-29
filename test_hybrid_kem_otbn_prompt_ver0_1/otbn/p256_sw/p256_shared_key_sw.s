/* Copyright lowRISC contributors (OpenTitan project). */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/**
 * @file p256_shared_key_sw.s
 *
 * Plain-software P-256 ECDH shared-key wrapper for OTBN profiling.
 *
 * Computes:
 *
 *     S = d * Q_peer
 *
 * where:
 *     d      is a single unmasked 256-bit private scalar,
 *     Q_peer is the peer's affine P-256 public key,
 *     S      is the resulting P-256 point.
 *
 * The ECDH shared secret is defined here as the affine x-coordinate:
 *
 *     shared_secret = x(S)
 *
 * This wrapper intentionally excludes:
 *   - scalar masking / secret sharing
 *   - scalar reblinding
 *   - randomized projective coordinates
 *   - arithmetic-to-boolean masking conversion
 *   - fault-injection countermeasures
 *
 * It is intended as the plain OTBN software profiling baseline.
 */


/* Public interface. */
.globl p256_shared_key_sw

.text


/**
 * Plain P-256 ECDH shared-key generation.
 *
 * Inputs:
 *
 *   dmem[scalar]:
 *       256-bit private scalar d.
 *
 *   dmem[peer_x]:
 *       affine x-coordinate of peer public key Q_peer.
 *
 *   dmem[peer_y]:
 *       affine y-coordinate of peer public key Q_peer.
 *
 * Output:
 *
 *   dmem[shared_x]:
 *       affine x-coordinate of:
 *
 *           S = d * Q_peer
 *
 *
 * Uses:
 *
 *   scalar_mult_sw
 *   proj_to_affine
 *
 *
 * Register interface of scalar_mult_sw:
 *
 *   w0  = scalar d
 *   x21 = pointer to affine input point x-coordinate
 *   x22 = pointer to affine input point y-coordinate
 *
 *
 * scalar_mult_sw returns:
 *
 *   w8  = projective X-coordinate
 *   w9  = projective Y-coordinate
 *   w10 = projective Z-coordinate
 *
 *
 * proj_to_affine returns:
 *
 *   w11 = affine x-coordinate
 *   w12 = affine y-coordinate
 */
p256_shared_key_sw:

  /*
   * Initialize the all-zero wide register used by the P-256 arithmetic
   * routines.
   *
   *   w31 = 0
   */
  bn.xor    w31, w31, w31


  /*
   * Load the plain 256-bit private scalar.
   *
   *   w0 = dmem[scalar]
   *
   * One bn.lid is sufficient because a wide data register is 256 bits.
   */
  la        x16, scalar
  li        x2, 0
  bn.lid    x2, 0(x16)


  /*
   * Select the peer public key as the input point P.
   *
   * scalar_mult_sw expects pointers to affine coordinates:
   *
   *   x21 -> P.x
   *   x22 -> P.y
   *
   * Therefore:
   *
   *   P = Q_peer = (peer_x, peer_y)
   */
  la        x21, peer_x
  la        x22, peer_y


  /*
   * Compute:
   *
   *   S = d * Q_peer
   *
   * The resulting point is returned in projective coordinates:
   *
   *   w8  = X
   *   w9  = Y
   *   w10 = Z
   */
  jal       x1, scalar_mult_sw


  /*
   * Convert:
   *
   *   (X, Y, Z)
   *
   * into affine coordinates:
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
   * P-256 ECDH uses the affine x-coordinate of the shared point
   * as the shared secret material.
   *
   *   dmem[shared_x] = w11
   */
  la        x16, shared_x
  li        x2, 11
  bn.sid    x2, 0(x16)


  ret


/*
 * --------------------------------------------------------------------------
 * DMEM interface
 * --------------------------------------------------------------------------
 *
 * These buffers belong specifically to the ECDH shared-key application.
 *
 * The P-256 field constants and arithmetic routines are supplied by
 * p256_base_sw.s.
 */


.section .bss


/*
 * Plain 256-bit private scalar d.
 *
 * Unlike the native masked OpenTitan implementation, this software baseline
 * contains only one scalar and therefore does not use d0/d1 shares.
 */
.globl scalar
.balign 32
scalar:
  .zero 32


/*
 * Affine x-coordinate of the peer P-256 public key.
 */
.globl peer_x
.balign 32
peer_x:
  .zero 32


/*
 * Affine y-coordinate of the peer P-256 public key.
 */
.globl peer_y
.balign 32
peer_y:
  .zero 32


/*
 * P-256 ECDH shared-secret material.
 *
 * This contains the affine x-coordinate of:
 *
 *   S = d * Q_peer
 */
.globl shared_x
.balign 32
shared_x:
  .zero 32
