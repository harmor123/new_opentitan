/* Copyright lowRISC contributors (OpenTitan project). */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */
/*
 * ver1_1 (ML-KEM-768, 官方向量指令实现)
 * 内核逐字移植自: sw/otbn/crypto/mlkem1024/mlkem1024_sample.s
 *   官方 sample_cbd_poly -> 本文件 cbd2 (eta = 2)
 * 文件布局沿用 ver0_2/otbn/mlkem768
 */

.globl cbd2
.text

/**
 * Centered Binomial Distribution sampling for noise polynomials (SamplePolyCBD_eta).
 *
 * Implements Algorithm 8 (SamplePolyCBD_eta) of FIPS 203 for eta = 2.
 * Samples 256 noise coefficients from 128 bytes (1024 bits) of PRF stream.
 *
 * For each coefficient i in 0..255:
 *   a = b[4i] + b[4i+1]
 *   b_val = b[4i+2] + b[4i+3]
 *   coeff[i] = (a - b_val) mod 3329
 *
 * @param[in]  x2: DMEM address of 128 PRF bytes (32 32-bit words).
 * @param[out] x3: DMEM output address for sampled polynomial (256 32-bit words, 1024 bytes).
 *
 */
cbd2:
  /* Push clobbered registers onto the stack. */
  .irp reg, x2, x3, x4, x5, x6, x7, x10, x11, x12, x13
    sw \reg, 0(x31)
    addi x31, x31, 4
  .endr

  li   x4, 3329      /* Modulus q = 3329 */
  li   x10, 0x11111111
  li   x11, 0x22222222

  loopi 32, 23
    lw   x5, 0(x2)     /* Load 32-bit word (4 bytes = 8 coefficients) */
    addi x2, x2, 4

    /* Parallel computation of (b0 + b1 + 2 - b2 - b3) for 8 nibbles: */
    and  x12, x5, x10
    srli x6, x5, 1
    and  x13, x6, x10
    add  x12, x12, x13
    add  x12, x12, x11
    srli x6, x5, 2
    and  x13, x6, x10
    srli x6, x5, 3
    and  x6, x6, x10
    add  x13, x13, x6
    sub  x12, x12, x13

    /* Unpack and store 8 coefficients */
    loopi 8, 8
      andi x6, x12, 7
      srli x12, x12, 4
      addi x6, x6, -2
      srai x7, x6, 31
      and  x7, x7, x4
      add  x6, x6, x7
      sw   x6, 0(x3)
      addi x3, x3, 4
      /* End of inner loop */
    nop
    /* End of outer loop */

  /* Restore registers from stack. */
  .irp reg, x13, x12, x11, x10, x7, x6, x5, x4, x3, x2
    addi x31, x31, -4
    lw \reg, 0(x31)
  .endr

  ret
