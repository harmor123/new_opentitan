/* Copyright lowRISC contributors (OpenTitan project). */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */
/*
 * ver1_1 (ML-KEM-768, 官方向量指令实现)
 * 内核逐字移植自: sw/otbn/crypto/mlkem1024/mlkem1024_ntt.s
 * 文件布局沿用 ver0_2/otbn/mlkem768
 */

.globl ntt
.globl _load_64x32
.globl _store_64x32
.globl _transpose_8x8_w0w16
.text
/**
 * Compute the forward number-theoretic transform (NTT) for a polynomial f(x)
 * in Z_q / (X^256+1) for ML-KEM-1024 (q = 3329).
 *
 * Implements Algorithm 9 (NTT) of FIPS 203. The modulus q needs to be provided
 * in the MOD[31:0] register alongside the Montgomery constant
 * mu = -q^-1 mod 2^32 in MOD[63:32].
 *
 * This routine can be in-place if x2 = x3.
 *
 * @param[in] x2: DMEM address of input polynomial (256 coefficients).
 * @param[out] x3: DMEM address of output polynomial (256 coefficients).
 *
 * Clobbered WDRs: w0-w16, w30, w31.
 */
ntt:
  .irp reg, x4, x5, x6, x20
    sw \reg, 0(x31)
    addi x31, x31, 4
  .endr

  li x5, 16
  la x4, _twiddles
  bn.lid x5, 0(x4)

  addi x6, x2, 0

  /* Layer 1: len = 128 */
  loopi 2, 43
_ntt_layer1_loop:
    addi x20, x6, 0
    li   x5, 0
    jal  x1, _load_64x32
    addi x20, x20, 256
    jal  x1, _load_64x32

    bn.mulvml.8S w30,  w8, w16, 0
    bn.addvm.8S  w30, w30, w31
    bn.subvm.8S   w8,  w0, w30
    bn.addvm.8S   w0,  w0, w30
    bn.mulvml.8S w30,  w9, w16, 0
    bn.addvm.8S  w30, w30, w31
    bn.subvm.8S   w9,  w1, w30
    bn.addvm.8S   w1,  w1, w30
    bn.mulvml.8S w30, w10, w16, 0
    bn.addvm.8S  w30, w30, w31
    bn.subvm.8S  w10,  w2, w30
    bn.addvm.8S   w2,  w2, w30
    bn.mulvml.8S w30, w11, w16, 0
    bn.addvm.8S  w30, w30, w31
    bn.subvm.8S  w11,  w3, w30
    bn.addvm.8S   w3,  w3, w30
    bn.mulvml.8S w30, w12, w16, 0
    bn.addvm.8S  w30, w30, w31
    bn.subvm.8S  w12,  w4, w30
    bn.addvm.8S   w4,  w4, w30
    bn.mulvml.8S w30, w13, w16, 0
    bn.addvm.8S  w30, w30, w31
    bn.subvm.8S  w13,  w5, w30
    bn.addvm.8S   w5,  w5, w30
    bn.mulvml.8S w30, w14, w16, 0
    bn.addvm.8S  w30, w30, w31
    bn.subvm.8S  w14,  w6, w30
    bn.addvm.8S   w6,  w6, w30
    bn.mulvml.8S w30, w15, w16, 0
    bn.addvm.8S  w30, w30, w31
    bn.subvm.8S  w15,  w7, w30
    bn.addvm.8S   w7,  w7, w30

    addi x20, x6, 0
    li   x5, 0
    jal  x1, _store_64x32
    addi x20, x20, 256
    jal  x1, _store_64x32

    addi x6, x6, 256
    /* End of loop */

  addi x6, x2, 0

  /* Layers 2-7 */
  loopi 2, 211
