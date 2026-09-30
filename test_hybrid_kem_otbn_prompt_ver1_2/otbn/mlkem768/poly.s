/* Copyright lowRISC contributors (OpenTitan project). */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */
/*
 * ver1_1 (ML-KEM-768, 官方向量指令实现) —— 多项式基础运算
 * 内核逐字移植自: sw/otbn/crypto/mlkem1024/
 *   官方 poly_add    -> poly_add
 *   官方 poly_sub    -> poly_sub
 *   官方 decode_1    -> poly_frommsg  (ByteDecode_1: bit=1 -> 1665)
 *   官方 compress_1  -> compress_1 (保留原名) + encode_1；
 *                       poly_tomsg = compress_1 + encode_1 (32 字节输出)
 *   官方 expand_prf  -> poly_getnoise_eta_1 / poly_getnoise_eta_2
 *                       (ML-KEM-768 中 eta1 = eta2 = 2，两者共用同一实现)
 * 文件布局沿用 ver0_2/otbn/mlkem768
 *
 * 接口说明: 数据布局为官方 32-bit 系数(1024 B/多项式)，寄存器约定沿用官方。
 */

.globl poly_add
.globl poly_sub
.globl poly_frommsg
.globl poly_tomsg
.globl poly_getnoise_eta_1
.globl poly_getnoise_eta_2
.globl compress_1
.globl encode_1
.text

/**
 * Pointwise Addition of polynomials for ML-KEM-1024.
 *
 * Computes c(X) = a(X) + b(X) mod 3329.
 *
 * @param[in]  x2: DMEM address of polynomial a(X) (256 32-bit words, 1024 bytes).
 * @param[in]  x3: DMEM address of polynomial b(X) (256 32-bit words, 1024 bytes).
 * @param[out] x4: DMEM address of polynomial c(X) (256 32-bit words, 1024 bytes).
 *
 * Clobbered WDRs: w0, w1.
 */
poly_add:
  /* Push clobbered general-purpose registers onto the stack. */
  .irp reg, x2, x3, x4, x10
    sw \reg, 0(x31)
    addi x31, x31, 4
  .endr

  addi x10, x0, 1

  /* Loop 32 iterations (32 * 8 = 256 coefficients). */
  loopi 32, 4
    bn.lid x0, 0(x2++)
    bn.lid x10, 0(x3++)
    bn.addvm.8S w0, w0, w1
    bn.sid x0, 0(x4++)
    /* End of loop */

  /* Restore registers from stack. */
  .irp reg, x10, x4, x3, x2
    addi x31, x31, -4
    lw \reg, 0(x31)
  .endr

  ret

/**
 * Pointwise Subtraction of polynomials for ML-KEM-1024.
 *
 * Computes c(X) = a(X) - b(X) mod 3329.
 *
 * @param[in]  x2: DMEM address of polynomial a(X) (256 32-bit words, 1024 bytes).
 * @param[in]  x3: DMEM address of polynomial b(X) (256 32-bit words, 1024 bytes).
 * @param[out] x4: DMEM address of polynomial c(X) (256 32-bit words, 1024 bytes).
 *
 * Clobbered WDRs: w0, w1.
 */
poly_sub:
  /* Push clobbered general-purpose registers onto the stack. */
  .irp reg, x2, x3, x4, x10
    sw \reg, 0(x31)
    addi x31, x31, 4
  .endr

  addi x10, x0, 1

  /* Loop 32 iterations (32 * 8 = 256 coefficients). */
  loopi 32, 4
    bn.lid x0, 0(x2++)
    bn.lid x10, 0(x3++)
    bn.subvm.8S w0, w0, w1
    bn.sid x0, 0(x4++)
    /* End of loop */

  /* Restore registers from stack. */
  .irp reg, x10, x4, x3, x2
    addi x31, x31, -4
    lw \reg, 0(x31)
  .endr

  ret

