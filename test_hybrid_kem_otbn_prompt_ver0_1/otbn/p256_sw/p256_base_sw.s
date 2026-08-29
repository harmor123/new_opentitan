/* Copyright lowRISC contributors (OpenTitan project). */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/* Copyright 2016 The Chromium OS Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE.dcrypto file.
 *
 * Derived from code in
 * https://chromium.googlesource.com/chromiumos/platform/ec/+/refs/heads/cr50_stab/chip/g/dcrypto/dcrypto_p256.c
 */
.globl scalar_mult_sw
.globl mul_modp
.globl setup_modp

.globl proj_add
.globl proj_to_affine

/* Exposed only for testing or SCA purposes. */

.globl proj_double

.text


/**
 * 256-bit modular multiplication for P-256 coordinate field.
 *
 * Returns c = a * b mod p
 *
 * Uses a specialized algorithm to quicly multiply modulo the P-256 coordinate
 * modulus p = 2^256 - 2^224 + 2^192 + 2^96 - 1.
 *
 * This code has been proven correct in Coq here against a simplified model of
 * OTBN (simplified in the sense of only including the instructions and
 * functionality that this code uses):
 * https://gist.github.com/jadephilipoom/5c1910fd355f730238c99ce620aed98a
 *
 * For more details about the code and how to read the proofs above, see the PR
 * description here: https://github.com/lowRISC/opentitan/pull/20701
 *
 * Flags: Flags have no meaning beyond the scope of this subroutine.
 *
 * @param[in]  w24: a, first 256 bit operand (a < p)
 * @param[in]  w25: b, second 256 bit operand (b < p)
 * @param[in]  w28: r256, constant, 2^256 mod p = 2^256 - p
 * @param[in]  w29: r448, constant, 2^448 mod p
 * @param[in]  w31: all-zero
 * @param[in]  MOD: p, modulus of P-256 underlying finite field
 * @param[out]  w19: c, result
 *
 * clobbered registers: w19, w20, w21, w22, w23, w24, w25
 * clobbered flag groups: FG0
 */
