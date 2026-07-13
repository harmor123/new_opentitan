/* Copyright lowRISC contributors (OpenTitan project). */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/* Public interface. */
.globl p256_keygen

.text

/**
 * P-256 public-key generation wrapper.
 *
 * Computes the affine public key Q = d * G and writes both coordinates to DMEM.
 * This wrapper reuses the existing masked P-256 scalar multiplication kernel.
 *
 * @param[in]  dmem[d0]:   first share of scalar d (320 bits)
 * @param[in]  dmem[d1]:   second share of scalar d (320 bits)
 * @param[out] dmem[pk_x]: affine x-coordinate of Q
 * @param[out] dmem[pk_y]: affine y-coordinate of Q
 *
 * clobbered registers: x2, x16, x21, x22, w0 to w30
 * clobbered flag groups: FG0
 */
p256_keygen:
  /* Init all-zero register. */
  bn.xor    w31, w31, w31

  /* Load first share of secret key d from DMEM. */
  la        x16, d0
  li        x2, 0
  bn.lid    x2, 0(x16++)
  li        x2, 1
  bn.lid    x2, 0(x16)

  /* Load second share of secret key d from DMEM. */
  la        x16, d1
  li        x2, 2
  bn.lid    x2, 0(x16++)
  li        x2, 3
  bn.lid    x2, 0(x16)

  /* Reblind the secret key before running scalar multiplication. */
  jal       x1, p256_masked_scalar_reblind

  /* Compute Q = d * G. */
  la        x21, p256_gx
  la        x22, p256_gy
  jal       x1, scalar_mult_int

  /* Store projective coordinates for the existing on-curve check. */
  li        x2, 8
  la        x21, x
  bn.sid    x2++, 0(x21)
  la        x22, y
  bn.sid    x2++, 0(x22)
  la        x21, z
  bn.sid    x2, 0(x21)

  jal       x1, p256_isoncurve_proj
  bn.cmp    w18, w19
  jal       x1, trigger_fault_if_fg0_z

  /* Convert Q from projective to affine coordinates. */
  jal       x1, proj_to_affine

  /* Store affine public key Q = (pk_x, pk_y). */
  li        x2, 11
  la        x21, pk_x
  bn.sid    x2++, 0(x21)
  la        x22, pk_y
  bn.sid    x2, 0(x22)

  ret

.section .bss

/* P-256 public key x-coordinate. */
.globl pk_x
.balign 32
pk_x:
  .zero 32

/* P-256 public key y-coordinate. */
.globl pk_y
.balign 32
pk_y:
  .zero 32

/* Temporary projective z-coordinate used by the on-curve check. */
.globl z
.balign 32
z:
  .zero 32
