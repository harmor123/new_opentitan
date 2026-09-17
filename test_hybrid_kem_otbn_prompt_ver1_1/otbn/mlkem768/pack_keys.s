/* Copyright lowRISC contributors (OpenTitan project). */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */
/*
 * ver1_1 (ML-KEM-768, 官方向量指令实现) —— 公钥/私钥的序列化
 * 内核逐字移植自: sw/otbn/crypto/mlkem1024/
 *   官方 encode_12 -> poly_tobytes   (单多项式 -> 384 字节)
 *   官方 decode_12 -> poly_frombytes (384 字节 -> 单多项式)
 * pack_pk / pack_sk / unpack_pk / unpack_sk 为 ver0_2 接口的包装函数(本文件新写),
 * 按 ML-KEM-768 尺寸(k = 3)拼装标准 pk(1184 B) / sk(2400 B)。
 * 文件布局沿用 ver0_2/otbn/mlkem768
 */

.globl poly_tobytes
.globl poly_frombytes
.globl pack_pk
.globl pack_sk
.globl unpack_pk
.text
/**
 * Vectorized encoding of 256 12-bit polynomial coefficients into 384 packed bytes (ByteEncode_12).
 *
 * Implements Algorithm 5 (ByteEncode_d) of FIPS 203 for d = 12.
 * Uses 256-bit WDR vector funnel shifts (`bn.rshi`) to pack 256 12-bit coefficients into 12 256-bit WDRs.
 * Loop 32 iterations: 256 coefficients -> 384 bytes output.
 *
 * @param[in]  x2: DMEM input address of 256 32-bit polynomial coefficients (1024 bytes).
 * @param[in]  x3: DMEM output address for 384 packed bytes (12 256-bit WDRs).
 *
 */
poly_tobytes:
  /* Push clobbered registers onto the stack. */
  .irp reg, x2, x3, x4
    sw \reg, 0(x31)
    addi x31, x31, 4
  .endr

  loopi 32, 16
    /* Load 8 coefficients into w0. */
    bn.lid x0, 0(x2++)

    loopi 8, 13
      bn.rshi w1,  w2,  w1  >> 12
      bn.rshi w2,  w3,  w2  >> 12
      bn.rshi w3,  w4,  w3  >> 12
      bn.rshi w4,  w5,  w4  >> 12
      bn.rshi w5,  w6,  w5  >> 12
      bn.rshi w6,  w7,  w6  >> 12
      bn.rshi w7,  w8,  w7  >> 12
      bn.rshi w8,  w9,  w8  >> 12
      bn.rshi w9,  w10, w9  >> 12
      bn.rshi w10, w11, w10 >> 12
      bn.rshi w11, w12, w11 >> 12
      bn.rshi w12, w0,  w12 >> 12

      /* Remove the coefficient from w0. */
      bn.rshi w0, w31, w0 >> 32
      /* End of loop */
    nop
    /* End of loop */

  /* Store the 12 encoded WDRs (384 bytes) to DMEM at x3 from w1 up to w12. */
  addi x4, x0, 1
  loopi 12, 2
    bn.sid x4++, 0(x3)
    addi x3, x3, 32
    /* End of loop */

  /* Restore registers. */
  .irp reg, x4, x3, x2
    addi x31, x31, -4
    lw \reg, 0(x31)
  .endr

  ret



/**
 * Decode 384 bytes into 256 12-bit polynomial coefficients (ByteDecode_12).
 *
 * Implements Algorithm 6 (ByteDecode_d) of FIPS 203 for d = 12.
 * Uses 256-bit WDR vector funnel shifts (`bn.rshi`) to unpack 12 256-bit WDRs (384 bytes)
 * into 256 32-bit polynomial coefficients.
 *
 * @param[in]  x2: DMEM input address of 384 packed bytes (12 WDRs).
 * @param[in]  x3: DMEM output address for 256 32-bit polynomial coefficients (1024 bytes).
 *
 */