mul_modp:
  /* First, compute the high partial products (coefficient 2^192 or higher).
       w19,w20.U <= 2^192*(a0b3 + a1b2 + a2b1 + a3b0)
                    + 2^256*(a1b3 + a2b2 + a3b1)
                    + 2^320*(a2b3 + a3b2)
                    + 2^384*a3b3 */
  bn.mulqacc.z          w24.0, w25.3, 64  /* a0b3 */
  bn.mulqacc            w24.1, w25.2, 64  /* a1b2 */
  bn.mulqacc            w24.2, w25.1, 64  /* a2b1 */
  bn.mulqacc.so  w20.U, w24.3, w25.0, 64  /* a3b0 */
  bn.mulqacc            w24.1, w25.3, 0   /* a1b3 */
  bn.mulqacc            w24.2, w25.2, 0   /* a2b2 */
  bn.mulqacc            w24.3, w25.1, 0   /* a3b1 */
  bn.mulqacc            w24.2, w25.3, 64  /* a2b3 */
  bn.mulqacc            w24.3, w25.2, 64  /* a3b2 */
  bn.mulqacc.wo    w19, w24.3, w25.3, 128 /* a3b3 */

  /* Now, we have:
     a * b = a0b0 + 2^64*(a0b1 + a1b0) + 2^128*(a0b2 + a1b1 + a2b0 + w20.U)
             + 2^256*w19

     If we separate w19 into limbs t0, t1, t2, and t3, that gives us
     a * b = a0b0 + 2^64*(a0b1 + a1b0) + 2^128*(a0b2 + a1b1 + a2b0 + w20.U)
              + 2^256*t0 + 2^320*t1 + 2^384*t2 + 2^448*t3

     This implies the modular equivalence:
     (a * b) mod p
       \equiv (a0b0 + 2^64*(a0b1 + a1b0) + 2^128*(a0b2 + a1b1 + a2b0 + w20.U)
              + (2^256 mod p)*t0 + (2^448 mod p)*t3 - ((-2^320) mod p)*t1
              - ((-2^384) mod p)*t2

     The only reason above for using ((-2^320) mod p) and ((-2^384) mod p)
     instead of (2^320 mod p) and (2^384 mod p) is that, for these specific
     values, the positive terms are ~256 bits and the negative ones are ~224
     bits, so the negative ones are quicker to compute.

     For simplicity, let's call the additive terms u and the subtractive ones v:
     u = a0b0 + 2^64*(a0b1 + a1b0) + 2^128*(a0b2 + a1b1 + a2b0 + w20.U)
         + (2^256 mod p)*t0 + (2^448 mod p)*t3
     v = ((-2^320) mod p)*t1 + ((-2^384) mod p)*t2
     (a * b) mod p \equiv (u - v) mod p
  */

  /* Compute the additive terms (u). The term in w21 is offset 128 bits to save
     a writeback instruction.
       w20 + w21 << 384 = u  */
  bn.mulqacc.z          w24.0, w25.0, 0   /* a0b0 */
  bn.mulqacc            w28.0, w19.0, 0   /* r256[0] * t0 */
  bn.mulqacc            w29.0, w19.3, 0   /* r448[0] * t3 */
  bn.mulqacc            w24.0, w25.1, 64  /* a0b1 */
  bn.mulqacc            w24.1, w25.0, 64  /* a1b0 */
  bn.mulqacc            w28.1, w19.0, 64  /* r256[1] * t0 */
  bn.mulqacc.so  w20.L, w29.1, w19.3, 64  /* r448[1] * t3 */
  bn.mulqacc            w24.0, w25.2, 0   /* a0b2 */
  bn.mulqacc            w24.1, w25.1, 0   /* a1b1 */
  bn.mulqacc            w24.2, w25.0, 0   /* a2b0 */
  bn.mulqacc            w28.2, w19.0, 0   /* r256[2] * t0 */
  bn.mulqacc            w29.2, w19.3, 0   /* r448[2] * t3 */
  bn.mulqacc            w28.3, w19.0, 64  /* r256[3] * t0 */
  bn.mulqacc.wo    w21, w29.3, w19.3, 64  /* r448[3] * t3 */

  /* To fully reduce u mod p, we'll separate the low 256 bits (u0) from the
     high 33 bits (u1) and compute:
      u0 + (2^256 mod p)*u1 = u0 + (2^224 - 2^192 - 2^96 + 1) * u1 */

  /* Rotate 128 bits to undo the offset and put u1 in the least significant
     position.
       w22 <= w21[128:0] << 128 | w21[255:127] */
  bn.rshi   w22, w21, w21 >> 128

  /* w21 <= (u0 + u1) mod p */
  bn.addm   w20, w20, w31
  bn.addm   w21, w22, w31
  bn.addm   w21, w20, w21

  /* w24 <= u1 << 223 */
  bn.rshi   w24, w22, w31 >> 33

  /* w25 <= u1 * (2^223 - 2^191 - 2^95) */
  bn.sub    w25, w24, w24 >> 32
  bn.sub    w25, w25, w24 >> 128

  /* Note: the value in w25 is small enough for addm because u1 < 2^33, and
     2^33*(2^223 - 2^191 - 2^95) < p.
     w25 <= (u0 + (2^224 - 2^192 - 2^96 + 1) * u1) mod p = u mod p */
  bn.addm   w25, w25, w25
  bn.addm   w25, w25, w21

  /* Now, compute the subtractive terms (v). We don't store constants for this
     one; instead we transform the expression into something that is
     computable with (the minimum number of) shifts and adds.
       v = ((-2^320) mod p)*t1 + ((-2^384) mod p)*t2
         = t1 * (2^224 + 2^160 + 2^128 - 2^64 - 2^32)
           + t2 * (2^224 - 2*2^128 - 2*2^96 + 2^32 + 1)
         = 2^224 * (t1 + t2) + (2^32 + 1) * (t1*2^128 + t2)
           - 2^32 * (2^32 + 1) * (t1 + t2*2*2^64) */

  /* First, isolate t1 and t2 using `mulqacc` and the lowest limb of r256,
     which happens to be 1. This method is faster than using shifts.
       w20 <= t1
       w21 <= t2 */
  bn.mulqacc.wo.z  w20, w28.0, w19.1, 0
  bn.mulqacc.wo.z  w21, w28.0, w19.2, 0

  /* w22 <= (2^32 + 1) * (t1*2^128 + t2) */
  bn.add    w22, w21, w20 << 128
  bn.add    w22, w22, w22 << 32

  /* w23 <= t1 + t2 */
  bn.add    w23, w20, w21

  /* w24 <= (2^32 + 1) * (t1 + 2*2^64*t2) */
  bn.add    w24, w20, w21 << 64
  bn.add    w24, w24, w21 << 64
  bn.add    w24, w24, w24 << 32

  /* w21, w20 <= v */
  bn.add    w20, w22, w23 << 224
  bn.addc   w21, w31, w23 >> 32
  bn.sub    w20, w20, w24 << 32
  bn.subb   w21, w21, w31

  /* The maximum value of v is 289 bits, so we can now reduce v the same way we
     reduced u earlier. */

  /* w22 <= (v0 + v1) mod p */
  bn.addm   w22, w20, w21

  /* w24 <= v1 << 223 */
  bn.rshi   w24, w21, w31 >> 33

  /* w23 <= v1 * (2^223 - 2^191 - 2^95) */
  bn.sub    w23, w24, w24 >> 32
  bn.sub    w23, w23, w24 >> 128

  /* w23 <= (v0 + (2^224 - 2^192 - 2^96 + 1) * v1) mod p = v mod p */
  bn.addm   w23, w23, w23
  bn.addm   w23, w23, w22

  /* w19 = (u - v) mod p = (a * b) mod p */
  bn.subm   w19, w25, w23

  ret


