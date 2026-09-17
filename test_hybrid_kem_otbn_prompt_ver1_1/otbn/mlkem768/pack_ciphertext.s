/* Copyright lowRISC contributors (OpenTitan project). */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */
/*
 * ver1_1 (ML-KEM-768, 官方向量指令实现) —— 密文压缩/解压缩与打包
 *
 * 说明: 官方 mlkem1024 只提供 du=11 / dv=5 的压缩函数(compress_11/compress_5 ...)。
 *       ML-KEM-768 需要 du=10 (u) / dv=4 (v)，本文件的 encode_10/compress_10/
 *       decode_10/decompress_10 与 encode_4/compress_4/decode_4/decompress_4
 *       由官方对应函数按位宽参数改写(循环结构、MOD WSR 定点除法用法完全一致)。
 *
 * 文件布局沿用 ver0_2/otbn/mlkem768
 * 依赖(由各 app 的内存文件提供): _compress_recip_m, _compress_offset_1664,
 *                                _compress_modulus_3329
 */

.globl poly_compress
.globl poly_decompress
.globl compress_4
.globl compress_10
.globl decompress_10
.globl encode_10
.globl decode_10
.globl encode_4
.globl decode_4
.globl decompress_4

.text

/**
 * Encapsulation: compress 256 coefficients mod 3329 to 10 bits and encode
 * (Compress_10 + ByteEncode_10) —— ML-KEM-768 的 du = 10。
 *
 * x' = ((x * 1024 + 1664) * 1290168 >> 32) mod 1024。
 * 定点除法与官方 compress_11 相同(M = round(2^32/3329) = 1290168, mu = 0)。
 *
 * @param[in]  x2: 输入多项式地址 (256 个 32-bit 系数, 1024 B) [原地被压缩覆盖]
 * @param[out] x3: 输出压缩字节地址 (320 字节 = 10 WDR)
 *
 * Clobbered: w0, w1, w29, w30, x4, x5 (x2/x3 由栈保存恢复)
 */
compress_10:
  /* Push clobbered registers onto the stack. */
  .irp reg, x2, x3, x4, x5
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

  /* Setup w29 = [0x3FF, ...] (10-bit mask). */
  bn.not w29, w31
  bn.shv.8s w29, w29 >> 22

  li x4, 1

  /* 32 iterations, 8 coefficients each: Compress_10 in place at x2. */
  loopi 32, 6
    bn.lid x4, 0(x2)
    bn.shv.8s w1, w1 << 10
    bn.addv.8s w1, w1, w30
    bn.mulvml.8s w1, w1, w0, 0
    bn.and w1, w1, w29
    bn.sid x4, 0(x2++)
    /* End of loop */

  /* Reset input pointer to start of buffer before calling encode_10. */
  addi x2, x2, -1024
  jal x1, encode_10

  /* Restore MOD CSR to q = 3329, mu = 0x94570CFF. */
  la x5, _compress_modulus_3329
  bn.lid x0, 0(x5)
  bn.wsrw MOD, w0

  /* Restore GPRs. */
  .irp reg, x5, x4, x3, x2
    addi x31, x31, -4
    lw \reg, 0(x31)
  .endr

  ret

/**
 * ByteEncode_10: pack 256 10-bit coefficients into 320 packed bytes (10 WDRs).
 *
 * @param[in]  x2: 输入 256 个 32-bit 系数 (1024 B)
 * @param[out] x3: 输出 320 打包字节 (10 WDR)
 */
encode_10:
  .irp reg, x2, x3, x4
    sw \reg, 0(x31)
    addi x31, x31, 4
  .endr

  loopi 32, 14
    /* Load 8 coefficients into w0. */
    bn.lid x0, 0(x2++)

    loopi 8, 11
      bn.rshi w1,  w2,  w1  >> 10
      bn.rshi w2,  w3,  w2  >> 10
      bn.rshi w3,  w4,  w3  >> 10
      bn.rshi w4,  w5,  w4  >> 10
      bn.rshi w5,  w6,  w5  >> 10
      bn.rshi w6,  w7,  w6  >> 10
      bn.rshi w7,  w8,  w7  >> 10
      bn.rshi w8,  w9,  w8  >> 10
      bn.rshi w9,  w10, w9  >> 10
      bn.rshi w10, w0,  w10 >> 10
      /* Remove the coefficient from w0. */
      bn.rshi w0, w31, w0 >> 32
      /* End of loop */
    nop
    /* End of loop */

  /* Store the 10 encoded WDRs (320 bytes) to DMEM at x3 from w1 up to w10. */
  addi x4, x0, 1
  loopi 10, 2
    bn.sid x4++, 0(x3)
    addi x3, x3, 32
    /* End of loop */

  .irp reg, x4, x3, x2
    addi x31, x31, -4
    lw \reg, 0(x31)
  .endr

  ret

