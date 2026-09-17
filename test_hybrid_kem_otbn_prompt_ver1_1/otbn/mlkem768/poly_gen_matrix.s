/* Copyright lowRISC contributors (OpenTitan project). */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */
/*
 * ver1_1 (ML-KEM-768, 官方向量指令实现)
 * 内核逐字移植自: sw/otbn/crypto/mlkem1024/mlkem1024_expand.s (expand_a)
 *                 sw/otbn/crypto/mlkem1024/mlkem1024_sample.s (sample_ntt_poly)
 *   官方 expand_a        -> 本文件 poly_gen_matrix (SHAKE128 absorb + squeeze + 拒绝采样)
 *   官方 sample_ntt_poly -> 本文件内部例程(由 poly_gen_matrix 调用)
 * 文件布局沿用 ver0_2/otbn/mlkem768
 */

.globl poly_gen_matrix
.text
/**
 * Expand matrix polynomial entry A[i][j] for ML-KEM-1024 using SHAKE128 XOF.
 *
 * Implements matrix expansion A[i][j] for ML-KEM-1024 per FIPS 203 Section 5.1 / Algorithm 7.
 * Absorbs 34-byte message B = rho || j || i into SHAKE128 hardware XOF (where
 * rho is 32 bytes, j is 1 byte column index, and i is 1 byte row index),
 * squeezes 672 bytes into _expand_buf, and calls sample_ntt_poly to sample 256 coefficients mod 3329.
 *
 * @param[in]  x2: DMEM address of 32-byte seed rho (in a 64-byte allocated space).
 * @param[in]  x3: Column index j (0 <= j <= 3).
 * @param[in]  x4: Row index i (0 <= i <= 3).
 * @param[out] x5: DMEM output address for sampled matrix polynomial (256 32-bit words).
 *
 * Clobbered Vector Registers: w0, w29, w30.
 */
poly_gen_matrix:
  /* Push clobbered registers onto the stack. */
  .irp reg, x2, x3, x4, x5, x20, x21, x22
    sw \reg, 0(x31)
    addi x31, x31, 4
  .endr

  /* Copy 32-byte rho from x2 to _expand_buf and append j||i at offset 32 */
  la   x21, _expand_buf
  bn.lid x0, 0(x2)
  bn.sid x0, 0(x21)
  bn.xor w0, w0, w0
  bn.sid x0, 32(x21)
  slli x20, x4, 8
  add  x20, x20, x3
  sw   x20, 32(x21)

  /* Initialize SHAKE128 hardware XOF */
  jal x1, xof_shake128_init

  /* Absorb 34 bytes of rho || j || i */
  addi x20, x0, 34  /* length 34 bytes */
  addi x22, x0, 0   /* unmasked */
  jal  x1, xof_absorb

  /* Finish absorb and process */
  jal x1, xof_process

  /* Squeeze 21 chunks of 32 bytes (672 bytes total) into _expand_buf */
  la   x20, _expand_buf
  loopi 21, 3
    jal  x1, xof_squeeze32
    bn.xor w0, w29, w30
    bn.sid x0, 0(x20++)
    /* End of loop */

  /* Finish XOF session */
  jal x1, xof_finish

  /* Call sample_ntt_poly(x2=_expand_buf, x3=x5) */
  la x2, _expand_buf
  addi x3, x5, 0
  jal x1, sample_ntt_poly

  /* Restore registers from stack. */
  .irp reg, x22, x21, x20, x5, x4, x3, x2
    addi x31, x31, -4
    lw \reg, 0(x31)
  .endr

  ret

/**
 * Rejection sampling for uniform polynomial coefficients modulo q = 3329 (SampleNTT).
 *
 * Implements Algorithm 7 (SampleNTT) of FIPS 203. Parses a byte stream B into
 * 3-byte groups [b0, b1, b2] and extracts two 12-bit candidate integers:
 *   d1 = b0 + 256 * (b1 & 0x0F)
 *   d2 = (b1 >> 4) + 16 * b2
 *
 * Candidates < 3329 are accepted as valid polynomial coefficients in the NTT domain.
 * Repeats parsing until 256 coefficients are collected.
 *
 * @param[in]  x2: DMEM address of byte stream input.
 * @param[out] x3: DMEM output address for sampled polynomial (256 32-bit words, 1024 bytes).
 *
 */