/**
 * Set up for coordinate field operations modulo the prime p.
 *
 * Loads the constants required by `mul_modp` and other coordinate-arithmetic
 * routines.
 *
 * Flags: Flags have no meaning beyond the scope of this subroutine.
 *
 * @param[in]  w31: all-zero
 * @param[out] MOD: p, modulus of P-256 underlying finite field
 * @param[out] w28: r256, constant, 2^256 mod p = 2^256 - p
 * @param[out] w29: r448, constant, 2^448 mod p
 *
 * clobbered registers: w28, w29
 * clobbered flag groups: FG0
 */
setup_modp:
  /* Load the modulus p from DMEM and store it in MOD.
     MOD <= w29 <= p = dmem[p256_p] */
  li        x2, 29
  la        x3, p256_p
  bn.lid    x2, 0(x3)
  bn.wsrw   MOD, w29

  /* Compute the constant r256 for reduction modulo p.
       w28 <= 2^256 - p = r256 */
  bn.sub   w28, w31, w29

  /* Load the constant r448 for reduction modulo p.
     w29 <= dmem[p256_r448] = r448 */
  li        x2, 29
  la        x3, p256_r448
  bn.lid    x2, 0(x3)
  ret

/**
 * P-256 point addition in projective coordinates
 *
 * returns R = (x_r, y_r, z_r) <= P+Q = (x_p, y_p, z_p) + (x_q, y_q, z_q)
 *         with R, P and Q being valid P-256 curve points
 *           in projective coordinates
 *
 * This routine adds two valid P-256 curve points in projective space.
 * Point addition is performed based on the complete formulas of Bosma and
 * Lenstra for Weierstrass curves as first published in [1] and
 * optimized in [2].
 * The implemented version follows Algorithm 4 of [2] which is an optimized
 * variant for Weierstrass curves with domain parameter 'a' set to a=-3.
 * Numbering of the steps below and naming of symbols follows the
 * terminology of Algorithm 4 of [2].
 * The routine is limited to P-256 curve points due to:
 *   - fixed a=-3 domain parameter
 *   - usage of a P-256 optimized modular multiplication kernel
 * This routine runs in constant time.
 *
 * [1] https://doi.org/10.1006/jnth.1995.1088
 * [2] https://doi.org/10.1007/978-3-662-49890-3_16
 *
 * @param[in]  w8: x_p, x-coordinate of input point P
 * @param[in]  w9: y_p, y-coordinate of input point P
 * @param[in]  w10: z_p, z-coordinate of input point P
 * @param[in]  w11: x_q, x-coordinate of input point Q
 * @param[in]  w12: y_q, x-coordinate of input point Q
 * @param[in]  w13: z_q, x-coordinate of input point Q
 * @param[in]  w27: b, curve domain parameter
 * @param[in]  w28: r256, constant, 2^256 mod p = 2^256 - p
 * @param[in]  w29: r448, constant, 2^448 mod p
 * @param[in]  w31: all-zero.
 * @param[in]  MOD: p, modulus, 2^256 > p > 2^255.
 * @param[out]  w11: x_r, x-coordinate of resulting point R
 * @param[out]  w12: y_r, x-coordinate of resulting point R
 * @param[out]  w13: z_r, x-coordinate of resulting point R
 *
 * Flags: Flags have no meaning beyond the scope of this subroutine.
 *
 * clobbered registers: w11 to w25
 * clobbered flag groups: FG0
 */