_ntt_layers_loop:
    bn.lid x5, 0(x4++)
    addi x20, x6, 0
    li   x5, 0
    jal  x1, _load_64x32
    jal  x1, _load_64x32

    /* Layer 2 */
    bn.mulvml.8S w30,  w8, w16, 1
    bn.addvm.8S  w30, w30, w31
    bn.subvm.8S   w8,  w0, w30
    bn.addvm.8S   w0,  w0, w30
    bn.mulvml.8S w30,  w9, w16, 1
    bn.addvm.8S  w30, w30, w31
    bn.subvm.8S   w9,  w1, w30
    bn.addvm.8S   w1,  w1, w30
    bn.mulvml.8S w30, w10, w16, 1
    bn.addvm.8S  w30, w30, w31
    bn.subvm.8S  w10,  w2, w30
    bn.addvm.8S   w2,  w2, w30
    bn.mulvml.8S w30, w11, w16, 1
    bn.addvm.8S  w30, w30, w31
    bn.subvm.8S  w11,  w3, w30
    bn.addvm.8S   w3,  w3, w30
    bn.mulvml.8S w30, w12, w16, 1
    bn.addvm.8S  w30, w30, w31
    bn.subvm.8S  w12,  w4, w30
    bn.addvm.8S   w4,  w4, w30
    bn.mulvml.8S w30, w13, w16, 1
    bn.addvm.8S  w30, w30, w31
    bn.subvm.8S  w13,  w5, w30
    bn.addvm.8S   w5,  w5, w30
    bn.mulvml.8S w30, w14, w16, 1
    bn.addvm.8S  w30, w30, w31
    bn.subvm.8S  w14,  w6, w30
    bn.addvm.8S   w6,  w6, w30
    bn.mulvml.8S w30, w15, w16, 1
    bn.addvm.8S  w30, w30, w31
    bn.subvm.8S  w15,  w7, w30
    bn.addvm.8S   w7,  w7, w30

    /* Layer 3 */
    bn.mulvml.8S w30,  w4, w16, 2
    bn.addvm.8S  w30, w30, w31
    bn.subvm.8S   w4,  w0, w30
    bn.addvm.8S   w0,  w0, w30
    bn.mulvml.8S w30,  w5, w16, 2
    bn.addvm.8S  w30, w30, w31
    bn.subvm.8S   w5,  w1, w30
    bn.addvm.8S   w1,  w1, w30
    bn.mulvml.8S w30,  w6, w16, 2
    bn.addvm.8S  w30, w30, w31
    bn.subvm.8S   w6,  w2, w30
    bn.addvm.8S   w2,  w2, w30
    bn.mulvml.8S w30,  w7, w16, 2
    bn.addvm.8S  w30, w30, w31
    bn.subvm.8S   w7,  w3, w30
    bn.addvm.8S   w3,  w3, w30
    bn.mulvml.8S w30, w12, w16, 3
    bn.addvm.8S  w30, w30, w31
    bn.subvm.8S  w12,  w8, w30
    bn.addvm.8S   w8,  w8, w30
    bn.mulvml.8S w30, w13, w16, 3
    bn.addvm.8S  w30, w30, w31
    bn.subvm.8S  w13,  w9, w30
    bn.addvm.8S   w9,  w9, w30
    bn.mulvml.8S w30, w14, w16, 3
    bn.addvm.8S  w30, w30, w31
    bn.subvm.8S  w14, w10, w30
    bn.addvm.8S  w10, w10, w30
    bn.mulvml.8S w30, w15, w16, 3
    bn.addvm.8S  w30, w30, w31
    bn.subvm.8S  w15, w11, w30
    bn.addvm.8S  w11, w11, w30

    /* Layer 4 */
    bn.mulvml.8S w30,  w2, w16, 4
    bn.addvm.8S  w30, w30, w31
    bn.subvm.8S   w2,  w0, w30
    bn.addvm.8S   w0,  w0, w30
    bn.mulvml.8S w30,  w3, w16, 4
    bn.addvm.8S  w30, w30, w31
    bn.subvm.8S   w3,  w1, w30
    bn.addvm.8S   w1,  w1, w30
    bn.mulvml.8S w30,  w6, w16, 5
    bn.addvm.8S  w30, w30, w31
    bn.subvm.8S   w6,  w4, w30
    bn.addvm.8S   w4,  w4, w30
    bn.mulvml.8S w30,  w7, w16, 5
    bn.addvm.8S  w30, w30, w31
    bn.subvm.8S   w7,  w5, w30
    bn.addvm.8S   w5,  w5, w30
    bn.mulvml.8S w30, w10, w16, 6
    bn.addvm.8S  w30, w30, w31
    bn.subvm.8S  w10,  w8, w30
    bn.addvm.8S   w8,  w8, w30
    bn.mulvml.8S w30, w11, w16, 6
    bn.addvm.8S  w30, w30, w31
    bn.subvm.8S  w11,  w9, w30
    bn.addvm.8S   w9,  w9, w30
    bn.mulvml.8S w30, w14, w16, 7
    bn.addvm.8S  w30, w30, w31
    bn.subvm.8S  w14, w12, w30
    bn.addvm.8S  w12, w12, w30
    bn.mulvml.8S w30, w15, w16, 7
    bn.addvm.8S  w30, w30, w31
    bn.subvm.8S  w15, w13, w30
    bn.addvm.8S  w13, w13, w30

    /* Layer 5 */
    bn.lid x5, 0(x4++)
    bn.mulvml.8S w30,  w1, w16, 0
    bn.addvm.8S  w30, w30, w31
    bn.subvm.8S   w1,  w0, w30
    bn.addvm.8S   w0,  w0, w30
    bn.mulvml.8S w30,  w3, w16, 1
    bn.addvm.8S  w30, w30, w31
    bn.subvm.8S   w3,  w2, w30
    bn.addvm.8S   w2,  w2, w30
    bn.mulvml.8S w30,  w5, w16, 2
    bn.addvm.8S  w30, w30, w31
    bn.subvm.8S   w5,  w4, w30
    bn.addvm.8S   w4,  w4, w30
    bn.mulvml.8S w30,  w7, w16, 3
    bn.addvm.8S  w30, w30, w31
    bn.subvm.8S   w7,  w6, w30
    bn.addvm.8S   w6,  w6, w30
    bn.mulvml.8S w30,  w9, w16, 4
    bn.addvm.8S  w30, w30, w31
    bn.subvm.8S   w9,  w8, w30
    bn.addvm.8S   w8,  w8, w30
    bn.mulvml.8S w30, w11, w16, 5
    bn.addvm.8S  w30, w30, w31
    bn.subvm.8S  w11, w10, w30
    bn.addvm.8S  w10, w10, w30
    bn.mulvml.8S w30, w13, w16, 6
    bn.addvm.8S  w30, w30, w31
    bn.subvm.8S  w13, w12, w30
    bn.addvm.8S  w12, w12, w30
    bn.mulvml.8S w30, w15, w16, 7
    bn.addvm.8S  w30, w30, w31
    bn.subvm.8S  w15, w14, w30
    bn.addvm.8S  w14, w14, w30

    /* Layer 6 */
    jal x1, _transpose_8x8_w0w16
    bn.lid x5, 0(x4++)
    bn.mulvm.8S w30,  w4, w16
    bn.addvm.8S w30, w30, w31
    bn.subvm.8S  w4,  w0, w30
    bn.addvm.8S  w0,  w0, w30
    bn.mulvm.8S w30,  w5, w16
    bn.addvm.8S w30, w30, w31
    bn.subvm.8S  w5,  w1, w30
    bn.addvm.8S  w1,  w1, w30
    bn.mulvm.8S w30,  w6, w16
    bn.addvm.8S w30, w30, w31
    bn.subvm.8S  w6,  w2, w30
    bn.addvm.8S  w2,  w2, w30
    bn.mulvm.8S w30,  w7, w16
    bn.addvm.8S w30, w30, w31
    bn.subvm.8S  w7,  w3, w30
    bn.addvm.8S  w3,  w3, w30

    bn.lid x5, 0(x4++)
    bn.mulvm.8S w30, w12, w16
    bn.addvm.8S w30, w30, w31
    bn.subvm.8S w12,  w8, w30
    bn.addvm.8S  w8,  w8, w30
    bn.mulvm.8S w30, w13, w16
    bn.addvm.8S w30, w30, w31
    bn.subvm.8S w13,  w9, w30
    bn.addvm.8S  w9,  w9, w30
    bn.mulvm.8S w30, w14, w16
    bn.addvm.8S w30, w30, w31
    bn.subvm.8S w14, w10, w30
    bn.addvm.8S w10, w10, w30
    bn.mulvm.8S w30, w15, w16
    bn.addvm.8S w30, w30, w31
    bn.subvm.8S w15, w11, w30
    bn.addvm.8S w11, w11, w30

    /* Layer 7 */
    bn.lid x5, 0(x4++)
    bn.mulvm.8S w30,  w2, w16
    bn.addvm.8S w30, w30, w31
    bn.subvm.8S  w2,  w0, w30
    bn.addvm.8S  w0,  w0, w30
    bn.mulvm.8S w30,  w3, w16
    bn.addvm.8S w30, w30, w31
    bn.subvm.8S  w3,  w1, w30
    bn.addvm.8S  w1,  w1, w30

    bn.lid x5, 0(x4++)
    bn.mulvm.8S w30,  w6, w16
    bn.addvm.8S w30, w30, w31
    bn.subvm.8S  w6,  w4, w30
    bn.addvm.8S  w4,  w4, w30
    bn.mulvm.8S w30,  w7, w16
    bn.addvm.8S w30, w30, w31
    bn.subvm.8S  w7,  w5, w30
    bn.addvm.8S  w5,  w5, w30

    bn.lid x5, 0(x4++)
    bn.mulvm.8S w30, w10, w16
    bn.addvm.8S w30, w30, w31
    bn.subvm.8S w10,  w8, w30
    bn.addvm.8S  w8,  w8, w30
    bn.mulvm.8S w30, w11, w16
    bn.addvm.8S w30, w30, w31
    bn.subvm.8S w11,  w9, w30
    bn.addvm.8S  w9,  w9, w30

    bn.lid x5, 0(x4++)
    bn.mulvm.8S w30, w14, w16
    bn.addvm.8S w30, w30, w31
    bn.subvm.8S w14, w12, w30
    bn.addvm.8S w12, w12, w30
    bn.mulvm.8S w30, w15, w16
    bn.addvm.8S w30, w30, w31
    bn.subvm.8S w15, w13, w30
    bn.addvm.8S w13, w13, w30

    jal x1, _transpose_8x8_w0w16

    addi x20, x6, 0
    li   x5, 0
    jal  x1, _store_64x32
    jal  x1, _store_64x32

    addi x6, x6, 512
    /* End of loop */

  .irp reg, x20, x6, x5, x4
    addi x31, x31, -4
    lw \reg, 0(x31)
  .endr

  ret