/**
 * Decaps: decompress 320 bytes into 256 coefficients mod 3329
 * (ByteDecode_10 + Decompress_10) —— ML-KEM-768 的 du = 10。
 *
 * y = round(x * 3329 / 1024) = (x * 3329 + 512) >> 10。
 *
 * @param[in]  x2: 输入 320 压缩字节
 * @param[out] x3: 输出 256 个 32-bit 系数 (1024 B)
 */
decompress_10:
  .irp reg, x2, x3, x4
    sw \reg, 0(x31)
    addi x31, x31, 4
  .endr

  jal x1, decode_10

  /* Setup w30 = [512, ...] (offset for rounding). */
  bn.not w30, w31
  bn.shv.8s w30, w30 >> 31
  bn.shv.8s w30, w30 << 9

  /* Read q = 3329 from MOD CSR (MOD[31:0] = 3329) into w29[0]. */
  bn.wsrr w29, MOD

  li x4, 1
  loopi 32, 5
    bn.lid x4, 0(x3)
    bn.mulvl.8s w1, w1, w29, 0
    bn.addv.8s w1, w1, w30
    bn.shv.8s w1, w1 >> 10
    bn.sid x4, 0(x3++)
    /* End of loop */

  .irp reg, x4, x3, x2
    addi x31, x31, -4
    lw \reg, 0(x31)
  .endr

  ret

/**
 * ByteDecode_10: unpack 320 bytes into 256 10-bit coefficients.
 *
 * @param[in]  x2: 输入 320 打包字节 (10 WDR)
 * @param[out] x3: 输出 256 个 32-bit 系数 (1024 B)
 */
decode_10:
  .irp reg, x2, x3, x4
    sw \reg, 0(x31)
    addi x31, x31, 4
  .endr

  /* Load 10 WDRs (320 bytes) into w10..w1 from input at x2. */
  addi x4, x0, 10
  loopi 10, 2
    bn.lid x4, 0(x2++)
    addi x4, x4, -1
    /* End of loop */

  /* Unpack 256 10-bit coefficients into 32 256-bit WDRs (1024 bytes) at x3. */
  loopi 32, 14
    loopi 8, 12
      bn.rshi w0,  w10, w0  >> 10
      bn.rshi w0,  w31, w0  >> 22
      bn.rshi w10, w9,  w10 >> 10
      bn.rshi w9,  w8,  w9  >> 10
      bn.rshi w8,  w7,  w8  >> 10
      bn.rshi w7,  w6,  w7  >> 10
      bn.rshi w6,  w5,  w6  >> 10
      bn.rshi w5,  w4,  w5  >> 10
      bn.rshi w4,  w3,  w4  >> 10
      bn.rshi w3,  w2,  w3  >> 10
      bn.rshi w2,  w1,  w2  >> 10
      bn.rshi w1,  w31, w1  >> 10
      /* End of loop */

    bn.sid x0, 0(x3++)
    /* End of loop */

  .irp reg, x4, x3, x2
    addi x31, x31, -4
    lw \reg, 0(x31)
  .endr

  ret

/**
 * ver0_2 接口名: poly_compress —— v 多项式压缩并序列化 (dv = 4)，输出 128 字节。
 * 即 compress_4 (寄存器约定同官方: x2 = 输入多项式, x3 = 输出 128 字节)。
 *
 * @param[in]  x2: 输入多项式地址 (1024 B) [原地被压缩覆盖]
 * @param[out] x3: 输出 128 压缩字节
 */
poly_compress:
compress_4:
  .irp reg, x2, x3, x4, x5
    sw \reg, 0(x31)
    addi x31, x31, 4
  .endr

  /* Setup MOD CSR and w0 with reciprocal constant M = 1290168 and mu = 0. */
  la x5, _compress_recip_m
  bn.lid x0, 0(x5)
  bn.wsrw MOD, w0

  /* Setup w30 = [1664, ...] (offset for rounding). */
  li x4, 30
  la x5, _compress_offset_1664
  bn.lid x4, 0(x5)

  /* Setup w29 = [0xF, ...] (4-bit mask). */
  bn.not w29, w31
  bn.shv.8s w29, w29 >> 28

  li x4, 1

  /* Compress_4: x' = ((x * 16 + 1664) * 1290168 >> 32) mod 16, in place at x2. */
  loopi 32, 6
    bn.lid x4, 0(x2)
    bn.shv.8s w1, w1 << 4
    bn.addv.8s w1, w1, w30
    bn.mulvml.8s w1, w1, w0, 0
    bn.and w1, w1, w29
    bn.sid x4, 0(x2++)
    /* End of loop */

  /* Reset input pointer back to start of buffer before calling encode_4. */
  addi x2, x2, -1024
  jal x1, encode_4

  /* Restore MOD CSR to q = 3329, mu = 0x94570CFF. */
  la x5, _compress_modulus_3329
  bn.lid x0, 0(x5)
  bn.wsrw MOD, w0

  .irp reg, x5, x4, x3, x2
    addi x31, x31, -4
    lw \reg, 0(x31)
  .endr

  ret