proj_add:
  /* mapping of parameters to symbols of [2] (Algorithm 4):
     X1 = x_p; Y1 = y_p; Z1 = z_p; X2 = x_q; Y2 = y_q; Z2 = z_q
     X3 = x_r; Y3 = y_r; Z3 = z_r */

  /* 1: w14 = t0 <= X1*X2 = w11*w8 */
  bn.mov    w24, w11
  bn.mov    w25, w8
  jal       x1, mul_modp
  bn.mov    w14, w19

  /* 2: w15 = t1 <= Y1*Y2 = w12*w9 */
  bn.mov    w24, w12
  bn.mov    w25, w9
  jal       x1, mul_modp
  bn.mov    w15, w19

  /* 3: w16 = t2 <= Z1*Z2 = w13*w10*/
  bn.mov    w24, w13
  bn.mov    w25, w10
  jal       x1, mul_modp
  bn.mov    w16, w19

  /* 5: w17 = t4 <= X2+Y2 = w11 + w12 */
  bn.addm   w17, w11, w12

  /* 4: w18 = t3 <= X1+Y1 = w8+w9 */
  bn.addm   w18, w8, w9

  /* 6: w19 = t3 <= t3*t4 = w18*w17 */
  bn.mov    w24, w17
  bn.mov    w25, w18
  jal       x1, mul_modp

  /* 7: w18 = t4 <= t0+t1 = w14+w15 */
  bn.addm   w18, w14, w15

  /* 8: w17 = t3 <= t3 - t4 = w19 - w18 */
  bn.subm   w17, w19, w18

  /* 10: w18 = X3 <= Y2 + Z2 = w12 + w13 */
  bn.addm   w18, w12, w13

  /* 9: w19 = t4 <= Y1 + Z1 = w9 + w10 */
  bn.addm   w19, w9, w10

  /* 11: w18 = t4 <= t4 * X3 = w19 * w18 */
  bn.mov    w24, w18
  bn.mov    w25, w19
  jal       x1, mul_modp
  bn.mov    w18, w19

  /* 12: w19 = X3 <= t1 + t2 = w15 + w16 */
  bn.addm   w19, w15, w16

  /* 13: w18 = t4 <= t4 - X3 = w18 + w19 */
  bn.subm   w18, w18, w19

  /* 15: w19 = Y3 <= X2 + Z2 = w11 + w13 */
  bn.addm   w19, w11, w13

  /* 14: w12 = X3 <= X1 + Z1 = w8 + w10 */
  bn.addm   w12, w8, w10

  /* 16: w11 = X3 <= X3 * Y3 = w12 * w19 */
  bn.mov    w24, w19
  bn.mov    w25, w12
  jal       x1, mul_modp
  bn.mov    w11, w19

  /* 17: w12 = Y3 <= t0 + t2 = w14 + w16 */
  bn.addm   w12, w14, w16

  /* 18: w12 = Y3 <= X3 - Y3 = w11 - w12 */
  bn.subm   w12, w11, w12

  /* 19: w19 = Z3 <= b * t2 =  w27 * w16 */
  bn.mov    w24, w27
  bn.mov    w25, w16
  jal       x1, mul_modp

  /* 20: w11 = X3 <= Y3 -Z3 = w12 - w19 */
  bn.subm   w11, w12, w19

  /* 21: w13 = Z3 <= X3 + X3 = w11 + w11 */
  bn.addm   w13, w11, w11

  /* 22: w11 = X3 <= w11 + w13 = X3 + Z3 */
  bn.addm   w11, w11, w13

  /* 23: w13 = Z3 <= t1 - X3 = w15 - w11 */
  bn.subm   w13, w15, w11

  /* 24: w11 = X3 <= t1 + X3 = w15 + w11 */
  bn.addm   w11, w15, w11

  /* 25: w19 = Y3 <= w27 * w12 = b * Y3 */
  bn.mov    w24, w27
  bn.mov    w25, w12
  jal       x1, mul_modp

  /* 26: w15 = t1 <= t2 + t2 = w16 + w16 */
  bn.addm   w15, w16, w16

  /* 27: w16 = t2 <= t1 + t2 = w15 + w16 */
  bn.addm   w16, w15, w16

  /* 28: w12 = Y3 <= Y3 - t2 = w19 - w16 */
  bn.subm   w12, w19, w16

  /* 29: w12 = Y3 <= Y3 - t0 = w12 - w14 */
  bn.subm   w12, w12, w14

  /* 30: w15 = t1 <= Y3 + Y3 = w12 + w12 */
  bn.addm   w15, w12, w12

  /* 31: w12 = Y3 <= t1 + Y3 = w15 + w12*/
  bn.addm   w12, w15, w12

  /* 32: w15 = t1 <= t0 + t0 = w14 + w14 */
  bn.addm   w15, w14, w14

  /* 33: w14 = t0 <= t1 + t0 = w15 + w14 */
  bn.addm   w14, w15, w14

  /* 34: w14 = t0 <= t0 - t2 = w14 - w16 */
  bn.subm   w14, w14, w16

  /* 35: w15 = t1 <= t4 * Y3 = w18 * w12 */
  bn.mov    w24, w18
  bn.mov    w25, w12
  jal       x1, mul_modp
  bn.mov    w15, w19

  /* 36: w16 = t2 <= t0 * Y3 = w14 * w12 */
  bn.mov    w24, w14
  bn.mov    w25, w12
  jal       x1, mul_modp
  bn.mov    w16, w19

  /* 37: w12 = Y3 <= X3 * Z3 = w11 * w13 */
  bn.mov    w24, w11
  bn.mov    w25, w13
  jal       x1, mul_modp

  /* 38: w12 = Y3 <= Y3 + t2 = w19 + w16 */
  bn.addm   w12, w19, w16

  /* 39: w19 = X3 <= t3 * X3 = w17 * w11 */
  bn.mov    w24, w17
  bn.mov    w25, w11
  jal       x1, mul_modp

  /* 40: w11 = X3 <= X3 - t1 = w19 - w15 */
  bn.subm   w11, w19, w15

  /* 41: w13 = Z3 <= t4 * Z3 = w18 * w13 */
  bn.mov    w24, w18
  bn.mov    w25, w13
  jal       x1, mul_modp
  bn.mov    w13, w19

  /* 42: w19 = t1 <= t3 * t0 = w17 * w14 */
  bn.mov    w24, w17
  bn.mov    w25, w14
  jal       x1, mul_modp

  /* 43: w13 = Z3 <= Z3 + t1 = w13 + w19 */
  bn.addm   w13, w13, w19

  ret