/**
 * In-place transpose of two 8x8 matrices with 32-bit elements held in w0-w7
 * and w8-w15.
 *
 * @param[in,out] w0-w7: First 8x8 matrix A0.
 * @param[in,out] w8-w15: Second 8x8 matrix A1.
 */
_transpose_8x8_w0w16:
  bn.trn1.8S w16,  w0,  w1
  bn.trn2.8S w17,  w0,  w1
  bn.trn1.8S w18,  w2,  w3
  bn.trn2.8S w19,  w2,  w3
  bn.trn1.8S w20,  w4,  w5
  bn.trn2.8S w21,  w4,  w5
  bn.trn1.8S w22,  w6,  w7
  bn.trn2.8S w23,  w6,  w7
  bn.trn1.4D  w4, w16, w18
  bn.trn2.4D w16, w16, w18
  bn.trn1.4D w18, w17, w19
  bn.trn2.4D w17, w17, w19
  bn.trn1.4D w19, w20, w22
  bn.trn2.4D w20, w20, w22
  bn.trn1.4D w22, w21, w23
  bn.trn2.4D w21, w21, w23
  bn.trn1.2Q  w0,  w4, w19
  bn.trn2.2Q  w4,  w4, w19
  bn.trn1.2Q  w1, w18, w22
  bn.trn2.2Q  w5, w18, w22
  bn.trn1.2Q  w2, w16, w20
  bn.trn2.2Q  w6, w16, w20
  bn.trn1.2Q  w3, w17, w21
  bn.trn2.2Q  w7, w17, w21

  bn.trn1.8S w16,  w8,  w9
  bn.trn2.8S w17,  w8,  w9
  bn.trn1.8S w18, w10, w11
  bn.trn2.8S w19, w10, w11
  bn.trn1.8S w20, w12, w13
  bn.trn2.8S w21, w12, w13
  bn.trn1.8S w22, w14, w15
  bn.trn2.8S w23, w14, w15
  bn.trn1.4D w12, w16, w18
  bn.trn2.4D w16, w16, w18
  bn.trn1.4D w18, w17, w19
  bn.trn2.4D w17, w17, w19
  bn.trn1.4D w19, w20, w22
  bn.trn2.4D w20, w20, w22
  bn.trn1.4D w22, w21, w23
  bn.trn2.4D w21, w21, w23
  bn.trn1.2Q  w8, w12, w19
  bn.trn2.2Q w12, w12, w19
  bn.trn1.2Q  w9, w18, w22
  bn.trn2.2Q w13, w18, w22
  bn.trn1.2Q w10, w16, w20
  bn.trn2.2Q w14, w16, w20
  bn.trn1.2Q w11, w17, w21
  bn.trn2.2Q w15, w17, w21

  ret

