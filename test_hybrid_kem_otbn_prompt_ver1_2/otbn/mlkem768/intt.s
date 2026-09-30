/* Copyright lowRISC contributors (OpenTitan project). */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */
/*
 * ver1_1 (ML-KEM-768, 官方向量指令实现)
 * 内核逐字移植自: sw/otbn/crypto/mlkem1024/mlkem1024_ntt.s
 * 文件布局沿用 ver0_2/otbn/mlkem768
 *
 * 依赖 ntt.s 内的共享辅助例程: _load_64x32 / _store_64x32 / _transpose_8x8_w0w16
 */

.globl intt
.text
/**
 * Compute the backward number-theoretic transform (INTT) for a polynomial f(x)
 * in Z_q / (X^256+1) for ML-KEM-1024 (q = 3329) in constant time.
 *
 * Implements Algorithm 10 (NTT^-1) of FIPS 203.
 * The input coefficients are in bit-reversed ordering and the output is in
 * standard ordering, scaled by 128^-1 mod q.
 * The modulus q needs to be provided in the MOD[31:0] register alongside the
 * Montgomery constant mu = -q^-1 mod 2^32 in MOD[63:32].
 *
 * This routine can be in-place if x2 = x3.
 *
 * @param[in] x2: DMEM address of input polynomial (256 coefficients).
 * @param[out] x3: DMEM address of output polynomial (256 coefficients).
 *
 * Clobbered WDRs: w0-w16, w30, w31.
 */