/**
 * Convert projective coordinates of a P-256 curve point to affine coordinates
 *
 * returns P = (x_a, y_a) = (x/z mod p, y/z mod p)
 *         with P being a valid P-256 curve point
 *              x_a and y_a being the affine coordinates of said curve point
 *              x, y and z being a set of projective coordinates of said point
 *              and p being the modulus of the P-256 underlying finite field.
 *
 * This routine computes the affine coordinates for a set of projective
 * coordinates of a valid P-256 curve point. The routine performs the required
 * divisions by computing the multiplicative modular inverse of the
 * projective z-coordinate in the underlying finite field of the P-256 curve.
 * For inverse computation Fermat's little theorem is used, i.e.
 * we compute z^-1 = z^(p-2) mod p.
 *
 * For exponentiation, we use an addition chain from Brian Smith's collection
 * of the fastest known addition chains:
 * https://briansmith.org/ecc-inversion-addition-chains-01#p256_field_inversion
 *
 * The chain is based on work by Gueron and Krasnov[1], with one more addition
 * shaved off by Smith himself.
 *
 * [1] https://eprint.iacr.org/2013/816.pdf
 *
 * This routine runs in constant time.
 *
 * Flags: When leaving this subroutine, the M, L and Z flags of FG0 depend on
 *        the computed affine y-coordinate.
 *
 * @param[in]  w8: x, x-coordinate of curve point (projective)
 * @param[in]  w9: y, y-coordinate of curve point (projective)
 * @param[in]  w10: z, z-coordinate of curve point (projective)
 * @param[in]  w28: r256, constant, 2^256 mod p = 2^256 - p
 * @param[in]  w29: r448, constant, 2^448 mod p
 * @param[in]  MOD: p, modulus of the finite field of P-256
 * @param[out]  w11: x_a, x-coordinate of curve point (affine)
 * @param[out]  w12: y_a, y-coordinate of curve point (affine)
 * @param[out]  w14: z^-1, modular inverse of the projective z-coordinate
 *
 * clobbered registers: w10 to w19, w24, w25
 * clobbered flag groups: FG0
 */