/**
 * Decode 32 packed bytes into 256 1-bit polynomial coefficients (ByteDecode_1).
 *
 * Implements Algorithm 6 (ByteDecode_d) of FIPS 203 for d = 1.
 * Unpacks 32-byte binary stream into 256 polynomial coefficients over Z_q:
 *   If bit i == 1 -> f[i] = (q + 1) / 2 = 1665
 *   If bit i == 0 -> f[i] = 0
 *
 * @param[in]  x2: DMEM input address of 32 packed bytes (1 WDR).
 * @param[in]  x3: DMEM output address for 256 32-bit polynomial coefficients (1024 bytes).
 *
 */
poly_frommsg:
  /* Push clobbered registers onto the stack. */
  .irp reg, x2, x3, x4, x5
    sw \reg, 0(x31)
    addi x31, x31, 4
  .endr

  /* Load 1 WDR (32 bytes) into w1. */
  li x4, 1
  bn.lid x4++, 0(x2)

  /* Load constant vector w2 = [1665, 1665, ..., 1665] from DMEM. */
  la x5, _decompress_const_1665
  bn.lid x4, 0(x5)

  /* Unpack 256 1-bit coefficients into 32 256-bit WDRs (1024 bytes) at x3. */
  loopi 32, 7
    loopi 8, 3
      bn.rshi w0, w1, w0 >> 1
      bn.rshi w0, w31, w0 >> 31
      bn.rshi w1, w31, w1 >> 1
      /* End of loop */

    /* Create 0x00000000 / 0xFFFFFFFF mask, and mask with 1665. */
    bn.subv.8s w0, w31, w0
    bn.and w0, w0, w2
    bn.sid x0, 0(x3++)
    /* End of loop */

  /* Restore registers. */
  .irp reg, x5, x4, x3, x2
    addi x31, x31, -4
    lw \reg, 0(x31)
  .endr

  ret

/**
 * Compress 256 coefficients to 1 bit per coefficient in-place (Compress_1).
 *
 * Implements Section 4.2.1 (Compress_d) of FIPS 203 for d = 1.
 * x' = ((x * 2 + 1664) * 1290168 >> 32) mod 2.
 * Note: See compress_11 for details on fixed-point division by 3329 (M = 1290168, mu = 0).
 *
 * @param[in,out]  x2: DMEM address of 256 32-bit polynomial coefficients (1024 bytes).
 *
 */
compress_1:
  /* Push clobbered registers onto the stack. */
  .irp reg, x2, x4, x5
    sw \reg, 0(x31)
    addi x31, x31, 4
  .endr

  /* Setup MOD CSR and w0 with reciprocal constant M = 1290168 and mu = 0. */
  la x5, _compress_recip_m
  bn.lid x0, 0(x5)
  bn.wsrw MOD, w0

  /* Setup w30 = [1664, 1664, ..., 1664] (offset for rounding). */
  li x4, 30
  la x5, _compress_offset_1664
  bn.lid x4, 0(x5)

  /* Setup w29 = [0x1, 0x1, ..., 0x1] (1-bit mask). */
  bn.not w29, w31
  bn.shv.8s w29, w29 >> 31

  li x4, 1

  /* Vectorized loop: process 256 coefficients in 32 iterations (8 per iteration).
     Computes Compress_1(x) = round(x * 2^1 / 3329) mod 2^1 in-place at x2. */
  loopi 32, 6
    bn.lid x4, 0(x2)
    bn.shv.8s w1, w1 << 1
    bn.addv.8s w1, w1, w30
    bn.mulvml.8s w1, w1, w0, 0
    bn.and w1, w1, w29
    bn.sid x4, 0(x2++)
    /* End of loop */

  /* Restore MOD CSR to q = 3329, mu = 0x94570CFF. */
  la x5, _compress_modulus_3329
  bn.lid x0, 0(x5)
  bn.wsrw MOD, w0

  /* Restore GPRs. */
  .irp reg, x5, x4, x2
    addi x31, x31, -4
    lw \reg, 0(x31)
  .endr

  ret


/**
 * ByteEncode_1: pack 256 1-bit coefficients into 32 packed bytes (1 WDR).
 *
 * Implements Algorithm 5 (ByteEncode_d) of FIPS 203 for d = 1.
 * Loop 32 iterations: 256 coefficients -> 32 bytes output.
 *
 * @param[in]  x2: DMEM 输入地址，256 个 32-bit 系数 (1024 B)
 * @param[out] x3: DMEM 输出地址，32 打包字节 (1 WDR)
 */