intt:
  /* Push clobbered general-purpose registers onto the stack. */
  .irp reg, x4, x5, x6, x7, x20
    sw \reg, 0(x31)
    addi x31, x31, 4
  .endr

  la x4, _inv_twiddles
  addi x6, x2, 0
  addi x7, x3, 0

  /* Iteration 1: Coefficients 0-127 (Half 1).
     Iteration 2: Coefficients 128-255 (Half 2). */
  loopi 2, 212

    /* Load 128 coefficients from DMEM into w0-15. */
    addi x20, x6, 0
    li   x5, 0
    jal  x1, _load_64x32
    jal  x1, _load_64x32

    /* Transpose w0-15 before running Stages 1 and 2. */
    jal x1, _transpose_8x8_w0w16

    /*
     * Stage 1: dist = 2 (transposed)
     */
    bn.lid x5, 0(x4++)
    bn.subvm.8S w30,  w0,  w2
    bn.addvm.8S  w0,  w0,  w2
    bn.mulvm.8S  w2, w30, w16
    bn.addvm.8S  w2,  w2, w31
    bn.subvm.8S w30,  w1,  w3
    bn.addvm.8S  w1,  w1,  w3
    bn.mulvm.8S  w3, w30, w16
    bn.addvm.8S  w3,  w3, w31

    bn.lid x5, 0(x4++)
    bn.subvm.8S w30,  w4,  w6
    bn.addvm.8S  w4,  w4,  w6
    bn.mulvm.8S  w6, w30, w16
    bn.addvm.8S  w6,  w6, w31
    bn.subvm.8S w30,  w5,  w7
    bn.addvm.8S  w5,  w5,  w7
    bn.mulvm.8S  w7, w30, w16
    bn.addvm.8S  w7,  w7, w31

    bn.lid x5, 0(x4++)
    bn.subvm.8S w30,  w8, w10
    bn.addvm.8S  w8,  w8, w10
    bn.mulvm.8S w10, w30, w16
    bn.addvm.8S w10, w10, w31
    bn.subvm.8S w30,  w9, w11
    bn.addvm.8S  w9,  w9, w11
    bn.mulvm.8S w11, w30, w16
    bn.addvm.8S w11, w11, w31

    bn.lid x5, 0(x4++)
    bn.subvm.8S w30, w12, w14
    bn.addvm.8S w12, w12, w14
    bn.mulvm.8S w14, w30, w16
    bn.addvm.8S w14, w14, w31
    bn.subvm.8S w30, w13, w15
    bn.addvm.8S w13, w13, w15
    bn.mulvm.8S w15, w30, w16
    bn.addvm.8S w15, w15, w31

    /*
     * Stage 2: dist = 4 (transposed)
     */
    bn.lid x5, 0(x4++)
    bn.subvm.8S w30,  w0,  w4
    bn.addvm.8S  w0,  w0,  w4
    bn.mulvm.8S  w4, w30, w16
    bn.addvm.8S  w4,  w4, w31
    bn.subvm.8S w30,  w1,  w5
    bn.addvm.8S  w1,  w1,  w5
    bn.mulvm.8S  w5, w30, w16
    bn.addvm.8S  w5,  w5, w31
    bn.subvm.8S w30,  w2,  w6
    bn.addvm.8S  w2,  w2,  w6
    bn.mulvm.8S  w6, w30, w16
    bn.addvm.8S  w6,  w6, w31
    bn.subvm.8S w30,  w3,  w7
    bn.addvm.8S  w3,  w3,  w7
    bn.mulvm.8S  w7, w30, w16
    bn.addvm.8S  w7,  w7, w31

    bn.lid x5, 0(x4++)
    bn.subvm.8S w30,  w8, w12
    bn.addvm.8S  w8,  w8, w12
    bn.mulvm.8S w12, w30, w16
    bn.addvm.8S w12, w12, w31
    bn.subvm.8S w30,  w9, w13
    bn.addvm.8S  w9,  w9, w13
    bn.mulvm.8S w13, w30, w16
    bn.addvm.8S w13, w13, w31
    bn.subvm.8S w30, w10, w14
    bn.addvm.8S w10, w10, w14
    bn.mulvm.8S w14, w30, w16
    bn.addvm.8S w14, w14, w31
    bn.subvm.8S w30, w11, w15
    bn.addvm.8S w11, w11, w15
    bn.mulvm.8S w15, w30, w16
    bn.addvm.8S w15, w15, w31

    /* Transpose w0-15 back before Stage 3. */
    jal x1, _transpose_8x8_w0w16

    /*
     * Stage 3: dist = 8 (untransposed)
     */
    bn.lid x5, 0(x4++)
    bn.subvm.8S  w30,  w0,  w1
    bn.addvm.8S   w0,  w0,  w1
    bn.mulvml.8S  w1, w30, w16, 0
    bn.addvm.8S   w1,  w1, w31
    bn.subvm.8S  w30,  w2,  w3
    bn.addvm.8S   w2,  w2,  w3
    bn.mulvml.8S  w3, w30, w16, 1
    bn.addvm.8S   w3,  w3, w31
    bn.subvm.8S  w30,  w4,  w5
    bn.addvm.8S   w4,  w4,  w5
    bn.mulvml.8S  w5, w30, w16, 2
    bn.addvm.8S   w5,  w5, w31
    bn.subvm.8S  w30,  w6,  w7
    bn.addvm.8S   w6,  w6,  w7
    bn.mulvml.8S  w7, w30, w16, 3
    bn.addvm.8S   w7,  w7, w31
    bn.subvm.8S  w30,  w8,  w9
    bn.addvm.8S   w8,  w8,  w9
    bn.mulvml.8S  w9, w30, w16, 4
    bn.addvm.8S   w9,  w9, w31
    bn.subvm.8S  w30, w10, w11
    bn.addvm.8S w10, w10, w11
    bn.mulvml.8S w11, w30, w16, 5
    bn.addvm.8S w11, w11, w31
    bn.subvm.8S  w30, w12, w13
    bn.addvm.8S w12, w12, w13
    bn.mulvml.8S w13, w30, w16, 6
    bn.addvm.8S w13, w13, w31
    bn.subvm.8S  w30, w14, w15
    bn.addvm.8S w14, w14, w15
    bn.mulvml.8S w15, w30, w16, 7
    bn.addvm.8S w15, w15, w31

    /*
     * Stages 4, 5, 6 (untransposed)
     */
    bn.lid x5, 0(x4++)

    /* Stage 4: dist = 16 */
    bn.subvm.8S  w30,  w0,  w2
    bn.addvm.8S   w0,  w0,  w2
    bn.mulvml.8S  w2, w30, w16, 0
    bn.addvm.8S   w2,  w2, w31
    bn.subvm.8S  w30,  w1,  w3
    bn.addvm.8S   w1,  w1,  w3
    bn.mulvml.8S  w3, w30, w16, 0
    bn.addvm.8S   w3,  w3, w31
    bn.subvm.8S  w30,  w4,  w6
    bn.addvm.8S   w4,  w4,  w6
    bn.mulvml.8S  w6, w30, w16, 1
    bn.addvm.8S   w6,  w6, w31
    bn.subvm.8S  w30,  w5,  w7
    bn.addvm.8S   w5,  w5,  w7
    bn.mulvml.8S  w7, w30, w16, 1
    bn.addvm.8S   w7,  w7, w31
    bn.subvm.8S  w30,  w8, w10
    bn.addvm.8S   w8,  w8, w10
    bn.mulvml.8S w10, w30, w16, 2
    bn.addvm.8S w10, w10, w31
    bn.subvm.8S  w30,  w9, w11
    bn.addvm.8S   w9,  w9, w11
    bn.mulvml.8S w11, w30, w16, 2
    bn.addvm.8S w11, w11, w31
    bn.subvm.8S  w30, w12, w14
    bn.addvm.8S w12, w12, w14
    bn.mulvml.8S w14, w30, w16, 3
    bn.addvm.8S w14, w14, w31
    bn.subvm.8S  w30, w13, w15
    bn.addvm.8S w13, w13, w15
    bn.mulvml.8S w15, w30, w16, 3
    bn.addvm.8S w15, w15, w31

    /* Stage 5: dist = 32 */
    bn.subvm.8S  w30,  w0,  w4
    bn.addvm.8S   w0,  w0,  w4
    bn.mulvml.8S  w4, w30, w16, 4
    bn.addvm.8S   w4,  w4, w31
    bn.subvm.8S  w30,  w1,  w5
    bn.addvm.8S   w1,  w1,  w5
    bn.mulvml.8S  w5, w30, w16, 4
    bn.addvm.8S   w5,  w5, w31
    bn.subvm.8S  w30,  w2,  w6
    bn.addvm.8S   w2,  w2,  w6
    bn.mulvml.8S  w6, w30, w16, 4
    bn.addvm.8S   w6,  w6, w31
    bn.subvm.8S  w30,  w3,  w7
    bn.addvm.8S   w3,  w3,  w7
    bn.mulvml.8S  w7, w30, w16, 4
    bn.addvm.8S   w7,  w7, w31
    bn.subvm.8S  w30,  w8, w12
    bn.addvm.8S   w8,  w8, w12
    bn.mulvml.8S w12, w30, w16, 5
    bn.addvm.8S w12, w12, w31
    bn.subvm.8S  w30,  w9, w13
    bn.addvm.8S   w9,  w9, w13
    bn.mulvml.8S w13, w30, w16, 5
    bn.addvm.8S w13, w13, w31
    bn.subvm.8S  w30, w10, w14
    bn.addvm.8S w10, w10, w14
    bn.mulvml.8S w14, w30, w16, 5
    bn.addvm.8S w14, w14, w31
    bn.subvm.8S  w30, w11, w15
    bn.addvm.8S w11, w11, w15
    bn.mulvml.8S w15, w30, w16, 5
    bn.addvm.8S w15, w15, w31

    /* Stage 6: dist = 64 */
    bn.subvm.8S  w30,  w0,  w8
    bn.addvm.8S   w0,  w0,  w8
    bn.mulvml.8S  w8, w30, w16, 6
    bn.addvm.8S   w8,  w8, w31
    bn.subvm.8S  w30,  w1,  w9
    bn.addvm.8S   w1,  w1,  w9
    bn.mulvml.8S  w9, w30, w16, 6
    bn.addvm.8S   w9,  w9, w31
    bn.subvm.8S  w30,  w2, w10
    bn.addvm.8S   w2,  w2, w10
    bn.mulvml.8S w10, w30, w16, 6
    bn.addvm.8S w10, w10, w31
    bn.subvm.8S  w30,  w3, w11
    bn.addvm.8S   w3,  w3, w11
    bn.mulvml.8S w11, w30, w16, 6
    bn.addvm.8S w11, w11, w31
    bn.subvm.8S  w30,  w4, w12
    bn.addvm.8S   w4,  w4, w12
    bn.mulvml.8S w12, w30, w16, 6
    bn.addvm.8S w12, w12, w31
    bn.subvm.8S  w30,  w5, w13
    bn.addvm.8S   w5,  w5, w13
    bn.mulvml.8S w13, w30, w16, 6
    bn.addvm.8S w13, w13, w31
    bn.subvm.8S  w30,  w6, w14
    bn.addvm.8S   w6,  w6, w14
    bn.mulvml.8S w14, w30, w16, 6
    bn.addvm.8S w14, w14, w31
    bn.subvm.8S  w30,  w7, w15
    bn.addvm.8S   w7,  w7, w15
    bn.mulvml.8S w15, w30, w16, 6
    bn.addvm.8S w15, w15, w31

    /* Store 128 coefficients back to DMEM. */
    addi x20, x7, 0
    li   x5, 0
    jal  x1, _store_64x32
    jal  x1, _store_64x32

    /* Advance DMEM pointers for Half 2. */
    addi x6, x6, 512
    addi x7, x7, 512
    /* End of loop */

  /*
   * Stage 7 & Scaling Pass
   */
  addi x6, x3, 0

  /* Load Stage 7 twiddle (w16[0]) and post-INTT scaling factor (w16[1]). */
  bn.lid x5, 0(x4++)

  /* Iteration 1: Coefficients 0-63 and 128-191.
     Iteration 2: Coefficients 64-127 and 192-255. */
  loopi 2, 75

    /* Load 128 coefficients from DMEM (Chunk 0 & Chunk 2 in Iter 1; Chunk 1 & Chunk 3 in Iter 2). */
    addi x20, x6, 0
    li   x5, 0
    jal  x1, _load_64x32
    addi x20, x6, 512
    jal  x1, _load_64x32

    /* Stage 7 (GS butterfly, dist 128) */
    bn.subvm.8S  w30,  w0,  w8
    bn.addvm.8S   w0,  w0,  w8
    bn.mulvml.8S  w8, w30, w16, 0
    bn.addvm.8S   w8,  w8, w31
    bn.subvm.8S  w30,  w1,  w9
    bn.addvm.8S   w1,  w1,  w9
    bn.mulvml.8S  w9, w30, w16, 0
    bn.addvm.8S   w9,  w9, w31
    bn.subvm.8S  w30,  w2, w10
    bn.addvm.8S   w2,  w2, w10
    bn.mulvml.8S w10, w30, w16, 0
    bn.addvm.8S  w10, w10, w31
    bn.subvm.8S  w30,  w3, w11
    bn.addvm.8S   w3,  w3, w11
    bn.mulvml.8S w11, w30, w16, 0
    bn.addvm.8S  w11, w11, w31
    bn.subvm.8S  w30,  w4, w12
    bn.addvm.8S   w4,  w4, w12
    bn.mulvml.8S w12, w30, w16, 0
    bn.addvm.8S  w12, w12, w31
    bn.subvm.8S  w30,  w5, w13
    bn.addvm.8S   w5,  w5, w13
    bn.mulvml.8S w13, w30, w16, 0
    bn.addvm.8S  w13, w13, w31
    bn.subvm.8S  w30,  w6, w14
    bn.addvm.8S   w6,  w6, w14
    bn.mulvml.8S w14, w30, w16, 0
    bn.addvm.8S  w14, w14, w31
    bn.subvm.8S  w30,  w7, w15
    bn.addvm.8S   w7,  w7, w15
    bn.mulvml.8S w15, w30, w16, 0
    bn.addvm.8S  w15, w15, w31

    /* Scaling pass: multiply by f = 128^-1 * R mod 3329 (w16[1]) */
    bn.mulvml.8S  w0,  w0, w16, 1
    bn.mulvml.8S  w1,  w1, w16, 1
    bn.mulvml.8S  w2,  w2, w16, 1
    bn.mulvml.8S  w3,  w3, w16, 1
    bn.mulvml.8S  w4,  w4, w16, 1
    bn.mulvml.8S  w5,  w5, w16, 1
    bn.mulvml.8S  w6,  w6, w16, 1
    bn.mulvml.8S  w7,  w7, w16, 1
    bn.mulvml.8S  w8,  w8, w16, 1
    bn.mulvml.8S  w9,  w9, w16, 1
    bn.mulvml.8S w10, w10, w16, 1
    bn.mulvml.8S w11, w11, w16, 1
    bn.mulvml.8S w12, w12, w16, 1
    bn.mulvml.8S w13, w13, w16, 1
    bn.mulvml.8S w14, w14, w16, 1
    bn.mulvml.8S w15, w15, w16, 1

    bn.addvm.8S  w0,  w0, w31
    bn.addvm.8S  w1,  w1, w31
    bn.addvm.8S  w2,  w2, w31
    bn.addvm.8S  w3,  w3, w31
    bn.addvm.8S  w4,  w4, w31
    bn.addvm.8S  w5,  w5, w31
    bn.addvm.8S  w6,  w6, w31
    bn.addvm.8S  w7,  w7, w31
    bn.addvm.8S  w8,  w8, w31
    bn.addvm.8S  w9,  w9, w31
    bn.addvm.8S w10, w10, w31
    bn.addvm.8S w11, w11, w31
    bn.addvm.8S w12, w12, w31
    bn.addvm.8S w13, w13, w31
    bn.addvm.8S w14, w14, w31
    bn.addvm.8S w15, w15, w31

    /* Store transformed & scaled coefficients back to DMEM. */
    addi x20, x6, 0
    li   x5, 0
    jal  x1, _store_64x32
    addi x20, x6, 512
    jal  x1, _store_64x32

    addi x6, x6, 256
    /* End of loop */

  /* Restore clobbered general-purpose registers. */
  .irp reg, x20, x7, x6, x5, x4
    addi x31, x31, -4
    lw \reg, 0(x31)
  .endr

  ret