proj_to_affine:

  /* Fully reduce z. */
  bn.addm   w10, w10, w31

  /* w19 <= z^2 */
  bn.mov    w24, w10
  bn.mov    w25, w10
  jal       x1, mul_modp

  /* w12 <= z^3 = x2 */
  bn.mov    w24, w19
  bn.mov    w25, w10
  jal       x1, mul_modp
  bn.mov    w12, w19

  /* w19 <= z^6 */
  bn.mov    w24, w19
  bn.mov    w25, w19
  jal       x1, mul_modp

  /* w13 <= z^7 = z^(2^3 - 1) = x3 */
  bn.mov    w24, w19
  bn.mov    w25, w10
  jal       x1, mul_modp
  bn.mov    w13, w19

  /* w14 <= z^(2^6 - 1) = x6 */
  bn.mov    w24, w19
  loopi     3, 3
    bn.mov    w25, w19
    jal       x1, mul_modp
    bn.mov    w24, w19
  bn.mov    w25, w13
  jal       x1, mul_modp
  bn.mov    w14, w19

  /* w15 <= z^(2^12 - 1) = x12 */
  bn.mov    w24, w19
  loopi     6, 3
    bn.mov    w25, w19
    jal       x1, mul_modp
    bn.mov    w24, w19
  bn.mov    w25, w14
  jal       x1, mul_modp
  bn.mov    w15, w19

  /* w16 <= z^(2^15 - 1) = x15 */
  bn.mov    w24, w19
  loopi     3, 3
    bn.mov    w25, w19
    jal       x1, mul_modp
    bn.mov    w24, w19
  bn.mov    w25, w13
  jal       x1, mul_modp
  bn.mov    w16, w19

  /* w17 <= z^(2^30 - 1) = x30 */
  bn.mov    w24, w19
  loopi     15, 3
    bn.mov    w25, w19
    jal       x1, mul_modp
    bn.mov    w24, w19
  bn.mov    w25, w16
  jal       x1, mul_modp
  bn.mov    w17, w19

  /* w18 <= z^(2^32 - 1) = x32 */
  bn.mov    w24, w19
  loopi     2, 3
    bn.mov    w25, w19
    jal       x1, mul_modp
    bn.mov    w24, w19
  bn.mov    w25, w12
  jal       x1, mul_modp
  bn.mov    w18, w19

  /* w19 <= z^(2^64 - 2^32 + 1) */
  bn.mov    w24, w19
  loopi     32, 3
    bn.mov    w25, w19
    jal       x1, mul_modp
    bn.mov    w24, w19
  bn.mov    w25, w10
  jal       x1, mul_modp

  /* w19 <= z^(2^192 - 2^160 + 2^128 + 2^32 - 1) */
  bn.mov    w24, w19
  loopi     128, 3
    bn.mov    w25, w19
    jal       x1, mul_modp
    bn.mov    w24, w19
  bn.mov    w25, w18
  jal       x1, mul_modp

  /* w19 <= z^(2^224 - 2^192 + 2^160 + 2^64 + 1) */
  bn.mov    w24, w19
  loopi     32, 3
    bn.mov    w25, w19
    jal       x1, mul_modp
    bn.mov    w24, w19
  bn.mov    w25, w18
  jal       x1, mul_modp

  /* w19 <= z^(2^254 - 2^222 + 2^190 + 2^94 - 1) */
  bn.mov    w24, w19
  loopi     30, 3
    bn.mov    w25, w19
    jal       x1, mul_modp
    bn.mov    w24, w19
  bn.mov    w25, w17
  jal       x1, mul_modp

  /* w14 <= z^(2^256 - 2^224 + 2^192 + 2^96 - 2^2 + 1) = z^(p-2) */
  bn.mov    w24, w19
  loopi     2, 3
    bn.mov    w25, w19
    jal       x1, mul_modp
    bn.mov    w24, w19
  bn.mov    w25, w10
  jal       x1, mul_modp
  bn.mov    w14, w19

  /* convert x-coordinate to affine
     w11 = x_a = x/z = x * z^(-1) = w8 * w14 */
  bn.mov    w24, w8
  bn.mov    w25, w14
  jal       x1, mul_modp
  bn.mov    w11, w19

  /* convert y-coordinate to affine
     w12 = y_a = y/z = y * z^(-1) = w9 * w14 */
  bn.mov    w24, w9
  bn.mov    w25, w14
  jal       x1, mul_modp
  bn.mov    w12, w19

  ret



