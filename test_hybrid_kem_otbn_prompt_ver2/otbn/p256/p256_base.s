/* Copyright 2016 The Chromium OS Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE.dcrypto file.
 *
 * Derived from code in
 * https://chromium.googlesource.com/chromiumos/platform/ec/+/refs/heads/cr50_stab/chip/g/dcrypto/dcrypto_p256.c
 */

.globl p256_scalar_mult
.globl p256_masked_scalar_reblind
.globl trigger_fault_if_fg0_z
.globl trigger_fault_if_fg0_not_z
.globl setup_modp

.globl scalar_mult_int
.globl proj_add
.globl proj_to_affine

/* Exposed only for testing or SCA purposes. */
.globl proj_double

.text

/**
 * Trigger a fault if the FG0.Z flag is 1.
 *
 * If the flag is 1, then this routine will trigger an `ILLEGAL_INSN` error and
 * abort the OTBN program. If the flag is 0, the routine will essentially do
 * nothing.
 *
 * NOTE: Be careful when calling this routine that the FG0.Z flag is not
 * sensitive; since aborting the program will be quicker than completing it,
 * the flag's value is likely clearly visible to an attacker through timing.
 *
 * @param[in]  FG0.Z: boolean indicating fault condition when 1
 *
 * clobbered registers: x2, w31
 * clobbered flag groups: none
 */
trigger_fault_if_fg0_not_z:
  /* Read the FG0.Z flag (position 3).
       x2 <= FG0.Z */
  csrrw     x2, FG0, x0
  andi      x2, x2, 8
  addi      x2, x2, 31

  /* The `bn.lid` instruction causes an `ILLEGAL_INSN` error if the index of the
     bignum register (stored in x2 in this case) is invalid. Therefore, if FG0.Z
     is 1, this instruction causes an error, but if FG0.Z is 0 it simply loads
     the word at address 0 into w31. */
  bn.lid    x2, 0(x0)

  /* If we get here, the flag must have been 0. Restore w31 to zero and return.
       w31 <= 0 */
  bn.xor    w31, w31, w31

  ret

/**
 * Trigger a fault if the FG0.Z flag is 0.
 *
 * If the flag is 0, then this routine will trigger an `ILLEGAL_INSN` error and
 * abort the OTBN program. If the flag is 1, the routine will essentially do
 * nothing.
 *
 * NOTE: Be careful when calling this routine that the FG0.Z flag is not
 * sensitive; since aborting the program will be quicker than completing it,
 * the flag's value is likely clearly visible to an attacker through timing.
 *
 * @param[in]  FG0.Z: boolean indicating fault condition when 0
 *
 * clobbered registers: x2, w31
 * clobbered flag groups: none
 */
trigger_fault_if_fg0_z:
  /* Read the FG0.Z flag (position 3).
       x2 <= FG0.Z */
  csrrw     x2, FG0, x0
  andi      x2, x2, 8
  xori      x2, x2, 8
  addi      x2, x2, 31

  /* The `bn.lid` instruction causes an `ILLEGAL_INSN` error if the index of the
     bignum register (stored in x2 in this case) is invalid. Therefore, if FG0.Z
     is 0, this instruction causes an error, but if FG0.Z is 1 it simply loads
     the word at address 0 into w31. */
  bn.lid    x2, 0(x0)

  /* If we get here, the flag must have been 1. Restore w31 to zero and return.
       w31 <= 0 */
  bn.xor    w31, w31, w31

  ret


/**
 * Set up MOD register for P-256 coordinate field operations.
 *
 * Loads the P-256 prime modulus p into the MOD register.
 *
 * Flags: Flags have no meaning beyond the scope of this subroutine.
 *
 * @param[in]  w31: all-zero
 * @param[out] MOD: p, modulus of P-256 underlying finite field
 *
 * clobbered registers: w29
 * clobbered flag groups: FG0
 */
