/* Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */
.section .text

/**
 * Constant Time Dilithium inverse NTT (base)
 *
 * Returns: INTT(input)
 *
 * This implements the in-place INTT for Dilithium, where n=256, q=8380417.
 *
 * Flags: -
 *
 * @param[in]  x10: dptr_input, dmem pointer to first word of input polynomial
 * @param[in]  x11: dptr_tw, dmem pointer to array of twiddle factors,
      last element is n^{-1} mod q
 * @param[in]  w31: all-zero
 * @param[out] x10: dmem pointer to result
 *
 * clobbered registers: x4-x30, w0-w23, w30
 */
.global intt
intt:
  /* save fp to stack */
  addi sp, sp, -32
  sw   fp, 0(sp)

  addi fp, sp, 0
  
  /* Adjust sp to accomodate local variables */
  addi sp, sp, -512


  /* In place */
  /* addi x12, x10, 0 */

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

  bn.rshi w17, w18, w17 >> 16

  LOOPI 16, 204
    /* Load Data */
    bn.lid  x4, 0(x10)
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

    /* Layer 7, stride 2 */
    /* Load layer 7 4x */
    bn.lid x23, 0(x11++)

    bn.subm w20, w0, w2
    bn.addm w0, w0, w2
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.0, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w2, w22, w20 >> 16 /* >> l */
      
    bn.subm w20, w1, w3
    bn.addm w1, w1, w3
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.0, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w3, w22, w20 >> 16 /* >> l */
      
    bn.subm w20, w4, w6
    bn.addm w4, w4, w6
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.1, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w6, w22, w20 >> 16 /* >> l */
      
    bn.subm w20, w5, w7
    bn.addm w5, w5, w7
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.1, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w7, w22, w20 >> 16 /* >> l */
      
    bn.subm w20, w8, w10
    bn.addm w8, w8, w10
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.2, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w10, w22, w20 >> 16 /* >> l */
      
    bn.subm w20, w9, w11
    bn.addm w9, w9, w11
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.2, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w11, w22, w20 >> 16 /* >> l */
      
    bn.subm w20, w12, w14
    bn.addm w12, w12, w14
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.3, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w14, w22, w20 >> 16 /* >> l */
      
    bn.subm w20, w13, w15
    bn.addm w13, w13, w15
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.3, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w15, w22, w20 >> 16 /* >> l */

    /* Layer 6, stride 4 */
    /* Load layer 6 x2 + layer 5 x1 + pad */
    bn.lid x23, 0(x11++)

    bn.subm w20, w0, w4
    bn.addm w0, w0, w4
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.0, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w4, w22, w20 >> 16 /* >> l */
      
    bn.subm w20, w1, w5
    bn.addm w1, w1, w5
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.0, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w5, w22, w20 >> 16 /* >> l */
      
    bn.subm w20, w2, w6
    bn.addm w2, w2, w6
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.0, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w6, w22, w20 >> 16 /* >> l */
      
    bn.subm w20, w3, w7
    bn.addm w3, w3, w7
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.0, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w7, w22, w20 >> 16 /* >> l */
      
    bn.subm w20, w8, w12
    bn.addm w8, w8, w12
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.1, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w12, w22, w20 >> 16 /* >> l */
      
    bn.subm w20, w9, w13
    bn.addm w9, w9, w13
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.1, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w13, w22, w20 >> 16 /* >> l */
      
    bn.subm w20, w10, w14
    bn.addm w10, w10, w14
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.1, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w14, w22, w20 >> 16 /* >> l */
      
    bn.subm w20, w11, w15
    bn.addm w11, w11, w15
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.1, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w15, w22, w20 >> 16 /* >> l */

    /* Layer 5, stride 8 */   

    bn.subm w20, w0, w8
    bn.addm w0, w0, w8
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.2, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w8, w22, w20 >> 16 /* >> l */
      
    bn.subm w20, w1, w9
    bn.addm w1, w1, w9
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.2, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w9, w22, w20 >> 16 /* >> l */
      
    bn.subm w20, w2, w10
    bn.addm w2, w2, w10
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.2, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w10, w22, w20 >> 16 /* >> l */
      
    bn.subm w20, w3, w11
    bn.addm w3, w3, w11
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.2, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w11, w22, w20 >> 16 /* >> l */
      
    bn.subm w20, w4, w12
    bn.addm w4, w4, w12
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.2, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w12, w22, w20 >> 16 /* >> l */
      
    bn.subm w20, w5, w13
    bn.addm w5, w5, w13
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.2, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w13, w22, w20 >> 16 /* >> l */
      
    bn.subm w20, w6, w14
    bn.addm w6, w6, w14
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.2, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w14, w22, w20 >> 16 /* >> l */
      
    bn.subm w20, w7, w15
    bn.addm w7, w7, w15
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.2, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w15, w22, w20 >> 16 /* >> l */

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
    bn.sid x4, 0(x10++)

  /* Restore output pointer */
  addi x10, x10, -512

  /* Set up constants for input/twiddle factors */
  li x23, 16   

  /* We can process 16 coefficients each iteration and need to process N=256, meaning we require 16 iterations. */
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
  LOOPI 8, 635
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
#    bn.and w10, w18, w22 >> 208
    bn.and w10, w19, w22 >> 208
    bn.and w11, w21, w22 >> 208
    bn.and w12, w23, w22 >> 208

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

    bn.lid x23, 0(x11)

    /* Layer 4, stride 16 */    
    bn.subm w20, w0, w1
    bn.addm w0, w0, w1
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.0, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w1, w22, w20 >> 16 /* >> l */
    
    bn.subm w20, w2, w3
    bn.addm w2, w2, w3
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.1, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w3, w22, w20 >> 16 /* >> l */
    
    bn.subm w20, w4, w5
    bn.addm w4, w4, w5
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.2, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w5, w22, w20 >> 16 /* >> l */
    
    bn.subm w20, w6, w7
    bn.addm w6, w6, w7
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.3, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w7, w22, w20 >> 16 /* >> l */
    
    /* Load layer 4 twiddle 4x */
    bn.lid x23, 32(x11)

    bn.subm w20, w8, w9
    bn.addm w8, w8, w9
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.0, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w9, w22, w20 >> 16 /* >> l */
    
    bn.subm w20, w10, w11
    bn.addm w10, w10, w11
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.1, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w11, w22, w20 >> 16 /* >> l */
    
    bn.subm w20, w12, w13
    bn.addm w12, w12, w13
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.2, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w13, w22, w20 >> 16 /* >> l */
    
    bn.subm w20, w14, w15
    bn.addm w14, w14, w15
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.3, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w15, w22, w20 >> 16 /* >> l */

    /* Layer 3, stride 32 */
    /* Load layer 3 4x */
    bn.lid x23, 64(x11)

    bn.subm w20, w0, w2
    bn.addm w0, w0, w2
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.0, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w2, w22, w20 >> 16 /* >> l */
    
    bn.subm w20, w1, w3
    bn.addm w1, w1, w3
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.0, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w3, w22, w20 >> 16 /* >> l */
    
    bn.subm w20, w4, w6
    bn.addm w4, w4, w6
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.1, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w6, w22, w20 >> 16 /* >> l */
    
    bn.subm w20, w5, w7
    bn.addm w5, w5, w7
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.1, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w7, w22, w20 >> 16 /* >> l */
    
    bn.subm w20, w8, w10
    bn.addm w8, w8, w10
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.2, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w10, w22, w20 >> 16 /* >> l */
    
    bn.subm w20, w9, w11
    bn.addm w9, w9, w11
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.2, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w11, w22, w20 >> 16 /* >> l */
    
    bn.subm w20, w12, w14
    bn.addm w12, w12, w14
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.3, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w14, w22, w20 >> 16 /* >> l */
    
    bn.subm w20, w13, w15
    bn.addm w13, w13, w15
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.3, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w15, w22, w20 >> 16 /* >> l */

    /* Layer 2, stride 64 */
    /* Load layer 2 x2 + layer 1 x1 + pad */
    bn.lid x23, 96(x11)

    bn.subm w20, w0, w4
    bn.addm w0, w0, w4
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.0, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w4, w22, w20 >> 16 /* >> l */
    
    bn.subm w20, w1, w5
    bn.addm w1, w1, w5
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.0, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w5, w22, w20 >> 16 /* >> l */
    
    bn.subm w20, w2, w6
    bn.addm w2, w2, w6
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.0, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w6, w22, w20 >> 16 /* >> l */
    
    bn.subm w20, w3, w7
    bn.addm w3, w3, w7
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.0, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w7, w22, w20 >> 16 /* >> l */
    
    bn.subm w20, w8, w12
    bn.addm w8, w8, w12
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.1, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w12, w22, w20 >> 16 /* >> l */
    
    bn.subm w20, w9, w13
    bn.addm w9, w9, w13
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.1, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w13, w22, w20 >> 16 /* >> l */
    
    bn.subm w20, w10, w14
    bn.addm w10, w10, w14
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.1, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w14, w22, w20 >> 16 /* >> l */
    
    bn.subm w20, w11, w15
    bn.addm w11, w11, w15
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.1, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w15, w22, w20 >> 16 /* >> l */

    /* Layer 1, stride 128 */   

    bn.subm w20, w0, w8
    bn.addm w0, w0, w8
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.2, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w8, w22, w20 >> 16 /* >> l */
    
    bn.subm w20, w1, w9
    bn.addm w1, w1, w9
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.2, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w9, w22, w20 >> 16 /* >> l */
    
    bn.subm w20, w2, w10
    bn.addm w2, w2, w10
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.2, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w10, w22, w20 >> 16 /* >> l */
    
    bn.subm w20, w3, w11
    bn.addm w3, w3, w11
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.2, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w11, w22, w20 >> 16 /* >> l */
    
    bn.subm w20, w4, w12
    bn.addm w4, w4, w12
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.2, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w12, w22, w20 >> 16 /* >> l */
    
    bn.subm w20, w5, w13
    bn.addm w5, w5, w13
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.2, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w13, w22, w20 >> 16 /* >> l */
    
    bn.subm w20, w6, w14
    bn.addm w6, w6, w14
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.2, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w14, w22, w20 >> 16 /* >> l */
    
    bn.subm w20, w7, w15
    bn.addm w7, w7, w15
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.2, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w15, w22, w20 >> 16 /* >> l */

    /* Mul ninv */
    bn.mulqacc.wo.z w20, w0.0, w16.3, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w0, w22, w20 >> 16 /* >> l */

    bn.mulqacc.wo.z w20, w1.0, w16.3, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w1, w22, w20 >> 16 /* >> l */

    bn.mulqacc.wo.z w20, w2.0, w16.3, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w2, w22, w20 >> 16 /* >> l */

    bn.mulqacc.wo.z w20, w3.0, w16.3, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w3, w22, w20 >> 16 /* >> l */

    bn.mulqacc.wo.z w20, w4.0, w16.3, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w4, w22, w20 >> 16 /* >> l */

    bn.mulqacc.wo.z w20, w5.0, w16.3, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w5, w22, w20 >> 16 /* >> l */

    bn.mulqacc.wo.z w20, w6.0, w16.3, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w6, w22, w20 >> 16 /* >> l */

    bn.mulqacc.wo.z w20, w7.0, w16.3, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w7, w22, w20 >> 16 /* >> l */

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
#    bn.rshi w18, w10, w18 >> 16    
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
#    bn.and w10, w18, w22 >> 208    
    bn.and w10, w19, w22 >> 208
    bn.and w11, w21, w22 >> 208
    bn.and w12, w23, w22 >> 208

    /* Coeff 13 */
    bn.lid  x20, -448(x8)
    bn.rshi w13, w22, w13 >> 16

    /* Coeff 14 */
    bn.lid  x21, -480(x8)
    bn.rshi w14, w22, w14 >> 16

    /* Coeff 15 */
    bn.lid  x22, -512(x8)
    bn.rshi w15, w22, w15 >> 16

    bn.lid x23, 0(x11)

    /* Layer 4, stride 16 */    
    bn.subm w20, w0, w1
    bn.addm w0, w0, w1
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.0, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w1, w22, w20 >> 16 /* >> l */
    
    bn.subm w20, w2, w3
    bn.addm w2, w2, w3
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.1, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w3, w22, w20 >> 16 /* >> l */
    
    bn.subm w20, w4, w5
    bn.addm w4, w4, w5
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.2, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w5, w22, w20 >> 16 /* >> l */
    
    bn.subm w20, w6, w7
    bn.addm w6, w6, w7
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.3, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w7, w22, w20 >> 16 /* >> l */
    
    /* Load layer 4 twiddle 4x */
    bn.lid x23, 32(x11)

    bn.subm w20, w8, w9
    bn.addm w8, w8, w9
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.0, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w9, w22, w20 >> 16 /* >> l */
    
    bn.subm w20, w10, w11
    bn.addm w10, w10, w11
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.1, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w11, w22, w20 >> 16 /* >> l */
    
    bn.subm w20, w12, w13
    bn.addm w12, w12, w13
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.2, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w13, w22, w20 >> 16 /* >> l */
    
    bn.subm w20, w14, w15
    bn.addm w14, w14, w15
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.3, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w15, w22, w20 >> 16 /* >> l */

    /* Layer 3, stride 32 */
    /* Load layer 3 4x */
    bn.lid x23, 64(x11)

    bn.subm w20, w0, w2
    bn.addm w0, w0, w2
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.0, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w2, w22, w20 >> 16 /* >> l */
    
    bn.subm w20, w1, w3
    bn.addm w1, w1, w3
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.0, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w3, w22, w20 >> 16 /* >> l */
    
    bn.subm w20, w4, w6
    bn.addm w4, w4, w6
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.1, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w6, w22, w20 >> 16 /* >> l */
    
    bn.subm w20, w5, w7
    bn.addm w5, w5, w7
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.1, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w7, w22, w20 >> 16 /* >> l */
    
    bn.subm w20, w8, w10
    bn.addm w8, w8, w10
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.2, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w10, w22, w20 >> 16 /* >> l */
    
    bn.subm w20, w9, w11
    bn.addm w9, w9, w11
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.2, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w11, w22, w20 >> 16 /* >> l */
    
    bn.subm w20, w12, w14
    bn.addm w12, w12, w14
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.3, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w14, w22, w20 >> 16 /* >> l */
    
    bn.subm w20, w13, w15
    bn.addm w13, w13, w15
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.3, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w15, w22, w20 >> 16 /* >> l */

    /* Layer 2, stride 64 */
    /* Load layer 2 x2 + layer 1 x1 + pad */
    bn.lid x23, 96(x11)

    bn.subm w20, w0, w4
    bn.addm w0, w0, w4
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.0, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w4, w22, w20 >> 16 /* >> l */
    
    bn.subm w20, w1, w5
    bn.addm w1, w1, w5
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.0, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w5, w22, w20 >> 16 /* >> l */
    
    bn.subm w20, w2, w6
    bn.addm w2, w2, w6
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.0, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w6, w22, w20 >> 16 /* >> l */
    
    bn.subm w20, w3, w7
    bn.addm w3, w3, w7
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.0, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w7, w22, w20 >> 16 /* >> l */
    
    bn.subm w20, w8, w12
    bn.addm w8, w8, w12
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.1, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w12, w22, w20 >> 16 /* >> l */
    
    bn.subm w20, w9, w13
    bn.addm w9, w9, w13
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.1, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w13, w22, w20 >> 16 /* >> l */
    
    bn.subm w20, w10, w14
    bn.addm w10, w10, w14
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.1, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w14, w22, w20 >> 16 /* >> l */
    
    bn.subm w20, w11, w15
    bn.addm w11, w11, w15
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.1, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w15, w22, w20 >> 16 /* >> l */

    /* Layer 1, stride 128 */   

    bn.subm w20, w0, w8
    bn.addm w0, w0, w8
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.2, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w8, w22, w20 >> 16 /* >> l */
    
    bn.subm w20, w1, w9
    bn.addm w1, w1, w9
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.2, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w9, w22, w20 >> 16 /* >> l */
    
    bn.subm w20, w2, w10
    bn.addm w2, w2, w10
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.2, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w10, w22, w20 >> 16 /* >> l */
    
    bn.subm w20, w3, w11
    bn.addm w3, w3, w11
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.2, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w11, w22, w20 >> 16 /* >> l */
    
    bn.subm w20, w4, w12
    bn.addm w4, w4, w12
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.2, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w12, w22, w20 >> 16 /* >> l */
    
    bn.subm w20, w5, w13
    bn.addm w5, w5, w13
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.2, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w13, w22, w20 >> 16 /* >> l */
    
    bn.subm w20, w6, w14
    bn.addm w6, w6, w14
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.2, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w14, w22, w20 >> 16 /* >> l */
    
    bn.subm w20, w7, w15
    bn.addm w7, w7, w15
    /* Plantard multiplication: Twiddle * (a-b) */
    bn.mulqacc.wo.z w20, w20.0, w16.2, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w15, w22, w20 >> 16 /* >> l */

    /* Mul ninv */
    bn.mulqacc.wo.z w20, w0.0, w16.3, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w0, w22, w20 >> 16 /* >> l */

    bn.mulqacc.wo.z w20, w1.0, w16.3, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w1, w22, w20 >> 16 /* >> l */

    bn.mulqacc.wo.z w20, w2.0, w16.3, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w2, w22, w20 >> 16 /* >> l */

    bn.mulqacc.wo.z w20, w3.0, w16.3, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w3, w22, w20 >> 16 /* >> l */

    bn.mulqacc.wo.z w20, w4.0, w16.3, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w4, w22, w20 >> 16 /* >> l */

    bn.mulqacc.wo.z w20, w5.0, w16.3, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w5, w22, w20 >> 16 /* >> l */

    bn.mulqacc.wo.z w20, w6.0, w16.3, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w6, w22, w20 >> 16 /* >> l */

    bn.mulqacc.wo.z w20, w7.0, w16.3, 192 /* a*bq' */
    bn.and          w20, w20, w22
    bn.add          w20, w22, w20 >> 144 /* + 2^alpha = 2^8 */
    bn.mulqacc.wo.z w20, w20.1, w22.2, 0 /* *q */
    bn.rshi         w7, w22, w20 >> 16 /* >> l */

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
#    bn.rshi w18, w10, w18 >> 16    
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

  addi x12, x12, -32
  addi x10, x10, 480 /* for next input poly */
  /* Subtract 32 from offset to account for the increment inside the LOOP 8 */
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

  /* Zero w31 again */
  bn.xor w31, w31, w31

  addi x12, x12, 512 /* for next output poly */

  /* sp <- fp */
  addi sp, fp, 0
  /* Pop ebp */
  lw   fp, 0(sp)
  addi sp, sp, 32
  ret