/**
 * P-256 point doubling in projective space
 *
 * returns R = (x_r, y_r, z_r) <= 2*P = 2*(x_p, y_p, z_p)
 *         with R, P being valid P-256 curve points
 *
 * This routines doubles a given P-256 curve point in projective coordinates.
 * The implementation is based on the following entry in the Explicit Formulas
 * Database:
 * http://hyperelliptic.org/EFD/g1p/auto-shortw-projective-3.html#doubling-dbl-2007-bl-2
 *
 * Algorithm (copied from EFD):
 *    w = 3*(X1-Z1)*(X1+Z1)
 *    s = 2*Y1*Z1
 *    ss = s^2
 *    sss = s*ss
 *    R = Y1*s
 *    RR = R^2
 *    B = 2*X1*R
 *    h = w^2-2*B
 *    X3 = h*s
 *    Y3 = w*(B-h)-2*RR
 *    Z3 = sss
 *
 * This routine relies on the assumption that the domain parameter a of the
 * elliptic curve is -3. It computes the result in 7 multiplies and 3 squares
 * instead of 14 multiplies.
 *
 * This routine runs in constant time.
 *
 * @param[in]  w8: x_p, x-coordinate of input point
 * @param[in]  w9: y_p, y-coordinate of input point
 * @param[in]  w10: z_p, z-coordinate of input point
 * @param[in]  w28: r256, constant, 2^256 mod p = 2^256 - p
 * @param[in]  w29: r448, constant, 2^448 mod p
 * @param[in]  w31: all-zero.
 * @param[in]  MOD: p, modulus of P-256 underlying finite field
 * @param[out]  w8: x_r, x-coordinate of resulting point
 * @param[out]  w9: y_r, y-coordinate of resulting point
 * @param[out]  w10: z_r, z-coordinate of resulting point
 *
 * Flags: Flags have no meaning beyond the scope of this subroutine.
 *
 * clobbered registers: w14 to w25
 * clobbered flag groups: FG0
 */
proj_double:
  /* w14 <= 3 * (w8 - w10) * (w8 + w10) = 3 * (X1 - Z1) * (X1 + Z1) = w */
  bn.subm   w24, w8, w10
  bn.addm   w25, w8, w10
  jal       x1, mul_modp
  bn.addm   w14, w19, w19
  bn.addm   w14, w14, w19

  /* w15 <= 2 * w9 * w10 = 2 * Y1 * Z1 = s */
  bn.mov    w24, w9
  bn.mov    w25, w10
  jal       x1, mul_modp
  bn.addm   w15, w19, w19

  /* w16 <= w9 * w15 = Y1 * s = R */
  bn.mov    w24, w9
  bn.mov    w25, w15
  jal       x1, mul_modp
  bn.mov    w16, w19

  /* w17 <= 2 * w8 * w16 = 2 * X1 * R = B */
  bn.mov    w24, w8
  bn.mov    w25, w16
  jal       x1, mul_modp
  bn.addm   w17, w19, w19

  /* w18 <= w14^2 - 2*w17 = w^2 - 2*B = h */
  bn.mov    w24, w14
  bn.mov    w25, w14
  jal       x1, mul_modp
  bn.subm   w18, w19, w17
  bn.subm   w18, w18, w17

  /* w8 <= w18 * w15 = h * s = X1 */
  bn.mov    w24, w18
  bn.mov    w25, w15
  jal       x1, mul_modp
  bn.mov    w8, w19

  /* w10 <= w15 * w15 * w15 = s * s * s = sss  = Z1 */
  bn.mov    w24, w15
  bn.mov    w25, w15
  jal       x1, mul_modp
  bn.mov    w24, w19
  bn.mov    w25, w15
  jal       x1, mul_modp
  bn.mov    w10, w19

  /* w15 <= w14 * (w17 - w18) = w*(B-h) */
  bn.mov    w24, w14
  bn.subm   w25, w17, w18
  jal       x1, mul_modp
  bn.mov    w15, w19

  /* w15 <= w15 - 2 * (w16 * w16) = w*(B-h) - 2*R^2 = Y1 */
  bn.mov    w24, w16
  bn.mov    w25, w16
  jal       x1, mul_modp
  bn.subm   w15, w15, w19
  bn.subm   w15, w15, w19

  /* The proj_double routine returns (0, 0, 0) when called on the point at
     infinity (any point where Y is nonzero and both X=0 and Z=0). Detect this
     case and select a 1 for Y if all coordinates are 0. */
  bn.addi   w16, w31, 1
  bn.or     w14, w8, w10
  bn.sel    w9, w16, w15, Z

  ret