setup_modp:
  /* Load the modulus p from DMEM and store it in MOD.
     MOD <= w29 <= p = dmem[p256_p] */
  li        x2, 29
  la        x3, p256_p
  bn.lid    x2, 0(x3)
  bn.wsrw   MOD, w29
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
  bn.modp256 w14, w11, w8

  /* 2: w15 = t1 <= Y1*Y2 = w12*w9 */
  bn.modp256 w15, w12, w9

  /* 3: w16 = t2 <= Z1*Z2 = w13*w10*/
  bn.modp256 w16, w13, w10

  /* 5: w17 = t4 <= X2+Y2 = w11 + w12 */
  bn.addm   w17, w11, w12

  /* 4: w18 = t3 <= X1+Y1 = w8+w9 */
  bn.addm   w18, w8, w9

  /* 6: w19 = t3 <= t3*t4 = w18*w17 */
  bn.modp256 w19, w17, w18

  /* 7: w18 = t4 <= t0+t1 = w14+w15 */
  bn.addm   w18, w14, w15

  /* 8: w17 = t3 <= t3 - t4 = w19 - w18 */
  bn.subm   w17, w19, w18

  /* 10: w18 = X3 <= Y2 + Z2 = w12 + w13 */
  bn.addm   w18, w12, w13

  /* 9: w19 = t4 <= Y1 + Z1 = w9 + w10 */
  bn.addm   w19, w9, w10

  /* 11: w18 = t4 <= t4 * X3 = w19 * w18 */
  bn.modp256 w18, w18, w19

  /* 12: w19 = X3 <= t1 + t2 = w15 + w16 */
  bn.addm   w19, w15, w16

  /* 13: w18 = t4 <= t4 - X3 = w18 + w19 */
  bn.subm   w18, w18, w19

  /* 15: w19 = Y3 <= X2 + Z2 = w11 + w13 */
  bn.addm   w19, w11, w13

  /* 14: w12 = X3 <= X1 + Z1 = w8 + w10 */
  bn.addm   w12, w8, w10

  /* 16: w11 = X3 <= X3 * Y3 = w12 * w19 */
  bn.modp256 w11, w19, w12

  /* 17: w12 = Y3 <= t0 + t2 = w14 + w16 */
  bn.addm   w12, w14, w16

  /* 18: w12 = Y3 <= X3 - Y3 = w11 - w12 */
  bn.subm   w12, w11, w12

  /* 19: w19 = Z3 <= b * t2 =  w27 * w16 */
  bn.modp256 w19, w27, w16

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
  bn.modp256 w19, w27, w12

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
  bn.modp256 w15, w18, w12

  /* 36: w16 = t2 <= t0 * Y3 = w14 * w12 */
  bn.modp256 w16, w14, w12

  /* 37: w12 = Y3 <= X3 * Z3 = w11 * w13 */
  bn.modp256 w19, w11, w13

  /* 38: w12 = Y3 <= Y3 + t2 = w19 + w16 */
  bn.addm   w12, w19, w16

  /* 39: w19 = X3 <= t3 * X3 = w17 * w11 */
  bn.modp256 w19, w17, w11

  /* 40: w11 = X3 <= X3 - t1 = w19 - w15 */
  bn.subm   w11, w19, w15

  /* 41: w13 = Z3 <= t4 * Z3 = w18 * w13 */
  bn.modp256 w13, w18, w13

  /* 42: w19 = t1 <= t3 * t0 = w17 * w14 */
  bn.modp256 w19, w17, w14

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
  bn.modp256 w19, w10, w10

  /* w12 <= z^3 = x2 */
  bn.modp256 w19, w19, w10
  bn.mov    w12, w19

  /* w19 <= z^6 */
   bn.modp256 w19, w19, w19

  /* w13 <= z^7 = z^(2^3 - 1) = x3 */
  bn.modp256 w19, w19, w10
  bn.mov    w13, w19

  /* w14 <= z^(2^6 - 1) = x6 */
  loopi     3, 1
    bn.modp256 w19, w19, w19      
  bn.modp256 w19, w19, w13        
  bn.mov    w14, w19

  /* w15 <= z^(2^12 - 1) = x12 */
  loopi     6, 1
    bn.modp256 w19, w19, w19  
  bn.modp256 w19, w19, w14    
  bn.mov    w15, w19

  /* w16 <= z^(2^15 - 1) = x15 */
  loopi     3, 1
    bn.modp256 w19, w19, w19  
  bn.modp256 w19, w19, w13  
  bn.mov    w16, w19

  /* w17 <= z^(2^30 - 1) = x30 */
  loopi     15, 1
    bn.modp256 w19, w19, w19  
  bn.modp256 w19, w19, w16  
  bn.mov    w17, w19

  /* w18 <= z^(2^32 - 1) = x32 */
  loopi     2, 1
    bn.modp256 w19, w19, w19 
  bn.modp256 w19, w19, w12 
  bn.mov    w18, w19

  /* w19 <= z^(2^64 - 2^32 + 1) */
  loopi     32, 1
    bn.modp256 w19, w19, w19 
  bn.modp256 w19, w19, w10 

  /* w19 <= z^(2^192 - 2^160 + 2^128 + 2^32 - 1) */
  loopi     128, 1
    bn.modp256 w19, w19, w19 
  bn.modp256 w19, w19, w18 

  /* w19 <= z^(2^224 - 2^192 + 2^160 + 2^64 + 1) */
  loopi     32, 1
    bn.modp256 w19, w19, w19 
  bn.modp256 w19, w19, w18 

  /* w19 <= z^(2^254 - 2^222 + 2^190 + 2^94 - 1) */
  loopi     30, 1
    bn.modp256 w19, w19, w19 
  bn.modp256 w19, w19, w17

  /* w14 <= z^(2^256 - 2^224 + 2^192 + 2^96 - 2^2 + 1) = z^(p-2) */
  loopi     2, 1
    bn.modp256 w19, w19, w19 
  bn.modp256 w14, w19, w10

  /* convert x-coordinate to affine
     w11 = x_a = x/z = x * z^(-1) = w8 * w14 */
  bn.modp256 w11, w8, w14

  /* convert y-coordinate to affine
     w12 = y_a = y/z = y * z^(-1) = w9 * w14 */
  bn.modp256 w12, w9, w14

  ret



