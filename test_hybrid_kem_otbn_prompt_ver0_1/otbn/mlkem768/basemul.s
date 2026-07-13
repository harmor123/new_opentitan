/* Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.globl basemul
basemul:
  /* save fp to stack */
  addi sp, sp, -32
  sw   fp, 0(sp)

  addi fp, sp, 0

  /* Set up constants for input/twiddle factors */
  li x4, 0
  li x5, 1
  li x18, 10
  li x19, 11
  li x25, 15
  li x26, 16

  /* Zero out one register */
  bn.xor w31, w31, w31
  /* 0xFFFFFFFF for masking */
  bn.addi w13, w31, 1
  bn.rshi w13, w13, w31 >> 224
  bn.subi w13, w13, 1 

  li     x22, 12 /* w12 */
  /*Set zero quad word to 1/q % 2^32 */
  la     x21, qinv
  bn.lid x22, 0(x21)
  bn.or  w14, w31, w12
  /* Set second WLEN/4 quad word to modulus */
  la     x21, modulus
  bn.lid x22, 0(x21)
  bn.or  w14, w14, w12 << 128
  /* Load alpha to w14.1 */
  bn.addi w12, w31, 1
  bn.or   w14, w14, w12 << 64
  /* Load w13 to w14.3 */
  bn.or w14, w14, w13 << 192

  /* 0xFFFF for masking */
  bn.addi w17, w31, 1
  bn.rshi w17, w17, w31 >> 240
  bn.subi w17, w17, 1
  LOOPI 4, 1
    bn.rshi w13, w17, w13 >> 64

  /* Point to right Twiddle factors for basemul in the twiddles_ntt_base */
  addi x28, x28, 160

  LOOPI 16, 281
    bn.lid x4, 0(x29++)
    bn.lid x5, 0(x11++)
    bn.lid x25, 0(x28++) /* Load twiddle factors: 4 twds */

    bn.and  w2, w13, w0 /* a0, a4, a8, a12 */
    bn.and  w3, w13, w0 >> 16 /* a1, a5, a9, a13 */
    bn.and  w4, w13, w0 >> 32 /* a2, a6, a10, a14 */
    bn.and  w5, w13, w0 >> 48 /* a3, a7, a11, a15 */

    bn.and  w6, w13, w1 /* b0, b4, b8, b12 */
    bn.and  w7, w13, w1 >> 16 /* b1, b5, b9, b13 */
    bn.and  w8, w13, w1 >> 32 /* b2, b6, b10, b14 */
    bn.and  w9, w13, w1 >> 48 /* b3, b7, b11, b15 */

    /*-----------------------------------------*/
    /* Plantard multiplication: a0*b0 */
    bn.mulqacc.wo.z w12, w2.0, w6.0, 0 /* a0*b0 */
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192      /* a0*b0*qinv % 2^64 */
    bn.and          w12, w12, w14               /* a0*b0*qinv % 2^32 */
    bn.add          w12, w14, w12 >> 144        
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w10, w31, w12 >> 16

    /* Plantard multiplication: a1*b1 */
    bn.mulqacc.wo.z w12, w3.0, w7.0, 0 
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192      
    bn.and          w12, w12, w14               
    bn.add          w12, w14, w12 >> 144        
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w11, w31, w12 >> 16

    /* Plantard multiplication: a1*b1*tf */
    bn.mulqacc.wo.z w12, w11.0, w15.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w11, w31, w12 >> 16

    /* r0 = a1*b1*tf + a0*b0 */
    bn.addm w10, w10, w11 
    bn.rshi w16, w10, w16 >> 16

    /* Plantard multiplication: a0*b1 */
    bn.mulqacc.wo.z w12, w2.0, w7.0, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w10, w31, w12 >> 16

    /* Plantard multiplication: a1*b0 */
    bn.mulqacc.wo.z w12, w3.0, w6.0, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w11, w31, w12 >> 16

    /* r1 = a0*b1 + a1*b0 */
    bn.addm w10, w10, w11 
    bn.rshi w16, w10, w16 >> 16

    /* Plantard multiplication: a2*b2 */
    bn.mulqacc.wo.z w12, w4.0, w8.0, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w10, w31, w12 >> 16

    /* Plantard multiplication: a3*b3 */
    bn.mulqacc.wo.z w12, w5.0, w9.0, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w11, w31, w12 >> 16
    
    /* -a3*b3 */
    bn.subm w11, w31, w11 
    
    /* Plantard multiplication: a3*b3*(-tf) */
    bn.mulqacc.wo.z w12, w11.0, w15.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w11, w31, w12 >> 16

    /* r2 = a3*b3*(-tf) + a2*b2 */
    bn.addm w10, w10, w11 
    bn.rshi w16, w10, w16 >> 16

    /* Plantard multiplication: a2*b3 */
    bn.mulqacc.wo.z w12, w4.0, w9.0, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w10, w31, w12 >> 16

    /* Plantard multiplication: a3*b2 */
    bn.mulqacc.wo.z w12, w5.0, w8.0, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w11, w31, w12 >> 16

    /* r3 = a2*b3 + a3*b2 */
    bn.addm w10, w10, w11 
    bn.rshi w16, w10, w16 >> 16

    /*-----------------------------------------*/
    /* Plantard multiplication: a4*b4 */
    bn.mulqacc.wo.z w12, w2.1, w6.1, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w10, w31, w12 >> 16

    /* Plantard multiplication: a5*b5 */
    bn.mulqacc.wo.z w12, w3.1, w7.1, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w11, w31, w12 >> 16

    /* Plantard multiplication: a5*b5*tf */
    bn.mulqacc.wo.z w12, w11.0, w15.1, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w11, w31, w12 >> 16

    /* r4 = a5*b5*tf + a4*b4 */
    bn.addm w10, w10, w11 
    bn.rshi w16, w10, w16 >> 16

    /* Plantard multiplication: a4*b5 */
    bn.mulqacc.wo.z w12, w2.1, w7.1, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w10, w31, w12 >> 16

    /* Plantard multiplication: a5*b4 */
    bn.mulqacc.wo.z w12, w3.1, w6.1, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w11, w31, w12 >> 16

    /* r5 = a4*b5 + a5*b4 */
    bn.addm w10, w10, w11 
    bn.rshi w16, w10, w16 >> 16

    /* Plantard multiplication: a6*b6 */
    bn.mulqacc.wo.z w12, w4.1, w8.1, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w10, w31, w12 >> 16

    /* Plantard multiplication: a7*b7 */
    bn.mulqacc.wo.z w12, w5.1, w9.1, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w11, w31, w12 >> 16
    
    /* -a7*b7 */
    bn.subm w11, w31, w11  
    
    /* Plantard multiplication: a7*b7*(-tf) */
    bn.mulqacc.wo.z w12, w11.0, w15.1, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w11, w31, w12 >> 16

    /* r6 = a7*b7*(-tf) + a6*b6 */
    bn.addm w10, w10, w11 
    bn.rshi w16, w10, w16 >> 16

    /* Plantard multiplication: a6*b7 */
    bn.mulqacc.wo.z w12, w4.1, w9.1, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w10, w31, w12 >> 16

    /* Plantard multiplication: a7*b6 */
    bn.mulqacc.wo.z w12, w5.1, w8.1, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w11, w31, w12 >> 16

    /* r7 = a6*b7 + a7*b6 */
    bn.addm w10, w10, w11 
    bn.rshi w16, w10, w16 >> 16

    /*-----------------------------------------*/
    /* Plantard multiplication: a8*b8 */
    bn.mulqacc.wo.z w12, w2.2, w6.2, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w10, w31, w12 >> 16

    /* Plantard multiplication: a9*b9 */
    bn.mulqacc.wo.z w12, w3.2, w7.2, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w11, w31, w12 >> 16

    /* Plantard multiplication: a9*b9*tf */
    bn.mulqacc.wo.z w12, w11.0, w15.2, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w11, w31, w12 >> 16

    /* r8 = a9*b9*tf + a8*b8 */
    bn.addm w10, w10, w11 
    bn.rshi w16, w10, w16 >> 16

    /* Plantard multiplication: a8*b9 */
    bn.mulqacc.wo.z w12, w2.2, w7.2, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w10, w31, w12 >> 16

    /* Plantard multiplication: a9*b8 */
    bn.mulqacc.wo.z w12, w3.2, w6.2, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w11, w31, w12 >> 16

    /* r9 = a8*b9 + a9*b8 */
    bn.addm w10, w10, w11 
    bn.rshi w16, w10, w16 >> 16

    /* Plantard multiplication: a10*b10 */
    bn.mulqacc.wo.z w12, w4.2, w8.2, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w10, w31, w12 >> 16

    /* Plantard multiplication: a11*b11 */
    bn.mulqacc.wo.z w12, w5.2, w9.2, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w11, w31, w12 >> 16
    
    /* -a11*b11 */
    bn.subm w11, w31, w11  
    
    /* Plantard multiplication: a11*b11*(-tf) */
    bn.mulqacc.wo.z w12, w11.0, w15.2, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w11, w31, w12 >> 16

    /* r10 = a11*b11*(-tf) + a10*b10 */
    bn.addm w10, w10, w11 
    bn.rshi w16, w10, w16 >> 16

    /* Plantard multiplication: a10*b11 */
    bn.mulqacc.wo.z w12, w4.2, w9.2, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w10, w31, w12 >> 16

    /* Plantard multiplication: a11*b10 */
    bn.mulqacc.wo.z w12, w5.2, w8.2, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w11, w31, w12 >> 16

    /* r11 = a10*b11 + a11*b10 */
    bn.addm w10, w10, w11 
    bn.rshi w16, w10, w16 >> 16

    /*-----------------------------------------*/
    /* Plantard multiplication: a12*b12 */
    bn.mulqacc.wo.z w12, w2.3, w6.3, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w10, w31, w12 >> 16

    /* Plantard multiplication: a13*b13 */
    bn.mulqacc.wo.z w12, w3.3, w7.3, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w11, w31, w12 >> 16

    /* Plantard multiplication: a13*b13*tf */
    bn.mulqacc.wo.z w12, w11.0, w15.3, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w11, w31, w12 >> 16

    /* r12 = a13*b13*tf + a12*b12 */
    bn.addm w10, w10, w11 
    bn.rshi w16, w10, w16 >> 16

    /* Plantard multiplication: a12*b13 */
    bn.mulqacc.wo.z w12, w2.3, w7.3, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w10, w31, w12 >> 16

    /* Plantard multiplication: a13*b12 */
    bn.mulqacc.wo.z w12, w3.3, w6.3, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w11, w31, w12 >> 16

    /* r13 = a12*b13 + a13*b12 */
    bn.addm w10, w10, w11 
    bn.rshi w16, w10, w16 >> 16

    /* Plantard multiplication: a14*b14 */
    bn.mulqacc.wo.z w12, w4.3, w8.3, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w10, w31, w12 >> 16

    /* Plantard multiplication: a15*b15 */
    bn.mulqacc.wo.z w12, w5.3, w9.3, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w11, w31, w12 >> 16
    
    /* -a15*b15 */
    bn.subm w11, w31, w11  
    
    /* Plantard multiplication: a15*b15*(-tf) */
    bn.mulqacc.wo.z w12, w11.0, w15.3, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w11, w31, w12 >> 16

    /* r14 = a15*b15*(-tf) + a14*b14 */
    bn.addm w10, w10, w11 
    bn.rshi w16, w10, w16 >> 16

    /* Plantard multiplication: a14*b15 */
    bn.mulqacc.wo.z w12, w4.3, w9.3, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w10, w31, w12 >> 16

    /* Plantard multiplication: a15*b14 */
    bn.mulqacc.wo.z w12, w5.3, w8.3, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w11, w31, w12 >> 16

    /* r15 = a14*b15 + a15*b14 */
    bn.addm w10, w10, w11 
    bn.rshi w16, w10, w16 >> 16

    bn.sid x26, 0(x13++)

    /* Adjust Twiddle pointer */
    addi x28, x28, 32

  /* Zero w31 again */
  bn.xor w31, w31, w31

  /* sp <- fp */
  addi sp, fp, 0
  /* Pop ebp */
  lw fp, 0(sp)
  addi sp, sp, 32
  ret