/**
 * Plain software P-256 scalar multiplication.
 *
 * Computes R = k * P for a single, unmasked 256-bit scalar k.
 *
 * This is the software-profiling baseline:
 *   - no scalar sharing
 *   - no scalar reblinding
 *   - no randomized projective coordinates
 *   - no fault-injection checks
 *
 * The loop is still fixed-length (256 rounds) and uses a select instead of a
 * secret-dependent branch, so the control-flow length is independent of k.
 *
 * Inputs:
 *   x21       pointer to affine x-coordinate of P in DMEM
 *   x22       pointer to affine y-coordinate of P in DMEM
 *   w0        256-bit scalar k
 *   w31       all-zero
 *
 * Outputs:
 *   w8,w9,w10 projective coordinates of R = kP
 *
 * Preserved for the loop:
 *   w1        affine x-coordinate of P
 *   w2        affine y-coordinate of P
 *
 * Clobbered:
 *   x2, x3, w0, w3-w29
 */
scalar_mult_sw:
  /* Set up P-256 field arithmetic:
       MOD <= p
       w28 <= 2^256 mod p
       w29 <= 2^448 mod p */
  jal       x1, setup_modp

  /* Load curve parameter b used by proj_add.
       w27 <= b */
  li        x2, 27
  la        x3, p256_b
  bn.lid    x2, 0(x3)

  /* Load affine input point P once and keep it in w1,w2.
       w1 <= P.x
       w2 <= P.y */
  li        x2, 1
  bn.lid    x2, 0(x21)
  li        x2, 2
  bn.lid    x2, 0(x22)

  /* Q = point at infinity = (0,1,0). */
  bn.mov    w8, w31
  bn.addi   w9, w31, 1
  bn.mov    w10, w31

  /*
   * Fixed 256-round double-and-add-always:
   *
   * for i = 255 .. 0:
   *   Qd = 2Q
   *   Qa = Qd + P
   *   Q  = k[i] ? Qa : Qd
   *
   * w4,w5,w6 preserve Qd while proj_add writes Qa to w11,w12,w13.
   *
   * bn.rshi w7,w31,w0 >> 255 moves the current MSB of k into bit 0
   * of w7. bn.or then updates the L flag from that least-significant bit,
   * which bn.sel uses as the selection condition.
   */
  loopi     256, 14
    /* Qd = 2Q. */
    jal       x1, proj_double

    /* Preserve Qd. */
    bn.mov    w4, w8
    bn.mov    w5, w9
    bn.mov    w6, w10

    /* P in projective coordinates is simply (Px, Py, 1). */
    bn.mov    w11, w1
    bn.mov    w12, w2
    bn.addi   w13, w31, 1

    /* Qa = Qd + P. Result is returned in w11,w12,w13. */
    jal       x1, proj_add

    /* Extract current scalar MSB into the L flag. */
    bn.rshi   w7, w31, w0 >> 255
    bn.or     w7, w7, w31

    /* Select Qa when k[i]=1, otherwise Qd. */
    bn.sel    w8, w11, w4, L
    bn.sel    w9, w12, w5, L
    bn.sel    w10, w13, w6, L

    /* Shift scalar left by one bit; next bit becomes the MSB. */
    bn.rshi   w0, w0, w31 >> 255

  ret


.section .data

/* P-256 domain parameter b. */
.globl p256_b
.balign 32
p256_b:
  .word 0x27d2604b
  .word 0x3bce3c3e
  .word 0xcc53b0f6
  .word 0x651d06b0
  .word 0x769886bc
  .word 0xb3ebbd55
  .word 0xaa3a93e7
  .word 0x5ac635d8

/* P-256 coordinate-field modulus p. */
.globl p256_p
.balign 32
p256_p:
  .word 0xffffffff
  .word 0xffffffff
  .word 0xffffffff
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000001
  .word 0xffffffff

/* Constant (2^448 mod p), used by mul_modp. */
.globl p256_r448
.balign 32
p256_r448:
  .word 0xffffffff
  .word 0xfffffffe
  .word 0xfffffffe
  .word 0xffffffff
  .word 0x00000000
  .word 0x00000002
  .word 0x00000003
  .word 0x00000000

/* P-256 base point G affine x-coordinate. */
.globl p256_gx
.balign 32
p256_gx:
  .word 0xd898c296
  .word 0xf4a13945
  .word 0x2deb33a0
  .word 0x77037d81
  .word 0x63a440f2
  .word 0xf8bce6e5
  .word 0xe12c4247
  .word 0x6b17d1f2

/* P-256 base point G affine y-coordinate. */
.globl p256_gy
.balign 32
p256_gy:
  .word 0x37bf51f5
  .word 0xcbb64068
  .word 0x6b315ece
  .word 0x2bce3357
  .word 0x7c0f9e16
  .word 0x8ee7eb4a
  .word 0xfe1a7f9b
  .word 0x4fe342e2