/**
 * Fetch curve point from dmem and randomize z-coordinate
 *
 * returns P = (x, y, z) = (x_a*z, y_a*z, z)
 *         with P being a valid P-256 curve point in projective coordinates
 *              x_a and y_a being the affine coordinates as fetched from dmem
 *              z being a randomized z-coordinate
 *
 * This routines fetches the affine x- and y-coordinates of a curve point from
 * dmem and computes a valid set of projective coordinates. The z-coordinate is
 * randomized and x and y are scaled appropriately.
 * This routine runs in constant time.
 *
 * @param[in]  x10: constant 24
 * @param[in]  x21: dptr_x, pointer to dmem location containing affine
 *                          x-coordinate of input point
 * @param[in]  x22: dptr_y, pointer to dmem location containing affine
 *                          y-coordinate of input point
 * @param[in]  w31: all-zero
 * @param[in]  MOD: p, modulus of P-256 underlying finite field
 * @param[out] w14: x, projective x-coordinate
 * @param[out] w15: y, projective y-coordinate
 * @param[out] w16: z, random projective z-coordinate
 *
 * Flags: When leaving this subroutine, the M, L and Z flags of FG0 depend on
 *        the scaled projective y-coordinate.
 *
 * clobbered registers: w14 to w16, w19 to w26
 * clobbered flag groups: FG0
 */