.globl basemul_acc
basemul_acc:
  /* save fp to stack */
  addi sp, sp, -32
  sw   fp, 0(sp)

  addi fp, sp, 0

  /* Set up constants for input/twiddle factors */
  li x4, 0
  li x5, 1
  li x18, 10
  li x19, 11
  li x25, 15
  li x26, 16
  li x27, 18

  /* Zero out one register */
  bn.xor w31, w31, w31
  /* 0xFFFFFFFF for masking */
  bn.addi w13, w31, 1
  bn.rshi w13, w13, w31 >> 224
  bn.subi w13, w13, 1 

  li     x22, 12 /* w12 */
  /*Set zero quad word to 1/q % 2^32 */
  la     x21, qinv
  bn.lid x22, 0(x21)
  bn.or  w14, w31, w12
  /* Set second WLEN/4 quad word to modulus */
  la     x21, modulus
  bn.lid x22, 0(x21)
  bn.or  w14, w14, w12 << 128
  /* Load alpha to w14.1 */
  bn.addi w12, w31, 1
  bn.or   w14, w14, w12 << 64
  /* Load w13 to w14.3 */
  bn.or w14, w14, w13 << 192

  /* 0xFFFF for masking */
  bn.addi w17, w31, 1
  bn.rshi w17, w17, w31 >> 240
  bn.subi w17, w17, 1
  bn.add  w19, w31, w17
  LOOPI 4, 1
    bn.rshi w13, w17, w13 >> 64

  addi x28, x28, 160

  LOOPI 16, 283
    bn.lid x4, 0(x29++)
    bn.lid x5, 0(x11++)
    bn.lid x25, 0(x28++) /* Load twiddle factors: 4 twds */

    bn.and  w2, w13, w0 /* a0, a4, a8, a12 */
    bn.and  w3, w13, w0 >> 16 /* a1, a5, a9, a13 */
    bn.and  w4, w13, w0 >> 32 /* a2, a6, a10, a14 */
    bn.and  w5, w13, w0 >> 48 /* a3, a7, a11, a15 */

    bn.and  w6, w13, w1 /* b0, b4, b8, b12 */
    bn.and  w7, w13, w1 >> 16 /* b1, b5, b9, b13 */
    bn.and  w8, w13, w1 >> 32 /* b2, b6, b10, b14 */
    bn.and  w9, w13, w1 >> 48 /* b3, b7, b11, b15 */

    /*-----------------------------------------*/
    /* Plantard multiplication: a0*b0 */
    bn.mulqacc.wo.z w12, w2.0, w6.0, 0 /* a0*b0 */
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192      /* a0*b0*qinv % 2^64 */
    bn.and          w12, w12, w14               /* a0*b0*qinv % 2^32 */
    bn.add          w12, w14, w12 >> 144        
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w10, w31, w12 >> 16

    /* Plantard multiplication: a1*b1 */
    bn.mulqacc.wo.z w12, w3.0, w7.0, 0 
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192      
    bn.and          w12, w12, w14               
    bn.add          w12, w14, w12 >> 144        
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w11, w31, w12 >> 16

    /* Plantard multiplication: a1*b1*tf */
    bn.mulqacc.wo.z w12, w11.0, w15.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w11, w31, w12 >> 16

    /* r0 = a1*b1*tf + a0*b0 */
    bn.addm w10, w10, w11 
    bn.rshi w16, w10, w16 >> 16

    /* Plantard multiplication: a0*b1 */
    bn.mulqacc.wo.z w12, w2.0, w7.0, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w10, w31, w12 >> 16

    /* Plantard multiplication: a1*b0 */
    bn.mulqacc.wo.z w12, w3.0, w6.0, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w11, w31, w12 >> 16

    /* r1 = a0*b1 + a1*b0 */
    bn.addm w10, w10, w11 
    bn.rshi w16, w10, w16 >> 16

    /* Plantard multiplication: a2*b2 */
    bn.mulqacc.wo.z w12, w4.0, w8.0, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w10, w31, w12 >> 16

    /* Plantard multiplication: a3*b3 */
    bn.mulqacc.wo.z w12, w5.0, w9.0, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w11, w31, w12 >> 16
    
    /* -a3*b3 */
    bn.subm w11, w31, w11  
    
    /* Plantard multiplication: a3*b3*(-tf) */
    bn.mulqacc.wo.z w12, w11.0, w15.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w11, w31, w12 >> 16

    /* r2 = a3*b3*(-tf) + a2*b2 */
    bn.addm w10, w10, w11 
    bn.rshi w16, w10, w16 >> 16

    /* Plantard multiplication: a2*b3 */
    bn.mulqacc.wo.z w12, w4.0, w9.0, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w10, w31, w12 >> 16

    /* Plantard multiplication: a3*b2 */
    bn.mulqacc.wo.z w12, w5.0, w8.0, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w11, w31, w12 >> 16

    /* r3 = a2*b3 + a3*b2 */
    bn.addm w10, w10, w11 
    bn.rshi w16, w10, w16 >> 16

    /*-----------------------------------------*/
    /* Plantard multiplication: a4*b4 */
    bn.mulqacc.wo.z w12, w2.1, w6.1, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w10, w31, w12 >> 16

    /* Plantard multiplication: a5*b5 */
    bn.mulqacc.wo.z w12, w3.1, w7.1, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w11, w31, w12 >> 16

    /* Plantard multiplication: a5*b5*tf */
    bn.mulqacc.wo.z w12, w11.0, w15.1, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w11, w31, w12 >> 16

    /* r4 = a5*b5*tf + a4*b4 */
    bn.addm w10, w10, w11 
    bn.rshi w16, w10, w16 >> 16

    /* Plantard multiplication: a4*b5 */
    bn.mulqacc.wo.z w12, w2.1, w7.1, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w10, w31, w12 >> 16

    /* Plantard multiplication: a5*b4 */
    bn.mulqacc.wo.z w12, w3.1, w6.1, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w11, w31, w12 >> 16

    /* r5 = a4*b5 + a5*b4 */
    bn.addm w10, w10, w11 
    bn.rshi w16, w10, w16 >> 16

    /* Plantard multiplication: a6*b6 */
    bn.mulqacc.wo.z w12, w4.1, w8.1, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w10, w31, w12 >> 16

    /* Plantard multiplication: a7*b7 */
    bn.mulqacc.wo.z w12, w5.1, w9.1, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w11, w31, w12 >> 16
    
    /* -a7*b7 */
    bn.subm w11, w31, w11  
    
    /* Plantard multiplication: a7*b7*(-tf) */
    bn.mulqacc.wo.z w12, w11.0, w15.1, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w11, w31, w12 >> 16

    /* r6 = a7*b7*(-tf) + a6*b6 */
    bn.addm w10, w10, w11 
    bn.rshi w16, w10, w16 >> 16

    /* Plantard multiplication: a6*b7 */
    bn.mulqacc.wo.z w12, w4.1, w9.1, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w10, w31, w12 >> 16

    /* Plantard multiplication: a7*b6 */
    bn.mulqacc.wo.z w12, w5.1, w8.1, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w11, w31, w12 >> 16

    /* r7 = a6*b7 + a7*b6 */
    bn.addm w10, w10, w11 
    bn.rshi w16, w10, w16 >> 16

    /*-----------------------------------------*/
    /* Plantard multiplication: a8*b8 */
    bn.mulqacc.wo.z w12, w2.2, w6.2, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w10, w31, w12 >> 16

    /* Plantard multiplication: a9*b9 */
    bn.mulqacc.wo.z w12, w3.2, w7.2, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w11, w31, w12 >> 16

    /* Plantard multiplication: a9*b9*tf */
    bn.mulqacc.wo.z w12, w11.0, w15.2, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w11, w31, w12 >> 16

    /* r8 = a9*b9*tf + a8*b8 */
    bn.addm w10, w10, w11 
    bn.rshi w16, w10, w16 >> 16

    /* Plantard multiplication: a8*b9 */
    bn.mulqacc.wo.z w12, w2.2, w7.2, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w10, w31, w12 >> 16

    /* Plantard multiplication: a9*b8 */
    bn.mulqacc.wo.z w12, w3.2, w6.2, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w11, w31, w12 >> 16

    /* r9 = a8*b9 + a9*b8 */
    bn.addm w10, w10, w11 
    bn.rshi w16, w10, w16 >> 16

    /* Plantard multiplication: a10*b10 */
    bn.mulqacc.wo.z w12, w4.2, w8.2, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w10, w31, w12 >> 16

    /* Plantard multiplication: a11*b11 */
    bn.mulqacc.wo.z w12, w5.2, w9.2, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w11, w31, w12 >> 16
    
    /* -a11*b11 */
    bn.subm w11, w31, w11  
    
    /* Plantard multiplication: a11*b11*(-tf) */
    bn.mulqacc.wo.z w12, w11.0, w15.2, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w11, w31, w12 >> 16

    /* r10 = a11*b11*(-tf) + a10*b10 */
    bn.addm w10, w10, w11 
    bn.rshi w16, w10, w16 >> 16

    /* Plantard multiplication: a10*b11 */
    bn.mulqacc.wo.z w12, w4.2, w9.2, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w10, w31, w12 >> 16

    /* Plantard multiplication: a11*b10 */
    bn.mulqacc.wo.z w12, w5.2, w8.2, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w11, w31, w12 >> 16

    /* r11 = a10*b11 + a11*b10 */
    bn.addm w10, w10, w11 
    bn.rshi w16, w10, w16 >> 16

    /*-----------------------------------------*/
    /* Plantard multiplication: a12*b12 */
    bn.mulqacc.wo.z w12, w2.3, w6.3, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w10, w31, w12 >> 16

    /* Plantard multiplication: a13*b13 */
    bn.mulqacc.wo.z w12, w3.3, w7.3, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w11, w31, w12 >> 16

    /* Plantard multiplication: a13*b13*tf */
    bn.mulqacc.wo.z w12, w11.0, w15.3, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w11, w31, w12 >> 16

    /* r12 = a13*b13*tf + a12*b12 */
    bn.addm w10, w10, w11 
    bn.rshi w16, w10, w16 >> 16

    /* Plantard multiplication: a12*b13 */
    bn.mulqacc.wo.z w12, w2.3, w7.3, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w10, w31, w12 >> 16

    /* Plantard multiplication: a13*b12 */
    bn.mulqacc.wo.z w12, w3.3, w6.3, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w11, w31, w12 >> 16

    /* r13 = a12*b13 + a13*b12 */
    bn.addm w10, w10, w11 
    bn.rshi w16, w10, w16 >> 16

    /* Plantard multiplication: a14*b14 */
    bn.mulqacc.wo.z w12, w4.3, w8.3, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w10, w31, w12 >> 16

    /* Plantard multiplication: a15*b15 */
    bn.mulqacc.wo.z w12, w5.3, w9.3, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w11, w31, w12 >> 16
    
    /* -a15*b15 */
    bn.subm w11, w31, w11  
    
    /* Plantard multiplication: a15*b15*(-tf) */
    bn.mulqacc.wo.z w12, w11.0, w15.3, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w11, w31, w12 >> 16

    /* r14 = a15*b15*(-tf) + a14*b14 */
    bn.addm w10, w10, w11 
    bn.rshi w16, w10, w16 >> 16

    /* Plantard multiplication: a14*b15 */
    bn.mulqacc.wo.z w12, w4.3, w9.3, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w10, w31, w12 >> 16

    /* Plantard multiplication: a15*b14 */
    bn.mulqacc.wo.z w12, w5.3, w8.3, 0
    bn.mulqacc.wo.z w12, w12.0, w14.0, 192
    bn.and          w12, w12, w14
    bn.add          w12, w14, w12 >> 144
    bn.mulqacc.wo.z w12, w12.1, w14.2, 0
    bn.rshi         w11, w31, w12 >> 16

    /* r15 = a14*b15 + a15*b14 */
    bn.addm w10, w10, w11 
    bn.rshi w16, w10, w16 >> 16

    /* accumulating */
    bn.lid x27, 0(x13)
    bn.add w16, w16,w18
    bn.sid x26, 0(x13++)

    addi x28, x28, 32

  /* Zero w31 again */
  bn.xor w31, w31, w31

  /* sp <- fp */
  addi sp, fp, 0
  /* Pop ebp */
  lw fp, 0(sp)
  addi sp, sp, 32
  ret