/**
 * Load 64 32-bit polynomial coefficients from DMEM[x20] to w[x5:x5+8].
 */
_load_64x32:
  bn.lid x5++, 0(x20)
  bn.lid x5++, 32(x20)
  bn.lid x5++, 64(x20)
  bn.lid x5++, 96(x20)
  bn.lid x5++, 128(x20)
  bn.lid x5++, 160(x20)
  bn.lid x5++, 192(x20)
  bn.lid x5++, 224(x20)
  addi x20, x20, 256
  ret

/**
 * Store 64 32-bit polynomial coefficients from w[x5:x5+8] to DMEM[x20].
 */
_store_64x32:
  bn.sid x5++, 0(x20)
  bn.sid x5++, 32(x20)
  bn.sid x5++, 64(x20)
  bn.sid x5++, 96(x20)
  bn.sid x5++, 128(x20)
  bn.sid x5++, 160(x20)
  bn.sid x5++, 192(x20)
  bn.sid x5++, 224(x20)
  addi x20, x20, 256
  ret

.section .data
.balign 32
.globl _twiddles

_twiddles:
/* Half 1 */
.word 0x0000094b
.word 0x0000079c
.word 0x00000a31
.word 0x000000a6
.word 0x00000827
.word 0x00000c2c
.word 0x000005bb
.word 0x00000c02
.word 0x000003f0
.word 0x000006e5
.word 0x000002b3
.word 0x00000b8d
.word 0x00000cc1
.word 0x000009e2
.word 0x00000532
.word 0x00000a00
.word 0x000005f4
.word 0x000006dd
.word 0x00000173
.word 0x000008f3
.word 0x0000066f
.word 0x00000558
.word 0x000005b0
.word 0x000002bc
.word 0x00000252
.word 0x0000069e
.word 0x0000049c
.word 0x00000b38
.word 0x0000056d
.word 0x0000055c
.word 0x00000650
.word 0x00000409
.word 0x00000bd3
.word 0x00000c53
.word 0x00000434
.word 0x00000bcf
.word 0x0000088d
.word 0x00000664
.word 0x00000361
.word 0x000004f6
.word 0x000001ef
.word 0x0000082d
.word 0x00000b06
.word 0x000000ed
.word 0x00000bdd
.word 0x00000913
.word 0x00000360
.word 0x000007e3
.word 0x000001eb
.word 0x000006e0
.word 0x000008c1
.word 0x00000a4c
.word 0x00000846
.word 0x0000060f
.word 0x00000bdc
.word 0x00000c00
.word 0x0000002c
.word 0x0000014e
.word 0x00000bf6
.word 0x000000f3
.word 0x0000007a
.word 0x0000072a
.word 0x00000ab4
.word 0x000006c5