fetch_proj_randomize:

  /* get random number from URND */
  bn.wsrr   w16, URND

  /* reduce random number
     w16 = z <= w16 mod p */
  bn.addm   w16, w16, w31

  /* fetch x-coordinate from dmem
     w24 = x_a <= dmem[x22] = dmem[dptr_x] */
  bn.lid    x10, 0(x21)

  /* scale x-coordinate
     w14 = x <= w24*w16 = x_a*z  mod p */
  bn.modp256 w14, w24, w16

  /* fetch y-coordinate from dmem
     w24 = y_a <= dmem[x22] = dmem[dptr_y] */
  bn.lid    x10, 0(x22)

  /* scale y-coordinate
     w15 = y <= w24*w16 = y_a*z  mod p */
  bn.modp256 w15, w24, w16

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
  bn.modp256 w19, w24, w25
  bn.addm   w14, w19, w19
  bn.addm   w14, w14, w19

  /* w15 <= 2 * w9 * w10 = 2 * Y1 * Z1 = s */
  bn.modp256 w19, w9, w10
  bn.addm   w15, w19, w19

  /* w16 <= w9 * w15 = Y1 * s = R */
  bn.modp256 w16, w9, w15

  /* w17 <= 2 * w8 * w16 = 2 * X1 * R = B */
  bn.modp256 w19, w8, w16
  bn.addm   w17, w19, w19

  /* w18 <= w14^2 - 2*w17 = w^2 - 2*B = h */
  bn.modp256 w19, w14, w14
  bn.subm   w18, w19, w17
  bn.subm   w18, w18, w17

  /* w8 <= w18 * w15 = h * s = X1 */
  bn.modp256 w8, w18, w15

  /* w10 <= w15 * w15 * w15 = s * s * s = sss  = Z1 */
  bn.modp256 w19, w15, w15
  bn.modp256 w10, w19, w15

  /* w15 <= w14 * (w17 - w18) = w*(B-h) */
  bn.subm   w25, w17, w18
  bn.modp256 w15, w14, w25

  /* w15 <= w15 - 2 * (w16 * w16) = w*(B-h) - 2*R^2 = Y1 */
  bn.modp256 w19, w16, w16
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
 * P-256 scalar point multiplication in affine space
 *
 * returns R = k*P = k*(x_p, y_p)
 *         with R, P being valid P-256 curve points in affine coordinates
 *              k being a 256 bit scalar
 *
 * This routine performs scalar multiplication based on the group laws
 * of Weierstrass curves.
 * A constant time double-and-add algorithm (sometimes referred to as
 * double-and-add-always) is used.
 * Due to the P-256 optimized implementations of the called routines for
 * point addition and doubling, this routine is limited to P-256.
 *
 * The routine receives the scalar in two shares k0, k1 such that
 *   k = (k0 + k1) mod n
 * The loop operates on both shares in parallel, computing (k0 + k1) * P as
 * follows:
 *  Q = (0, 1, 0) # origin
 *  for i in 319..0:
 *    Q = 2 * Q
 *    A = if (k0[i] ^ k1[i]) then P else 2P
 *    B = Q + A
 *    Q = if (k0[i] | k1[i]) then B else Q
 *
 *
 * Each share k0/k1 is 321 bits, even though it represents a 256-bit value.
 * This allows for blinded scalars as a side-channel protection measure.
 *
 * 321 bit shares mean that we have 65 bits of blinding for each share. This
 * is the minimal number of bits to protect against window attacks mentioned
 * in Schindler.
 * https://csrc.nist.gov/csrc/media/events/workshop-on-elliptic-curve-cryptography-standards/documents/papers/session6-schindler-werner.pdf
 *
 * @param[in]  x21: dptr_x, pointer to affine x-coordinate in dmem
 * @param[in]  x22: dptr_y, pointer to affine y-coordinate in dmem
 * @param[in]  w0: lower 256 bits of k0, first share of scalar
 * @param[in]  w1: upper 65 bits of k0, first share of scalar
 * @param[in]  w2: lower 256 bits of k1, second share of scalar
 * @param[in]  w3: upper 65 bits of k1, second share of scalar
 * @param[in]  w27: b, curve domain parameter
 * @param[in]  w31: all-zero
 * @param[in]  MOD: p, modulus, 2^256 > p > 2^255.
 * @param[out]  w8: x, x-coordinate of curve point (projective)
 * @param[out]  w9: y, y-coordinate of curve point (projective)
 * @param[out]  w10: z, z-coordinate of curve point (projective)
 *
 * Flags: When leaving this subroutine, the M, L and Z flags of FG0 depend on
 *        the computed affine y-coordinate.
 *
 * clobbered registers: x2, x3, x10, w0 to w30
 * clobbered flag groups: FG0
 */