sample_ntt_poly:
  /* Push clobbered registers onto the stack. */
  .irp reg, x2, x3, x4, x5, x6, x7, x8, x9, x11, x13
    sw \reg, 0(x31)
    addi x31, x31, 4
  .endr

  li   x4, 3329      /* Modulus q = 3329 */
  li   x5, 256       /* Remaining coefficient count (256 to 0) */
  li   x13, 0xFFF    /* 12-bit mask (4095) */

_sample_ntt_loop:
  /* Load 12 bytes (3 words) from DMEM input stream. */
  lw   x6, 0(x2)     /* W0 */
  lw   x7, 4(x2)     /* W1 */
  lw   x8, 8(x2)     /* W2 */
  addi x2, x2, 12

  /* Group 0: W0 */
  /* Candidate 0: W0 & 0xFFF */
  and  x9, x6, x13
  sub  x11, x9, x4
  srli x11, x11, 31
  beq  x11, x0, 1f
  sw   x9, 0(x3)
  addi x3, x3, 4
  addi x5, x5, -1
  beq  x5, x0, _sample_ntt_done
1:

  /* Candidate 1: (W0 >> 12) & 0xFFF */
  srli x9, x6, 12
  and  x9, x9, x13
  sub  x11, x9, x4
  srli x11, x11, 31
  beq  x11, x0, 2f
  sw   x9, 0(x3)
  addi x3, x3, 4
  addi x5, x5, -1
  beq  x5, x0, _sample_ntt_done
2:

  /* Candidate 2: (W0 >> 24) | (W1 << 8) & 0xFFF */
  srli x9, x6, 24
  slli x11, x7, 8
  or   x9, x9, x11
  and  x9, x9, x13
  sub  x11, x9, x4
  srli x11, x11, 31
  beq  x11, x0, 3f
  sw   x9, 0(x3)
  addi x3, x3, 4
  addi x5, x5, -1
  beq  x5, x0, _sample_ntt_done
3:

  /* Candidate 3: (W1 >> 4) & 0xFFF */
  srli x9, x7, 4
  and  x9, x9, x13
  sub  x11, x9, x4
  srli x11, x11, 31
  beq  x11, x0, 4f
  sw   x9, 0(x3)
  addi x3, x3, 4
  addi x5, x5, -1
  beq  x5, x0, _sample_ntt_done
4:

  /* Candidate 4: (W1 >> 16) & 0xFFF */
  srli x9, x7, 16
  and  x9, x9, x13
  sub  x11, x9, x4
  srli x11, x11, 31
  beq  x11, x0, 5f
  sw   x9, 0(x3)
  addi x3, x3, 4
  addi x5, x5, -1
  beq  x5, x0, _sample_ntt_done
5:

  /* Candidate 5: (W1 >> 28) | (W2 << 4) & 0xFFF */
  srli x9, x7, 28
  slli x11, x8, 4
  or   x9, x9, x11
  and  x9, x9, x13
  sub  x11, x9, x4
  srli x11, x11, 31
  beq  x11, x0, 6f
  sw   x9, 0(x3)
  addi x3, x3, 4
  addi x5, x5, -1
  beq  x5, x0, _sample_ntt_done
6:

  /* Candidate 6: (W2 >> 8) & 0xFFF */
  srli x9, x8, 8
  and  x9, x9, x13
  sub  x11, x9, x4
  srli x11, x11, 31
  beq  x11, x0, 7f
  sw   x9, 0(x3)
  addi x3, x3, 4
  addi x5, x5, -1
  beq  x5, x0, _sample_ntt_done
7:

  /* Candidate 7: (W2 >> 20) & 0xFFF */
  srli x9, x8, 20
  and  x9, x9, x13
  sub  x11, x9, x4
  srli x11, x11, 31
  beq  x11, x0, 8f
  sw   x9, 0(x3)
  addi x3, x3, 4
  addi x5, x5, -1
  beq  x5, x0, _sample_ntt_done
8:

  jal  x0, _sample_ntt_loop

_sample_ntt_done:
  /* Restore registers from stack. */
  .irp reg, x13, x11, x9, x8, x7, x6, x5, x4, x3, x2
    addi x31, x31, -4
    lw \reg, 0(x31)
  .endr

  ret