.section .data
.balign 32
.globl _inv_twiddles
_inv_twiddles:
/* Half 1 */
/* Stage 1 (transposed, 4 WDRs) */
.word 0x00000732
.word 0x000001ba
.word 0x00000a36
.word 0x00000551
.word 0x00000bc3
.word 0x00000254
.word 0x0000000f
.word 0x00000258
.word 0x0000040b
.word 0x000005ac
.word 0x00000498
.word 0x000001b2
.word 0x00000219
.word 0x000005e2
.word 0x000002b9
.word 0x000004e0
.word 0x0000096d
.word 0x00000cec
.word 0x00000457
.word 0x0000048b
.word 0x00000588
.word 0x0000002f
.word 0x000003e9
.word 0x0000005c
.word 0x000009b9
.word 0x00000bcb
.word 0x00000cab
.word 0x00000c92
.word 0x00000758
.word 0x000007aa
.word 0x0000015f
.word 0x000002d4
/* Stage 2 (transposed, 2 WDRs) */
.word 0x000001f4
.word 0x00000410
.word 0x0000001a
.word 0x00000674
.word 0x00000840
.word 0x00000109
.word 0x000004e7
.word 0x00000265
.word 0x000009df
.word 0x00000702
.word 0x000004ba
.word 0x0000073b
.word 0x000003d4
.word 0x00000029
.word 0x00000a15
.word 0x00000668
/* Stage 3 (1 WDR) */
.word 0x00000431
.word 0x0000093d
.word 0x00000b9c
.word 0x0000056c
.word 0x000008c2
.word 0x0000074b
.word 0x00000c36
.word 0x000005a2
/* Stages 4-6 (1 WDR) */
.word 0x000004e4
.word 0x000009a7
.word 0x00000091
.word 0x000008fb
.word 0x00000489
.word 0x00000012
.word 0x00000358
.word 0x00000000
/* Half 2 */
/* Stage 1 (transposed, 4 WDRs) */
.word 0x0000063c
.word 0x0000024d
.word 0x000005d7
.word 0x00000c87
.word 0x00000c0e
.word 0x0000010b
.word 0x00000bb3
.word 0x00000cd5
.word 0x00000101
.word 0x00000125
.word 0x000006f2
.word 0x000004bb
.word 0x000002b5
.word 0x00000440
.word 0x00000621
.word 0x00000b16
.word 0x0000051e
.word 0x000009a1
.word 0x000003ee
.word 0x00000124
.word 0x00000c14
.word 0x000001fb
.word 0x000004d4
.word 0x00000b12
.word 0x0000080b
.word 0x000009a0
.word 0x0000069d
.word 0x00000474
.word 0x00000132
.word 0x000008cd
.word 0x000000ae
.word 0x0000012e
/* Stage 2 (transposed, 2 WDRs) */
.word 0x000008f8
.word 0x000006b1
.word 0x000007a5
.word 0x00000794
.word 0x000001c9
.word 0x00000865
.word 0x00000663
.word 0x00000aaf
.word 0x00000a45
.word 0x00000751
.word 0x000007a9
.word 0x00000692
.word 0x0000040e
.word 0x00000b8e
.word 0x00000624
.word 0x0000070d
/* Stage 3 (1 WDR) */
.word 0x00000301
.word 0x000007cf
.word 0x0000031f
.word 0x00000040
.word 0x00000174
.word 0x00000a4e
.word 0x0000061c
.word 0x00000911
/* Stages 4-6 (1 WDR) */
.word 0x000000ff
.word 0x00000746
.word 0x000000d5
.word 0x000004da
.word 0x00000c5b
.word 0x000002d0
.word 0x00000565
.word 0x00000000
/* Stage 7 and Scaling (1 WDR) */
.word 0x000003b6
.word 0x000005a1
.word 0x00000000
.word 0x00000000
.word 0x00000000
.word 0x00000000
.word 0x00000000
.word 0x00000000