/* Half 2 */
.word 0x00000000
.word 0x000009a9
.word 0x00000cef
.word 0x00000878
.word 0x00000406
.word 0x00000c70
.word 0x0000035a
.word 0x0000081d
.word 0x0000075f
.word 0x000000cb
.word 0x000005b6
.word 0x0000043f
.word 0x00000795
.word 0x00000165
.word 0x000003c4
.word 0x000008d0
.word 0x00000699
.word 0x000002ec
.word 0x00000cd8
.word 0x0000092d
.word 0x000005c6
.word 0x00000847
.word 0x000005ff
.word 0x00000322
.word 0x00000a9c
.word 0x0000081a
.word 0x00000bf8
.word 0x000004c1
.word 0x0000068d
.word 0x00000ce7
.word 0x000008f1
.word 0x00000b0d
.word 0x00000a2d
.word 0x00000ba2
.word 0x00000557
.word 0x000005a9
.word 0x0000006f
.word 0x00000056
.word 0x00000136
.word 0x00000348
.word 0x00000ca5
.word 0x00000918
.word 0x00000cd2
.word 0x00000779
.word 0x00000876
.word 0x000008aa
.word 0x00000015
.word 0x00000394
.word 0x00000821
.word 0x00000a48
.word 0x0000071f
.word 0x00000ae8
.word 0x00000b4f
.word 0x00000869
.word 0x00000755
.word 0x000008f6
.word 0x00000aa9
.word 0x00000cf2
.word 0x00000aad
.word 0x0000013e
.word 0x000007b0
.word 0x000002cb
.word 0x00000b47
.word 0x000005cf