poly_frombytes:
  /* Push clobbered registers onto the stack. */
  .irp reg, x2, x3, x4
    sw \reg, 0(x31)
    addi x31, x31, 4
  .endr

  /* Load 12 WDRs (384 bytes) into w12..w1 from input at x2. */
  addi x4, x0, 12
  loopi 12, 2
    bn.lid x4, 0(x2++)
    addi x4, x4, -1
    /* End of loop */

  /* Unpack 256 12-bit coefficients into 32 256-bit WDRs (1024 bytes) at x3. */
  loopi 32, 16
    loopi 8, 14
      bn.rshi w0,  w12, w0  >> 12
      bn.rshi w0,  w31, w0  >> 20
      bn.rshi w12, w11, w12 >> 12
      bn.rshi w11, w10, w11 >> 12
      bn.rshi w10, w9,  w10 >> 12
      bn.rshi w9,  w8,  w9  >> 12
      bn.rshi w8,  w7,  w8  >> 12
      bn.rshi w7,  w6,  w7  >> 12
      bn.rshi w6,  w5,  w6  >> 12
      bn.rshi w5,  w4,  w5  >> 12
      bn.rshi w4,  w3,  w4  >> 12
      bn.rshi w3,  w2,  w3  >> 12
      bn.rshi w2,  w1,  w2  >> 12
      bn.rshi w1,  w31, w1  >> 12
      /* End of loop */

    bn.sid x0, 0(x3++)
    /* End of loop */

  /* Restore registers. */
  .irp reg, x4, x3, x2
    addi x31, x31, -4
    lw \reg, 0(x31)
  .endr

  ret



/* ======================================================================
 * 以下为 ver0_2 接口的包装函数(本文件新写)。
 * 内部数据为官方 32-bit 系数布局；pk/sk 为标准 FIPS 203 打包格式。
 * ML-KEM-768: k = 3, poly_tobytes = 384 B/多项式, pk = 1184 B, sk = 2400 B
 * ====================================================================== */

/**
 * ver0_2 接口: pack_pk —— pk = pk_t(k*384 = 1152 B) || rho(32 B)，共 1184 字节
 *
 * @param[in]  x10: 源 pk_t 地址 (1152 字节)
 * @param[in]  x11: 源 rho 地址 (32 字节)
 * @param[out] x13: 目标 pk 地址 (1184 字节)
 *
 * Clobbered: w0, x10, x11, x13
 */
pack_pk:
  loopi 36, 2
    bn.lid x0, 0(x10++)
    bn.sid x0, 0(x13++)
  bn.lid x0, 0(x11)
  bn.sid x0, 0(x13)
  ret

/**
 * ver0_2 接口: pack_sk ——
 *   sk = s(1152) || pk_t(1152) || rho(32) || H(pk)(32) || z(32)，共 2400 字节
 *   其中 z = z_share0 ^ z_share1 (掩码合并)
 *
 * @param[in]  x10: 源 s 地址            (sk_s_share0, 1152 字节)
 * @param[in]  x11: 源 pk_t 地址          (1152 字节)
 * @param[in]  x12: 源 rho 地址           (32 字节)
 * @param[in]  x14: 源 H(pk) 地址         (32 字节)
 * @param[in]  x15: 源 z_share0 地址      (32 字节)
 * @param[in]  x16: 源 z_share1 地址      (32 字节)
 * @param[out] x13: 目标 sk 地址          (2400 字节)
 *
 * Clobbered: w0, w1, w2, x10-x16
 */
pack_sk:
  /* s: 1152 B */
  loopi 36, 2
    bn.lid x0, 0(x10++)
    bn.sid x0, 0(x13++)
  /* pk_t: 1152 B */
  loopi 36, 2
    bn.lid x0, 0(x11++)
    bn.sid x0, 0(x13++)
  /* rho: 32 B */
  bn.lid x0, 0(x12)
  bn.sid x0, 0(x13++)
  /* H(pk): 32 B */
  bn.lid x0, 0(x14)
  bn.sid x0, 0(x13++)
  /* z = z_share0 ^ z_share1: 32 B */
  addi x5, x0, 1
  bn.lid x5, 0(x15)
  addi x6, x0, 2
  bn.lid x6, 0(x16)
  bn.xor w0, w1, w2
  bn.sid x0, 0(x13)
  ret

/**
 * ver0_2 接口: unpack_pk —— pk(1184 B) -> pk_t(1152 B) + rho(32 B)
 *
 * @param[in]  x10: 源 pk 地址 (1184 字节)
 * @param[out] x12: 目标 pk_t 地址 (1152 字节)
 * @param[out] x13: 目标 rho 地址 (32 字节)
 *
 * Clobbered: w0, x10, x12, x13
 */
unpack_pk:
  loopi 36, 2
    bn.lid x0, 0(x10++)
    bn.sid x0, 0(x12++)
  bn.lid x0, 0(x10)
  bn.sid x0, 0(x13)
  ret