scalar_mult_int:
  /* Set up MOD for coordinate arithmetic.
       MOD <= p */
  jal       x1, setup_modp

  /* load domain parameter b from dmem
     w27 <= b = dmem[p256_b] */
  li        x2, 27
  la        x3, p256_b
  bn.lid    x2, 0(x3)

  /* get randomized projective coodinates of curve point
     P = (x_p, y_p, z_p) = (w8, w9, w10) = (w14, w15, w16) =
     (x*z mod p, y*z mod p, z) */
  li        x10, 24
  jal       x1, fetch_proj_randomize
  bn.mov    w8, w14
  bn.mov    w9, w15
  bn.mov    w10, w16

  /* Init 2P, this will be used for the addition part in the double-and-add
     loop when the bit at the current index is 1 for both shares of the scalar.
     2P = (w4, w5, w6) <= (w8, w8, w10) <= 2*(w8, w9, w10) = 2*P */
  jal       x1, proj_double
  bn.mov    w4, w8
  bn.mov    w5, w9
  bn.mov    w6, w10

  /* Shift first share of k so its MSB is in the most significant position of
     a word.

     N.B. This has been intentionally separated from accesses to [w2,w3] below
     to avoid potential transient side channel leakage from accessing k0 and k1
     in sequential instructions.

     w0,w1 <= [w0, w1] << 191 = k0 << 191 */
  bn.wsrr   w20, URND
  bn.rshi   w20, w1,  w20 >> 65
  bn.rshi   w1,  w20, w20 >> 191
  bn.rshi   w1,  w1,  w0 >> 65
  bn.wsrr   w20, URND
  bn.rshi   w0,  w0,  w20 >> 65

  /* init double-and-add with point in infinity
     Q = (w8, w9, w10) <= (0, 1, 0) */
  bn.mov    w8, w31
  bn.addi   w9, w31, 1
  bn.mov    w10, w31

  /* Shift second share of k so its MSB is in the most significant position of a
     word as well.

     w2,w3 <= [w2, w3] << 191 = k1 << 191 */
  bn.wsrr   w20, URND
  bn.rshi   w20, w3,  w20 >> 65
  bn.rshi   w3,  w20, w20 >> 191
  bn.rshi   w3,  w3,  w2 >> 65
  bn.wsrr   w20, URND
  bn.rshi   w2,  w2,  w20 >> 65

  /* double-and-add loop with decreasing index */
  loopi     321, 54

    /* double point Q
       Q = (w8, w9, w10) <= 2*(w8, w9, w10) = 2*Q */
    jal       x1, proj_double

    /* prepare a mostly-randomized word with LSb matching the MSb of k0 for
       performing a MSb check on k0 and k1 after the following call. */
    bn.wsrr   w20, URND
    bn.rshi   w7, w20, w1 >> 255

    /* re-fetch and randomize P again
       P = (w14, w15, w16) */
    jal       x1, fetch_proj_randomize

    /* probe if MSb of either of the two scalars (k0 or k1) but not both is 1.
       - If only one MSb is set, select P for addition
       - If both MSbs are set, select 2P for addition
       - If neither MSB is set, also 2P will be selected but this will be
         discarded later

       w26 <= MSb(k1) */
    bn.wsrr   w20, URND
    bn.rshi   w26, w20, w3 >> 255

    /* N.B. The L bit here is secret. For side channel protection in the
       selects below, it is vital that neither option is equal to the
       destination register (e.g. bn.sel w0, w0, w1). In this case, the
       hamming distance from the destination's previous value to its new value
       will be 0 in one of the cases and potentially reveal L.

       The select itself is split in two shares, i.e., if L = L0 xor L1, then
       L ? a : b = L1 ? (L0 ? b : a) : (L0 ? a : b).
       Thus, we calculate a select over L0 (the LSB of w7) and over L1 (the LSB of w26).

       P = (w11, w12, w13)
        <= (w0[255] xor w1[255])?P=(w14, w15, w16):2P=(w4, w5, w6) */

    /* init regs with random numbers from URND */
    bn.wsrr   w20, URND
    bn.wsrr   w21, URND
    bn.wsrr   w22, URND

    /* (L0 ? a : b) */
    bn.or     w7, w7, w31
    bn.sel    w20, w14, w4, L
    bn.sel    w21, w15, w5, L
    bn.sel    w22, w16, w6, L

    /* init regs with random numbers from URND */
    bn.wsrr   w23, URND
    bn.wsrr   w24, URND
    bn.wsrr   w25, URND

    /* (L0 ? b : a) */
    bn.sel    w23, w4, w14, L
    bn.sel    w24, w5, w15, L
    bn.sel    w25, w6, w16, L

    /* init regs with random numbers from URND */
    bn.wsrr   w11, URND
    bn.wsrr   w12, URND
    bn.wsrr   w13, URND

    /* wipe the L flag */
    bn.or     w12, w12, w31

    /* L1 ? (L0 ? b : a) : (L0 ? a : b) */
    bn.or     w26, w26, w31
    bn.sel    w11, w23, w20, L
    bn.sel    w12, w24, w21, L
    bn.sel    w13, w25, w22, L

    /* add points
       Q+P = (w11, w12, w13) <= (w11, w12, w13) + (w8, w9, w10) */
    jal       x1, proj_add

    /* probe if MSb of either one or both of the two
       scalars (k0 or k1) is 1.*/

    /* duplicate point P to allow distinct source/destination registers for
       the select instructions below.
       Q = (w20, w21, w22) <= (w8, w9, w10) */
    bn.mov    w20, w8
    bn.mov    w21, w9
    bn.mov    w22, w10

    /* init destination registers with random numbers from URND */
    bn.wsrr   w23, URND
    bn.wsrr   w24, URND
    bn.wsrr   w25, URND

    /* N.B. The select instructions below must use distinct
       source/destination registers and source and destination must not be
       equal for any source and destination pair to avoid revealing L.

       The select is split in two shares, i.e., if L = L0 or L1, then
       L ? a : b = L0 ? a : (L1 ? a : b). Thus, we calculate a select
       over L0 (the LSB of w7) and over L1 (the LSB of w26).

       Select doubling result (Q) or addition result (Q+P)
         Q = w0[255] or w1[255]?Q+P=(w11, w12, w13):Q=(w20, w21, w22) */
    bn.or     w7, w7, w31
    bn.sel    w23, w11, w20, L
    bn.sel    w24, w12, w21, L
    bn.sel    w25, w13, w22, L

    /* init destination registers with random numbers from URND */
    bn.wsrr   w8, URND
    bn.wsrr   w9, URND
    bn.wsrr   w10, URND

    /* wipe the L flag */
    bn.or     w10, w10, w31

    bn.or     w26, w26, w31
    bn.sel    w8, w11, w23, L
    bn.sel    w9, w12, w24, L
    bn.sel    w10, w13, w25, L

    /* Load random to pad the shift and re-randomize the coordinates of Q. */
    bn.wsrr   w7, URND

    /* Shift k0 left 1 bit.

     N.B. This has been intentionally separated from accesses to [w2,w3] below
     to avoid potential transient side channel leakage from accessing k0 and k1
     in sequential instructions. */
    bn.rshi   w1, w1, w0 >> 255
    bn.rshi   w0, w0, w7 >> 255

    /* w4 = w4 * w7 */
    bn.modp256 w4, w4, w7

    /* w5 = w5 * w7 */
    bn.modp256 w5, w5, w7

    /* w6 = w6 * w7 */
    bn.modp256 w6, w6, w7

    /* Shift k1 left 1 bit. */
    bn.rshi   w3, w3, w2 >> 255
    bn.rshi   w2, w2, w7 >> 255

  /* Check if the z-coordinate of Q is 0. If so, fail; this represents the
     point at infinity and means the scalar was zero mod n, which likely
     indicates a fault attack. Tail-call.

     FG0.Z <= if (w10 == 0) then 1 else 0 */
  bn.cmp    w10, w31
  jal       x0, trigger_fault_if_fg0_not_z