.balign 32

.balign 32
.globl _basemul_twiddles
_basemul_twiddles:
.word 0x00000bd3
.word 0x00000bd3
.word 0x0000012e
.word 0x0000012e
.word 0x000001ef
.word 0x000001ef
.word 0x00000b12
.word 0x00000b12
.word 0x00000c53
.word 0x00000c53
.word 0x000000ae
.word 0x000000ae
.word 0x0000082d
.word 0x0000082d
.word 0x000004d4
.word 0x000004d4
.word 0x00000434
.word 0x00000434
.word 0x000008cd
.word 0x000008cd
.word 0x00000b06
.word 0x00000b06
.word 0x000001fb
.word 0x000001fb
.word 0x00000bcf
.word 0x00000bcf
.word 0x00000132
.word 0x00000132
.word 0x000000ed
.word 0x000000ed
.word 0x00000c14
.word 0x00000c14
.word 0x0000088d
.word 0x0000088d
.word 0x00000474
.word 0x00000474
.word 0x00000bdd
.word 0x00000bdd
.word 0x00000124
.word 0x00000124
.word 0x00000664
.word 0x00000664
.word 0x0000069d
.word 0x0000069d
.word 0x00000913
.word 0x00000913
.word 0x000003ee
.word 0x000003ee
.word 0x00000361
.word 0x00000361
.word 0x000009a0
.word 0x000009a0
.word 0x00000360
.word 0x00000360
.word 0x000009a1
.word 0x000009a1
.word 0x000004f6
.word 0x000004f6
.word 0x0000080b
.word 0x0000080b
.word 0x000007e3
.word 0x000007e3
.word 0x0000051e
.word 0x0000051e
.word 0x000001eb
.word 0x000001eb
.word 0x00000b16
.word 0x00000b16
.word 0x0000002c
.word 0x0000002c
.word 0x00000cd5
.word 0x00000cd5
.word 0x000006e0
.word 0x000006e0
.word 0x00000621
.word 0x00000621
.word 0x0000014e
.word 0x0000014e
.word 0x00000bb3
.word 0x00000bb3
.word 0x000008c1
.word 0x000008c1
.word 0x00000440
.word 0x00000440
.word 0x00000bf6
.word 0x00000bf6
.word 0x0000010b
.word 0x0000010b
.word 0x00000a4c
.word 0x00000a4c
.word 0x000002b5
.word 0x000002b5
.word 0x000000f3
.word 0x000000f3
.word 0x00000c0e
.word 0x00000c0e
.word 0x00000846
.word 0x00000846
.word 0x000004bb
.word 0x000004bb
.word 0x0000007a
.word 0x0000007a
.word 0x00000c87
.word 0x00000c87
.word 0x0000060f
.word 0x0000060f
.word 0x000006f2
.word 0x000006f2
.word 0x0000072a
.word 0x0000072a
.word 0x000005d7
.word 0x000005d7
.word 0x00000bdc
.word 0x00000bdc
.word 0x00000125
.word 0x00000125
.word 0x00000ab4
.word 0x00000ab4
.word 0x0000024d
.word 0x0000024d
.word 0x00000c00
.word 0x00000c00
.word 0x00000101
.word 0x00000101
.word 0x000006c5
.word 0x000006c5
.word 0x0000063c
.word 0x0000063c
.word 0x00000a2d
.word 0x00000a2d
.word 0x000002d4
.word 0x000002d4
.word 0x00000ca5
.word 0x00000ca5
.word 0x0000005c
.word 0x0000005c
.word 0x00000ba2
.word 0x00000ba2
.word 0x0000015f
.word 0x0000015f
.word 0x00000918
.word 0x00000918
.word 0x000003e9
.word 0x000003e9
.word 0x00000557
.word 0x00000557
.word 0x000007aa
.word 0x000007aa
.word 0x00000cd2
.word 0x00000cd2
.word 0x0000002f
.word 0x0000002f
.word 0x000005a9
.word 0x000005a9
.word 0x00000758
.word 0x00000758
.word 0x00000779
.word 0x00000779
.word 0x00000588
.word 0x00000588
.word 0x0000006f
.word 0x0000006f
.word 0x00000c92
.word 0x00000c92
.word 0x00000876
.word 0x00000876
.word 0x0000048b
.word 0x0000048b
.word 0x00000056
.word 0x00000056
.word 0x00000cab
.word 0x00000cab
.word 0x000008aa
.word 0x000008aa
.word 0x00000457
.word 0x00000457
.word 0x00000136
.word 0x00000136
.word 0x00000bcb
.word 0x00000bcb
.word 0x00000015
.word 0x00000015
.word 0x00000cec
.word 0x00000cec
.word 0x00000348
.word 0x00000348
.word 0x000009b9
.word 0x000009b9
.word 0x00000394
.word 0x00000394
.word 0x0000096d
.word 0x0000096d
.word 0x00000821
.word 0x00000821
.word 0x000004e0
.word 0x000004e0
.word 0x00000aa9
.word 0x00000aa9
.word 0x00000258
.word 0x00000258
.word 0x00000a48
.word 0x00000a48
.word 0x000002b9
.word 0x000002b9
.word 0x00000cf2
.word 0x00000cf2
.word 0x0000000f
.word 0x0000000f
.word 0x0000071f
.word 0x0000071f
.word 0x000005e2
.word 0x000005e2
.word 0x00000aad
.word 0x00000aad
.word 0x00000254
.word 0x00000254
.word 0x00000ae8
.word 0x00000ae8
.word 0x00000219
.word 0x00000219
.word 0x0000013e
.word 0x0000013e
.word 0x00000bc3
.word 0x00000bc3
.word 0x00000b4f
.word 0x00000b4f
.word 0x000001b2
.word 0x000001b2
.word 0x000007b0
.word 0x000007b0
.word 0x00000551
.word 0x00000551
.word 0x00000869
.word 0x00000869
.word 0x00000498
.word 0x00000498
.word 0x000002cb
.word 0x000002cb
.word 0x00000a36
.word 0x00000a36
.word 0x00000755
.word 0x00000755
.word 0x000005ac
.word 0x000005ac
.word 0x00000b47
.word 0x00000b47
.word 0x000001ba
.word 0x000001ba
.word 0x000008f6
.word 0x000008f6
.word 0x0000040b
.word 0x0000040b
.word 0x000005cf
.word 0x000005cf
.word 0x00000732
.word 0x00000732
