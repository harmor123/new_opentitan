/* Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.globl ntt
ntt:
  /* save fp to stack */
  addi sp, sp, -32
  sw   fp, 0(sp)

  addi fp, sp, 0
    
  /* Adjust sp to accomodate local variables */
  addi sp, sp, -512



  /* Set up constants for input/twiddle factors */
  li x23, 16

  li x15, 8
  li x16, 9
  li x17, 10
  li x18, 11
  li x19, 12
  li x20, 13
  li x21, 14
  li x22, 15

  li x4, 31
  li x5, 30
  li x6, 29
  li x7, 28
  li x3, 27
  li x9, 26
  li x13, 25
  li x14, 24
  li x24, 17
  li x25, 18
  li x26, 19
  li x29, 21
  li x30, 23

  /* Zero out one register */
  bn.xor w18, w18, w18
  /* 0xFFFFFFFF for masking */
  bn.addi w17, w18, 1
  bn.rshi w17, w17, w18 >> 224
  bn.subi w17, w17, 1 

  /* Set second WLEN/4 quad word to modulus */
  la     x27, modulus
  li     x28, 20 /* Load q to w20 */
  bn.lid x28, 0(x27)
  bn.and w20, w20, w17
  bn.or  w22, w18, w20 << 128
  /* Load alpha to w22.1 */
  bn.addi w20, w18, 1
  bn.or   w22, w22, w20 << 64
  /* Load mask to w22.3 */
  bn.or w22, w22, w17 << 192

  /* We can process 16 coefficients each iteration and need to process N=256, meaning we require 16 iterations. */
  /* Load coefficients into buffer registers */
  bn.lid x4, 0(x10)
  bn.lid x5, 32(x10)
  bn.lid x6, 64(x10)
  bn.lid x7, 96(x10)
  bn.lid x3, 128(x10)
  bn.lid x9, 160(x10)
  bn.lid x13, 192(x10)
  bn.lid x14, 224(x10)
  bn.lid x24, 256(x10)
  bn.lid x25, 288(x10)
  bn.lid x26, 320(x10)
  bn.lid x29, 352(x10)
  bn.lid x30, 384(x10) 

  LOOPI 8, 555
    bn.lid x23, 0(x11)
    /* Extract coefficients from buffer registers into working state */
    bn.and w0, w31, w22 >> 208
    bn.and w1, w30, w22 >> 208
    bn.and w2, w29, w22 >> 208
    bn.and w3, w28, w22 >> 208
    bn.and w4, w27, w22 >> 208
    bn.and w5, w26, w22 >> 208
    bn.and w6, w25, w22 >> 208
    bn.and w7, w24, w22 >> 208
    bn.and w8, w17, w22 >> 208
    bn.and w9, w18, w22 >> 208
    bn.and w10, w19, w22 >> 208
    bn.and w11, w21, w22 >> 208
    bn.and w12, w23, w22 >> 208

    /* Load remaining coefficients using 32-bit loads */
    /* Coeff 13 */
    lw     x27, 416(x10)
    sw     x27, -448(fp)
    bn.lid x20, -448(x8)
    bn.and w13, w13, w22 >> 208

    /* Coeff 14 */
    lw     x27, 448(x10)
    sw     x27, -480(fp)
    bn.lid x21, -480(x8)
    bn.and w14, w14, w22 >> 208

    /* Coeff 15 */
    lw     x27, 480(x10)
    sw     x27, -512(fp)
    bn.lid x22, -512(x8)
    bn.and w15, w15, w22 >> 208

    /* Layer 1 */

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w8, w8.0, w16.0, 192 /* a*bq' */
    bn.and          w8, w8, w22
    bn.add          w8, w22, w8 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w8, w8.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w8 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w8, w0, w20
    bn.addm w0, w0, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w9, w9.0, w16.0, 192 /* a*bq' */
    bn.and          w9, w9, w22
    bn.add          w9, w22, w9 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w9, w9.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w9 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w9, w1, w20
    bn.addm w1, w1, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w10, w10.0, w16.0, 192 /* a*bq' */
    bn.and          w10, w10, w22
    bn.add          w10, w22, w10 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w10, w10.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w10 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w10, w2, w20
    bn.addm w2, w2, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w11, w11.0, w16.0, 192 /* a*bq' */
    bn.and          w11, w11, w22
    bn.add          w11, w22, w11 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w11, w11.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w11 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w11, w3, w20
    bn.addm w3, w3, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w12, w12.0, w16.0, 192 /* a*bq' */
    bn.and          w12, w12, w22
    bn.add          w12, w22, w12 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w12, w12.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w12 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w12, w4, w20
    bn.addm w4, w4, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w13, w13.0, w16.0, 192 /* a*bq' */
    bn.and          w13, w13, w22
    bn.add          w13, w22, w13 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w13, w13.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w13 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w13, w5, w20
    bn.addm w5, w5, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w14, w14.0, w16.0, 192 /* a*bq' */
    bn.and          w14, w14, w22
    bn.add          w14, w22, w14 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w14, w14.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w14 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w14, w6, w20
    bn.addm w6, w6, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w15, w15.0, w16.0, 192 /* a*bq' */
    bn.and          w15, w15, w22
    bn.add          w15, w22, w15 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w15, w15.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w15 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w15, w7, w20
    bn.addm w7, w7, w20

    /* Layer 2 */

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w4, w4.0, w16.1, 192 /* a*bq' */
    bn.and          w4, w4, w22
    bn.add          w4, w22, w4 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w4, w4.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w4 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w4, w0, w20
    bn.addm w0, w0, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w5, w5.0, w16.1, 192 /* a*bq' */
    bn.and          w5, w5, w22
    bn.add          w5, w22, w5 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w5, w5.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w5 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w5, w1, w20
    bn.addm w1, w1, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w6, w6.0, w16.1, 192 /* a*bq' */
    bn.and          w6, w6, w22
    bn.add          w6, w22, w6 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w6, w6.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w6 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w6, w2, w20
    bn.addm w2, w2, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w7, w7.0, w16.1, 192 /* a*bq' */
    bn.and          w7, w7, w22
    bn.add          w7, w22, w7 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w7, w7.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w7 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w7, w3, w20
    bn.addm w3, w3, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w12, w12.0, w16.2, 192 /* a*bq' */
    bn.and          w12, w12, w22
    bn.add          w12, w22, w12 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w12, w12.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w12 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w12, w8, w20
    bn.addm w8, w8, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w13, w13.0, w16.2, 192 /* a*bq' */
    bn.and          w13, w13, w22
    bn.add          w13, w22, w13 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w13, w13.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w13 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w13, w9, w20
    bn.addm w9, w9, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w14, w14.0, w16.2, 192 /* a*bq' */
    bn.and          w14, w14, w22
    bn.add          w14, w22, w14 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w14, w14.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w14 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w14, w10, w20
    bn.addm w10, w10, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w15, w15.0, w16.2, 192 /* a*bq' */
    bn.and          w15, w15, w22
    bn.add          w15, w22, w15 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w15, w15.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w15 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w15, w11, w20
    bn.addm w11, w11, w20

    /* Layer 3 */

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w2, w2.0, w16.3, 192 /* a*bq' */
    bn.and          w2, w2, w22
    bn.add          w2, w22, w2 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w2, w2.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w2 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w2, w0, w20
    bn.addm w0, w0, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w3, w3.0, w16.3, 192 /* a*bq' */
    bn.and          w3, w3, w22
    bn.add          w3, w22, w3 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w3, w3.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w3 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w3, w1, w20
    bn.addm w1, w1, w20

    bn.lid x23, 32(x11)

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w6, w6.0, w16.0, 192 /* a*bq' */
    bn.and          w6, w6, w22
    bn.add          w6, w22, w6 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w6, w6.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w6 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w6, w4, w20
    bn.addm w4, w4, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w7, w7.0, w16.0, 192 /* a*bq' */
    bn.and          w7, w7, w22
    bn.add          w7, w22, w7 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w7, w7.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w7 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w7, w5, w20
    bn.addm w5, w5, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w10, w10.0, w16.1, 192 /* a*bq' */
    bn.and          w10, w10, w22
    bn.add          w10, w22, w10 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w10, w10.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w10 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w10, w8, w20
    bn.addm w8, w8, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w11, w11.0, w16.1, 192 /* a*bq' */
    bn.and          w11, w11, w22
    bn.add          w11, w22, w11 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w11, w11.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w11 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w11, w9, w20
    bn.addm w9, w9, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w14, w14.0, w16.2, 192 /* a*bq' */
    bn.and          w14, w14, w22
    bn.add          w14, w22, w14 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w14, w14.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w14 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w14, w12, w20
    bn.addm w12, w12, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w15, w15.0, w16.2, 192 /* a*bq' */
    bn.and          w15, w15, w22
    bn.add          w15, w22, w15 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w15, w15.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w15 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w15, w13, w20
    bn.addm w13, w13, w20

    /* Layer 4 */

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w1, w1.0, w16.3, 192 /* a*bq' */
    bn.and          w1, w1, w22
    bn.add          w1, w22, w1 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w1, w1.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w1 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w1, w0, w20
    bn.addm w0, w0, w20

    bn.lid x23, 64(x11)

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w3, w3.0, w16.0, 192 /* a*bq' */
    bn.and          w3, w3, w22
    bn.add          w3, w22, w3 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w3, w3.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w3 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w3, w2, w20
    bn.addm w2, w2, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w5, w5.0, w16.1, 192 /* a*bq' */
    bn.and          w5, w5, w22
    bn.add          w5, w22, w5 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w5, w5.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w5 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w5, w4, w20
    bn.addm w4, w4, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w7, w7.0, w16.2, 192 /* a*bq' */
    bn.and          w7, w7, w22
    bn.add          w7, w22, w7 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w7, w7.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w7 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w7, w6, w20
    bn.addm w6, w6, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w9, w9.0, w16.3, 192 /* a*bq' */
    bn.and          w9, w9, w22
    bn.add          w9, w22, w9 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w9, w9.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w9 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w9, w8, w20
    bn.addm w8, w8, w20

    bn.lid x23, 96(x11)

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w11, w11.0, w16.0, 192 /* a*bq' */
    bn.and          w11, w11, w22
    bn.add          w11, w22, w11 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w11, w11.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w11 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w11, w10, w20
    bn.addm w10, w10, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w13, w13.0, w16.1, 192 /* a*bq' */
    bn.and          w13, w13, w22
    bn.add          w13, w22, w13 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w13, w13.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w13 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w13, w12, w20
    bn.addm w12, w12, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w15, w15.0, w16.2, 192 /* a*bq' */
    bn.and          w15, w15, w22
    bn.add          w15, w22, w15 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w15, w15.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w15 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w15, w14, w20
    bn.addm w14, w14, w20

    /* Shift result values into the top of buffer registers */
    /* implicitly removes the old value */
    bn.rshi w31, w0, w31 >> 16
    bn.rshi w30, w1, w30 >> 16
    bn.rshi w29, w2, w29 >> 16
    bn.rshi w28, w3, w28 >> 16
    bn.rshi w27, w4, w27 >> 16
    bn.rshi w26, w5, w26 >> 16
    bn.rshi w25, w6, w25 >> 16
    bn.rshi w24, w7, w24 >> 16
    bn.rshi w17, w8, w17 >> 16
    bn.rshi w18, w9, w18 >> 16
    bn.rshi w19, w10, w19 >> 16
    bn.rshi w21, w11, w21 >> 16
    bn.rshi w23, w12, w23 >> 16

    /* Store unbuffered values */
    /* Coeff13 */
    bn.sid x20, -416(x8)
    lw     x27, -416(fp)
    sw     x27, 416(x12)
    /* Coeff14 */
    bn.sid x21, -416(x8)
    lw     x27, -416(fp)
    sw     x27, 448(x12)
    /* Coeff15 */
    bn.sid x22, -416(x8)
    lw     x27, -416(fp)
    sw     x27, 480(x12)
    
    /* Go to next coefficient for the unbuffered loads/stores */
    bn.lid x23, 0(x11)
    /* Extract coefficients from buffer registers into working state */
    bn.and w0, w31, w22 >> 208
    bn.and w1, w30, w22 >> 208
    bn.and w2, w29, w22 >> 208
    bn.and w3, w28, w22 >> 208
    bn.and w4, w27, w22 >> 208
    bn.and w5, w26, w22 >> 208
    bn.and w6, w25, w22 >> 208
    bn.and w7, w24, w22 >> 208
    bn.and w8, w17, w22 >> 208
    bn.and w9, w18, w22 >> 208
    bn.and w10, w19, w22 >> 208
    bn.and w11, w21, w22 >> 208
    bn.and w12, w23, w22 >> 208

    /* Load remaining coefficients using 32-bit loads */
    /* Coeff 13 */
    bn.lid  x20, -448(x8)
    bn.rshi w13, w22, w13 >> 16

    /* Coeff 14 */
    bn.lid  x21, -480(x8)
    bn.rshi w14, w22, w14 >> 16

    /* Coeff 15 */
    bn.lid  x22, -512(x8)
    bn.rshi w15, w22, w15 >> 16

    /* Layer 1 */

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w8, w8.0, w16.0, 192 /* a*bq' */
    bn.and          w8, w8, w22
    bn.add          w8, w22, w8 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w8, w8.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w8 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w8, w0, w20
    bn.addm w0, w0, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w9, w9.0, w16.0, 192 /* a*bq' */
    bn.and          w9, w9, w22
    bn.add          w9, w22, w9 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w9, w9.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w9 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w9, w1, w20
    bn.addm w1, w1, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w10, w10.0, w16.0, 192 /* a*bq' */
    bn.and          w10, w10, w22
    bn.add          w10, w22, w10 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w10, w10.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w10 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w10, w2, w20
    bn.addm w2, w2, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w11, w11.0, w16.0, 192 /* a*bq' */
    bn.and          w11, w11, w22
    bn.add          w11, w22, w11 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w11, w11.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w11 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w11, w3, w20
    bn.addm w3, w3, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w12, w12.0, w16.0, 192 /* a*bq' */
    bn.and          w12, w12, w22
    bn.add          w12, w22, w12 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w12, w12.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w12 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w12, w4, w20
    bn.addm w4, w4, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w13, w13.0, w16.0, 192 /* a*bq' */
    bn.and          w13, w13, w22
    bn.add          w13, w22, w13 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w13, w13.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w13 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w13, w5, w20
    bn.addm w5, w5, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w14, w14.0, w16.0, 192 /* a*bq' */
    bn.and          w14, w14, w22
    bn.add          w14, w22, w14 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w14, w14.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w14 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w14, w6, w20
    bn.addm w6, w6, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w15, w15.0, w16.0, 192 /* a*bq' */
    bn.and          w15, w15, w22
    bn.add          w15, w22, w15 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w15, w15.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w15 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w15, w7, w20
    bn.addm w7, w7, w20

    /* Layer 2 */

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w4, w4.0, w16.1, 192 /* a*bq' */
    bn.and          w4, w4, w22
    bn.add          w4, w22, w4 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w4, w4.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w4 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w4, w0, w20
    bn.addm w0, w0, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w5, w5.0, w16.1, 192 /* a*bq' */
    bn.and          w5, w5, w22
    bn.add          w5, w22, w5 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w5, w5.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w5 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w5, w1, w20
    bn.addm w1, w1, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w6, w6.0, w16.1, 192 /* a*bq' */
    bn.and          w6, w6, w22
    bn.add          w6, w22, w6 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w6, w6.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w6 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w6, w2, w20
    bn.addm w2, w2, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w7, w7.0, w16.1, 192 /* a*bq' */
    bn.and          w7, w7, w22
    bn.add          w7, w22, w7 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w7, w7.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w7 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w7, w3, w20
    bn.addm w3, w3, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w12, w12.0, w16.2, 192 /* a*bq' */
    bn.and          w12, w12, w22
    bn.add          w12, w22, w12 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w12, w12.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w12 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w12, w8, w20
    bn.addm w8, w8, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w13, w13.0, w16.2, 192 /* a*bq' */
    bn.and          w13, w13, w22
    bn.add          w13, w22, w13 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w13, w13.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w13 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w13, w9, w20
    bn.addm w9, w9, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w14, w14.0, w16.2, 192 /* a*bq' */
    bn.and          w14, w14, w22
    bn.add          w14, w22, w14 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w14, w14.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w14 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w14, w10, w20
    bn.addm w10, w10, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w15, w15.0, w16.2, 192 /* a*bq' */
    bn.and          w15, w15, w22
    bn.add          w15, w22, w15 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w15, w15.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w15 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w15, w11, w20
    bn.addm w11, w11, w20

    /* Layer 3 */

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w2, w2.0, w16.3, 192 /* a*bq' */
    bn.and          w2, w2, w22
    bn.add          w2, w22, w2 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w2, w2.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w2 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w2, w0, w20
    bn.addm w0, w0, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w3, w3.0, w16.3, 192 /* a*bq' */
    bn.and          w3, w3, w22
    bn.add          w3, w22, w3 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w3, w3.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w3 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w3, w1, w20
    bn.addm w1, w1, w20

    bn.lid x23, 32(x11)

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w6, w6.0, w16.0, 192 /* a*bq' */
    bn.and          w6, w6, w22
    bn.add          w6, w22, w6 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w6, w6.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w6 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w6, w4, w20
    bn.addm w4, w4, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w7, w7.0, w16.0, 192 /* a*bq' */
    bn.and          w7, w7, w22
    bn.add          w7, w22, w7 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w7, w7.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w7 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w7, w5, w20
    bn.addm w5, w5, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w10, w10.0, w16.1, 192 /* a*bq' */
    bn.and          w10, w10, w22
    bn.add          w10, w22, w10 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w10, w10.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w10 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w10, w8, w20
    bn.addm w8, w8, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w11, w11.0, w16.1, 192 /* a*bq' */
    bn.and          w11, w11, w22
    bn.add          w11, w22, w11 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w11, w11.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w11 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w11, w9, w20
    bn.addm w9, w9, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w14, w14.0, w16.2, 192 /* a*bq' */
    bn.and          w14, w14, w22
    bn.add          w14, w22, w14 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w14, w14.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w14 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w14, w12, w20
    bn.addm w12, w12, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w15, w15.0, w16.2, 192 /* a*bq' */
    bn.and          w15, w15, w22
    bn.add          w15, w22, w15 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w15, w15.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w15 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w15, w13, w20
    bn.addm w13, w13, w20

    /* Layer 4 */

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w1, w1.0, w16.3, 192 /* a*bq' */
    bn.and          w1, w1, w22
    bn.add          w1, w22, w1 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w1, w1.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w1 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w1, w0, w20
    bn.addm w0, w0, w20

    bn.lid x23, 64(x11)

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w3, w3.0, w16.0, 192 /* a*bq' */
    bn.and          w3, w3, w22
    bn.add          w3, w22, w3 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w3, w3.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w3 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w3, w2, w20
    bn.addm w2, w2, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w5, w5.0, w16.1, 192 /* a*bq' */
    bn.and          w5, w5, w22
    bn.add          w5, w22, w5 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w5, w5.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w5 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w5, w4, w20
    bn.addm w4, w4, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w7, w7.0, w16.2, 192 /* a*bq' */
    bn.and          w7, w7, w22
    bn.add          w7, w22, w7 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w7, w7.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w7 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w7, w6, w20
    bn.addm w6, w6, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w9, w9.0, w16.3, 192 /* a*bq' */
    bn.and          w9, w9, w22
    bn.add          w9, w22, w9 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w9, w9.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w9 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w9, w8, w20
    bn.addm w8, w8, w20

    bn.lid x23, 96(x11)

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w11, w11.0, w16.0, 192 /* a*bq' */
    bn.and          w11, w11, w22
    bn.add          w11, w22, w11 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w11, w11.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w11 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w11, w10, w20
    bn.addm w10, w10, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w13, w13.0, w16.1, 192 /* a*bq' */
    bn.and          w13, w13, w22
    bn.add          w13, w22, w13 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w13, w13.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w13 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w13, w12, w20
    bn.addm w12, w12, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w15, w15.0, w16.2, 192 /* a*bq' */
    bn.and          w15, w15, w22
    bn.add          w15, w22, w15 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w15, w15.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w15 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w15, w14, w20
    bn.addm w14, w14, w20

    /* Shift result values into the top of buffer registers */
    /* implicitly removes the old value */
    bn.rshi w31, w0, w31 >> 16
    bn.rshi w30, w1, w30 >> 16
    bn.rshi w29, w2, w29 >> 16
    bn.rshi w28, w3, w28 >> 16
    bn.rshi w27, w4, w27 >> 16
    bn.rshi w26, w5, w26 >> 16
    bn.rshi w25, w6, w25 >> 16
    bn.rshi w24, w7, w24 >> 16
    bn.rshi w17, w8, w17 >> 16
    bn.rshi w18, w9, w18 >> 16
    bn.rshi w19, w10, w19 >> 16
    bn.rshi w21, w11, w21 >> 16
    bn.rshi w23, w12, w23 >> 16

    /* Store unbuffered values */
    /* Coeff13 */
    bn.sid x20, -416(x8)
    lw     x27, -416(fp)
    sll    x27, x27, 16
    lw     x28, 416(x12)
    xor    x27, x27, x28
    sw     x27, 416(x12)
  
    /* Coeff14 */
    bn.sid x21, -416(x8)
    lw     x27, -416(fp)
    sll    x27, x27, 16
    lw     x28, 448(x12)
    xor    x27, x27, x28
    sw     x27, 448(x12)

    /* Coeff15 */
    bn.sid x22, -416(x8)
    lw     x27, -416(fp)
    sll    x27, x27, 16
    lw     x28, 480(x12)
    xor    x27, x27, x28
    sw     x27, 480(x12)
    
    /* Go to next coefficient for the unbuffered loads/stores */
    addi x10, x10, 4
    addi x12, x12, 4
    /* Inner Loop End */

  addi x12, x12, -32
  addi x10, x10, 480 /* -32 + 512 : for next input poly */
  /* Subtract 32 from offset to account for the increment inside the LOOP 16 */
  bn.sid x4, 0(x12)
  bn.sid x5, 32(x12)
  bn.sid x6, 64(x12)
  bn.sid x7, 96(x12)
  bn.sid x3, 128(x12)
  bn.sid x9, 160(x12)
  bn.sid x13, 192(x12)
  bn.sid x14, 224(x12)
  bn.sid x24, 256(x12)
  bn.sid x25, 288(x12)
  bn.sid x26, 320(x12)
  bn.sid x29, 352(x12)
  bn.sid x30, 384(x12)

  /* Set the twiddle pointer for layer 5 */
  addi x11, x11, 128

  /* Set up constants for input/twiddle factors */
  li x23, 16

  bn.xor  w18, w18, w18
  bn.addi w17, w18, 1
  bn.rshi w17, w17, w18 >> 240
  bn.subi w17, w17, 1 

  LOOPI 16, 204
    /* Load layer 5 + 2 layer 6 + 1 layer 7 twiddle */
    bn.lid x23, 0(x11++)

    /* Load Data */
    bn.lid  x4, 0(x12)
    bn.and  w0, w17, w31 >> 0
    bn.and  w1, w17, w31 >> 16
    bn.and  w2, w17, w31 >> 32
    bn.and  w3, w17, w31 >> 48
    bn.and  w4, w17, w31 >> 64
    bn.and  w5, w17, w31 >> 80
    bn.and  w6, w17, w31 >> 96
    bn.and  w7, w17, w31 >> 112
    bn.and  w8, w17, w31 >> 128
    bn.and  w9, w17, w31 >> 144
    bn.and  w10, w17, w31 >> 160
    bn.and  w11, w17, w31 >> 176
    bn.and  w12, w17, w31 >> 192
    bn.and  w13, w17, w31 >> 208
    bn.and  w14, w17, w31 >> 224
    bn.and  w15, w17, w31 >> 240

    /* Layer 5 */

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w8, w8.0, w16.0, 192 /* a*bq' */
    bn.and          w8, w8, w22
    bn.add          w8, w22, w8 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w8, w8.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w8 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w8, w0, w20
    bn.addm w0, w0, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w9, w9.0, w16.0, 192 /* a*bq' */
    bn.and          w9, w9, w22
    bn.add          w9, w22, w9 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w9, w9.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w9 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w9, w1, w20
    bn.addm w1, w1, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w10, w10.0, w16.0, 192 /* a*bq' */
    bn.and          w10, w10, w22
    bn.add          w10, w22, w10 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w10, w10.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w10 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w10, w2, w20
    bn.addm w2, w2, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w11, w11.0, w16.0, 192 /* a*bq' */
    bn.and          w11, w11, w22
    bn.add          w11, w22, w11 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w11, w11.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w11 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w11, w3, w20
    bn.addm w3, w3, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w12, w12.0, w16.0, 192 /* a*bq' */
    bn.and          w12, w12, w22
    bn.add          w12, w22, w12 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w12, w12.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w12 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w12, w4, w20
    bn.addm w4, w4, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w13, w13.0, w16.0, 192 /* a*bq' */
    bn.and          w13, w13, w22
    bn.add          w13, w22, w13 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w13, w13.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w13 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w13, w5, w20
    bn.addm w5, w5, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w14, w14.0, w16.0, 192 /* a*bq' */
    bn.and          w14, w14, w22
    bn.add          w14, w22, w14 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w14, w14.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w14 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w14, w6, w20
    bn.addm w6, w6, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w15, w15.0, w16.0, 192 /* a*bq' */
    bn.and          w15, w15, w22
    bn.add          w15, w22, w15 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w15, w15.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w15 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w15, w7, w20
    bn.addm w7, w7, w20

    /* Layer 6 */

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w4, w4.0, w16.1, 192 /* a*bq' */
    bn.and          w4, w4, w22
    bn.add          w4, w22, w4 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w4, w4.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w4 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w4, w0, w20
    bn.addm w0, w0, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w5, w5.0, w16.1, 192 /* a*bq' */
    bn.and          w5, w5, w22
    bn.add          w5, w22, w5 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w5, w5.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w5 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w5, w1, w20
    bn.addm w1, w1, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w6, w6.0, w16.1, 192 /* a*bq' */
    bn.and          w6, w6, w22
    bn.add          w6, w22, w6 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w6, w6.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w6 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w6, w2, w20
    bn.addm w2, w2, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w7, w7.0, w16.1, 192 /* a*bq' */
    bn.and          w7, w7, w22
    bn.add          w7, w22, w7 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w7, w7.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w7 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w7, w3, w20
    bn.addm w3, w3, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w12, w12.0, w16.2, 192 /* a*bq' */
    bn.and          w12, w12, w22
    bn.add          w12, w22, w12 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w12, w12.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w12 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w12, w8, w20
    bn.addm w8, w8, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w13, w13.0, w16.2, 192 /* a*bq' */
    bn.and          w13, w13, w22
    bn.add          w13, w22, w13 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w13, w13.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w13 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w13, w9, w20
    bn.addm w9, w9, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w14, w14.0, w16.2, 192 /* a*bq' */
    bn.and          w14, w14, w22
    bn.add          w14, w22, w14 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w14, w14.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w14 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w14, w10, w20
    bn.addm w10, w10, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w15, w15.0, w16.2, 192 /* a*bq' */
    bn.and          w15, w15, w22
    bn.add          w15, w22, w15 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w15, w15.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w15 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w15, w11, w20
    bn.addm w11, w11, w20

    /* Layer 7 */
    /* Load 4 factois of Layer 7 */
    bn.lid x23, 0(x11++)

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w2, w2.0, w16.0, 192 /* a*bq' */
    bn.and          w2, w2, w22
    bn.add          w2, w22, w2 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w2, w2.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w2 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w2, w0, w20
    bn.addm w0, w0, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w3, w3.0, w16.0, 192 /* a*bq' */
    bn.and          w3, w3, w22
    bn.add          w3, w22, w3 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w3, w3.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w3 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w3, w1, w20
    bn.addm w1, w1, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w6, w6.0, w16.1, 192 /* a*bq' */
    bn.and          w6, w6, w22
    bn.add          w6, w22, w6 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w6, w6.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w6 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w6, w4, w20
    bn.addm w4, w4, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w7, w7.0, w16.1, 192 /* a*bq' */
    bn.and          w7, w7, w22
    bn.add          w7, w22, w7 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w7, w7.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w7 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w7, w5, w20
    bn.addm w5, w5, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w10, w10.0, w16.2, 192 /* a*bq' */
    bn.and          w10, w10, w22
    bn.add          w10, w22, w10 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w10, w10.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w10 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w10, w8, w20
    bn.addm w8, w8, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w11, w11.0, w16.2, 192 /* a*bq' */
    bn.and          w11, w11, w22
    bn.add          w11, w22, w11 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w11, w11.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w11 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w11, w9, w20
    bn.addm w9, w9, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w14, w14.0, w16.3, 192 /* a*bq' */
    bn.and          w14, w14, w22
    bn.add          w14, w22, w14 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w14, w14.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w14 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w14, w12, w20
    bn.addm w12, w12, w20

    /* Plantard multiplication: Twiddle * coeff */
    bn.mulqacc.wo.z w15, w15.0, w16.3, 192 /* a*bq' */
    bn.and          w15, w15, w22
    bn.add          w15, w22, w15 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w15, w15.1, w22.2, 0 /* *q */
    bn.rshi         w20, w22, w15 >> 16 /* >> l */
    /* Butterfly */
    bn.subm w15, w13, w20
    bn.addm w13, w13, w20

    /* Reassemble WDRs and store */
    bn.rshi w31, w0, w31 >> 16
    bn.rshi w31, w1, w31 >> 16
    bn.rshi w31, w2, w31 >> 16
    bn.rshi w31, w3, w31 >> 16
    bn.rshi w31, w4, w31 >> 16
    bn.rshi w31, w5, w31 >> 16
    bn.rshi w31, w6, w31 >> 16
    bn.rshi w31, w7, w31 >> 16
    bn.rshi w31, w8, w31 >> 16
    bn.rshi w31, w9, w31 >> 16
    bn.rshi w31, w10, w31 >> 16
    bn.rshi w31, w11, w31 >> 16
    bn.rshi w31, w12, w31 >> 16
    bn.rshi w31, w13, w31 >> 16
    bn.rshi w31, w14, w31 >> 16
    bn.rshi w31, w15, w31 >> 16
    bn.sid  x4, 0(x12++)

  /* Zero w31 again */
  bn.xor w31, w31, w31

  /* sp <- fp */
  addi sp, fp, 0
  /* Pop ebp */
  lw fp, 0(sp)
  addi sp, sp, 32
  ret