/**
 * Routine to hide a masked scalar.
 *
 * Adds a multiple of the curve order n to both shares of the
 * secret scalar d.
 *
 * For each share s a 65 bit random number r is generated and added
 * to the s as follows:
 *
 * s = (s + r * n) mod (n << 65)
 *
 * @param[in]           w31: all-zero
 * @param[in,out]  [w1, w0]: first share of scalar d (321 bits)
 * @param[in,out]  [w3, w2]: first share of scalar d (321 bits)
 *
 * clobbered registers: x10-x11, w0-w5, w19-w23
 * clobbered flag groups: FG0
 */
p256_masked_scalar_reblind:
  /* Initialize all-zero register. */
  bn.xor    w31, w31, w31

  /* Hide first share of scalar d in [w1, w0]. */
  bn.mov w4, w0
  bn.mov w5, w1
  jal    x1, p256_scalar_reblind
  bn.mov w0, w20
  bn.mov w1, w21

  /* Clear w4 and w5 which contain the first share of scalar d. */
  bn.xor w4, w4, w4
  bn.xor w5, w5, w5

  /* Hide second share of scalar d in [w3, w2]. */
  bn.mov w4, w2
  bn.mov w5, w3
  jal    x1, p256_scalar_reblind
  bn.mov w2, w20
  bn.mov w3, w21

  /* Clear w4 and w5 which contain the second share of scalar d. */
  bn.xor w4, w4, w4
  bn.xor w5, w5, w5

  ret