encode_1:
  /* Push clobbered registers onto the stack. */
  .irp reg, x2, x3, x4
    sw \reg, 0(x31)
    addi x31, x31, 4
  .endr

  loopi 32, 5
    /* Load 8 coefficients into w0. */
    bn.lid x0, 0(x2++)

    loopi 8, 2
      bn.rshi w1, w0, w1 >> 1
      /* Remove the coefficient from w0. */
      bn.rshi w0, w31, w0 >> 32
      /* End of loop */
    nop
    /* End of loop */

  /* Store the 1 encoded WDR (32 bytes) to DMEM at x3. */
  li x4, 1
  bn.sid x4, 0(x3)

  /* Restore registers. */
  .irp reg, x4, x3, x2
    addi x31, x31, -4
    lw \reg, 0(x31)
  .endr

  ret

/**
 * ver0_2 接口名: poly_tomsg —— 多项式压缩为 1 bit/系数并序列化成 32 字节。
 * = compress_1 (原地) + encode_1
 *
 * @param[in]  x2: 输入多项式地址 (1024 B)
 * @param[out] x3: 输出 32 字节消息
 */
poly_tomsg:
  .irp reg, x2, x3
    sw \reg, 0(x31)
    addi x31, x31, 4
  .endr

  jal  x1, compress_1

  jal  x1, encode_1

  .irp reg, x3, x2
    addi x31, x31, -4
    lw \reg, 0(x31)
  .endr

  ret

/**
 * Expand noise polynomial for ML-KEM-1024 using SHAKE256 PRF (ExpandPRF).
 *
 * Implements noise expansion per FIPS 203 Section 4.1 / Algorithm 8 (SamplePolyCBD_eta).
 * Absorbs 33-byte message B = s || N into SHAKE256 hardware XOF (where s is
 * 32 bytes seed and N is 1 byte nonce), squeezes 128 bytes into _expand_buf,
 * and calls sample_cbd_poly.
 *
 * @param[in]  x2: DMEM address of 32-byte seed s (in a 64-byte allocated space).
 * @param[in]  x3: Nonce N (0 <= N <= 255).
 * @param[out] x4: DMEM output address for sampled noise polynomial (256 32-bit words).
 *
 * Clobbered Vector Registers: w0, w29, w30.
 */
poly_getnoise_eta_1:
poly_getnoise_eta_2:
  /* Push clobbered registers onto the stack. */
  .irp reg, x2, x3, x4, x20, x21, x22
    sw \reg, 0(x31)
    addi x31, x31, 4
  .endr

  /* Initialize 32-byte slot at offset 32 to guarantee valid 256-bit DMEM ECC integrity for bn.lid in xof_absorb */
  bn.xor w0, w0, w0
  bn.sid x0, 32(x2)

  /* Append Nonce byte N to seed s at offset 32 */
  addi x21, x2, 0   /* save s address in x21 */
  sw   x3, 32(x21)

  /* Initialize SHAKE256 hardware XOF */
  jal x1, xof_shake256_init

  /* Absorb 33 bytes of s || N */
  addi x20, x0, 33  /* length 33 bytes */
  addi x22, x0, 0   /* unmasked */
  jal  x1, xof_absorb

  /* Finish absorb and process */
  jal x1, xof_process

  /* Squeeze 4 chunks of 32 bytes (128 bytes total) into _expand_buf */
  la   x20, _expand_buf
  loopi 4, 3
    jal  x1, xof_squeeze32
    bn.xor w0, w29, w30
    bn.sid x0, 0(x20++)
    /* End of loop */

  /* Finish XOF session */
  jal x1, xof_finish

  /* Call sample_cbd_poly(x2=_expand_buf, x3=x4) */
  la x2, _expand_buf
  addi x3, x4, 0
  jal x1, cbd2

  /* Restore registers from stack. */
  .irp reg, x22, x21, x20, x4, x3, x2
    addi x31, x31, -4
    lw \reg, 0(x31)
  .endr

  ret