/**
 * ByteEncode_4: pack 256 4-bit coefficients into 128 packed bytes (4 WDRs).
 *
 * @param[in]  x2: 输入 256 个 32-bit 系数 (1024 B)
 * @param[out] x3: 输出 128 打包字节 (4 WDR)
 */
encode_4:
  .irp reg, x2, x3, x4
    sw \reg, 0(x31)
    addi x31, x31, 4
  .endr

  loopi 32, 8
    /* Load 8 coefficients into w0. */
    bn.lid x0, 0(x2++)

    loopi 8, 5
      bn.rshi w1, w2, w1 >> 4
      bn.rshi w2, w3, w2 >> 4
      bn.rshi w3, w4, w3 >> 4
      bn.rshi w4, w0, w4 >> 4
      /* Remove the coefficient from w0. */
      bn.rshi w0, w31, w0 >> 32
      /* End of loop */
    nop
    /* End of loop */

  /* Store the 4 encoded WDRs (128 bytes) to DMEM at x3 from w1 up to w4. */
  addi x4, x0, 1
  loopi 4, 2
    bn.sid x4++, 0(x3)
    addi x3, x3, 32
    /* End of loop */

  .irp reg, x4, x3, x2
    addi x31, x31, -4
    lw \reg, 0(x31)
  .endr

  ret

/**
 * ver0_2 接口名: poly_decompress —— v 解序列化并解压缩 (dv = 4)，输入 128 字节。
 * 即 decompress_4 (寄存器约定同官方: x2 = 输入 128 字节, x3 = 输出多项式)。
 *
 * @param[in]  x2: 输入 128 压缩字节
 * @param[out] x3: 输出多项式 (1024 B)
 */
poly_decompress:
decompress_4:
  .irp reg, x2, x3, x4
    sw \reg, 0(x31)
    addi x31, x31, 4
  .endr

  jal x1, decode_4

  /* Setup w30 = [8, ...] (offset for rounding). */
  bn.not w30, w31
  bn.shv.8s w30, w30 >> 31
  bn.shv.8s w30, w30 << 3

  /* Read q = 3329 from MOD CSR (MOD[31:0] = 3329) into w29[0]. */
  bn.wsrr w29, MOD

  li x4, 1
  loopi 32, 5
    bn.lid x4, 0(x3)
    bn.mulvl.8s w1, w1, w29, 0
    bn.addv.8s w1, w1, w30
    bn.shv.8s w1, w1 >> 4
    bn.sid x4, 0(x3++)
    /* End of loop */

  .irp reg, x4, x3, x2
    addi x31, x31, -4
    lw \reg, 0(x31)
  .endr

  ret

/**
 * ByteDecode_4: unpack 128 bytes into 256 4-bit coefficients.
 *
 * @param[in]  x2: 输入 128 打包字节 (4 WDR)
 * @param[out] x3: 输出 256 个 32-bit 系数 (1024 B)
 */
decode_4:
  .irp reg, x2, x3, x4
    sw \reg, 0(x31)
    addi x31, x31, 4
  .endr

  /* Load 4 WDRs (128 bytes) into w4..w1 from input at x2. */
  addi x4, x0, 4
  loopi 4, 2
    bn.lid x4, 0(x2++)
    addi x4, x4, -1
    /* End of loop */

  /* Unpack 256 4-bit coefficients into 32 256-bit WDRs (1024 bytes) at x3. */
  loopi 32, 8
    loopi 8, 6
      bn.rshi w0, w4, w0 >> 4
      bn.rshi w0, w31, w0 >> 28
      bn.rshi w4, w3, w4 >> 4
      bn.rshi w3, w2, w3 >> 4
      bn.rshi w2, w1, w2 >> 4
      bn.rshi w1, w31, w1 >> 4
      /* End of loop */

    bn.sid x0, 0(x3++)
    /* End of loop */

  .irp reg, x4, x3, x2
    addi x31, x31, -4
    lw \reg, 0(x31)
  .endr

  ret

/* ======================================================================
 * ver0_2 接口的打包函数(本文件新写)
 * ====================================================================== */