/**
 * Helper routine to hide a scalar.
 *
 * Adds a multiple of the curve order n to the secret scalar d.
 *
 * A 65 bit random number r is generated and added
 * to d as follows:
 *
 * d = (d + r * n) mod (n << 65)
 *
 * @param[in]         w31: all-zero
 * @param[in]    [w5, w4]: scalar d (321 bits)
 * @param[out] [w21, w20]: hidden scalar d (321 bits)
 *
 * clobbered registers: x10-x11, w19-w23
 * clobbered flag groups: FG0
 */
p256_scalar_reblind:

  /* Zero out multiplication registers. */
  bn.xor w22, w22, w22
  bn.xor w23, w23, w23

  /* Get a fresh 65-bit random value r from URND.
       w20 = URND() */
  bn.wsrr   w20, URND
  bn.rshi   w20, w31, w20 >> 191

  /* Load curve order n from DMEM.
       w19 <= dmem[p256_n] = n */
  la        x10, p256_n
  li        x11, 19
  bn.lid    x11, 0(x10)

  /* [w23,w22] <= m = r * n */
  bn.mulqacc.z          w20.0, w19.0,  0
  bn.mulqacc            w20.1, w19.0, 64
  bn.mulqacc.so  w22.L, w20.0, w19.1, 64
  bn.mulqacc            w20.1, w19.1,  0
  bn.mulqacc            w20.0, w19.2,  0
  bn.mulqacc            w20.1, w19.2, 64
  bn.mulqacc.so  w22.U, w20.0, w19.3, 64
  bn.mulqacc.so  w23.L, w20.1, w19.3,  0

  /* [w21,w20] <= d + m */
  bn.add    w20, w4, w22
  bn.addc   w21, w5, w23
  bn.sub    w31, w31, w31  /* dummy instruction to clear flags */

  /* [w22,w23] <= n << 65 */
  bn.rshi   w22, w19, w31 >> 191
  bn.rshi   w23, w31, w19 >> 191

  /* Reduce d + m modulo (n << 65) with a conditional subtraction.
       [w20,w21] <= d + m mod (n << 65) */
  bn.sub    w22, w20, w22
  bn.subb   w23, w21, w23
  bn.sel    w20, w20, w22, FG0.C
  bn.sel    w21, w21, w23, FG0.C
  bn.sub    w31, w31, w31  /* dummy instruction to clear flags */

  ret

.section .data

/* P-256 domain parameter b */
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

/* P-256 domain parameter p (modulus) */
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

/* P-256 domain parameter n (order of base point) */
.globl p256_n
.balign 32
p256_n:
  .word 0xfc632551
  .word 0xf3b9cac2
  .word 0xa7179e84
  .word 0xbce6faad
  .word 0xffffffff
  .word 0xffffffff
  .word 0x00000000
  .word 0xffffffff