.globl ntt
ntt:
  /* Set up wide registers for input and intermediate states */
  li x4, 0
  li x5, 1
  li x6, 2
  li x7, 3
  li x3, 4
  li x9, 5
  li x13, 6
  li x14, 7
  li x15, 8
  li x16, 9
  li x17, 10
  li x18, 11
  li x19, 12
  li x20, 13
  li x21, 14
  li x22, 15

  /* Set up wide registers for input and twiddle factors */
  li x23, 17

  /* Load twiddle factors for Layers 1--4 */
  bn.lid x23, 0(x11)
  
  /* Compute NTT Layers 1--4 */
  /* Load input */
  bn.lid x4,  0(x10++)
  bn.lid x5,  0(x10++)
  bn.lid x6,  0(x10++)
  bn.lid x7,  0(x10++)
  bn.lid x3,  0(x10++)
  bn.lid x9,  0(x10++)
  bn.lid x13, 0(x10++)
  bn.lid x14, 0(x10++)
  bn.lid x15, 0(x10++)
  bn.lid x16, 0(x10++)
  bn.lid x17, 0(x10++)
  bn.lid x18, 0(x10++)
  bn.lid x19, 0(x10++)
  bn.lid x20, 0(x10++)
  bn.lid x21, 0(x10++)
  bn.lid x22, 0(x10++)

  /* Layer 1, stride 128 */

  bn.mulv.l.16H.acc.z.lo w30, w8, sw1.0
  bn.mulv.l.16H.lo       w30, w30, sw0.2
  bn.mulv.l.16H.acc.hi   w30, w30, sw0.0
  bn.subvm.16H           w8, w0, w30
  bn.addvm.16H           w0, w0, w30

  bn.mulv.l.16H.acc.z.lo w30, w9, sw1.0
  bn.mulv.l.16H.lo       w30, w30, sw0.2
  bn.mulv.l.16H.acc.hi   w30, w30, sw0.0
  bn.subvm.16H           w9, w1, w30
  bn.addvm.16H           w1, w1, w30

  bn.mulv.l.16H.acc.z.lo w30, w10, sw1.0
  bn.mulv.l.16H.lo       w30, w30, sw0.2
  bn.mulv.l.16H.acc.hi   w30, w30, sw0.0
  bn.subvm.16H           w10, w2, w30
  bn.addvm.16H           w2, w2, w30

  bn.mulv.l.16H.acc.z.lo w30, w11, sw1.0
  bn.mulv.l.16H.lo       w30, w30, sw0.2
  bn.mulv.l.16H.acc.hi   w30, w30, sw0.0
  bn.subvm.16H           w11, w3, w30
  bn.addvm.16H           w3, w3, w30

  bn.mulv.l.16H.acc.z.lo w30, w12, sw1.0
  bn.mulv.l.16H.lo       w30, w30, sw0.2
  bn.mulv.l.16H.acc.hi   w30, w30, sw0.0
  bn.subvm.16H           w12, w4, w30
  bn.addvm.16H           w4, w4, w30

  bn.mulv.l.16H.acc.z.lo w30, w13, sw1.0
  bn.mulv.l.16H.lo       w30, w30, sw0.2
  bn.mulv.l.16H.acc.hi   w30, w30, sw0.0
  bn.subvm.16H           w13, w5, w30
  bn.addvm.16H           w5, w5, w30

  bn.mulv.l.16H.acc.z.lo w30, w14, sw1.0
  bn.mulv.l.16H.lo       w30, w30, sw0.2
  bn.mulv.l.16H.acc.hi   w30, w30, sw0.0
  bn.subvm.16H           w14, w6, w30
  bn.addvm.16H           w6, w6, w30

  bn.mulv.l.16H.acc.z.lo w30, w15, sw1.0
  bn.mulv.l.16H.lo       w30, w30, sw0.2
  bn.mulv.l.16H.acc.hi   w30, w30, sw0.0
  bn.subvm.16H           w15, w7, w30
  bn.addvm.16H           w7, w7, w30

  /* Layer 2, stride 64 */

  bn.mulv.l.16H.acc.z.lo w30, w4, sw1.1
  bn.mulv.l.16H.lo       w30, w30, sw0.2
  bn.mulv.l.16H.acc.hi   w30, w30, sw0.0
  bn.subvm.16H           w4, w0, w30
  bn.addvm.16H           w0, w0, w30

  bn.mulv.l.16H.acc.z.lo w30, w5, sw1.1
  bn.mulv.l.16H.lo       w30, w30, sw0.2
  bn.mulv.l.16H.acc.hi   w30, w30, sw0.0
  bn.subvm.16H           w5, w1, w30
  bn.addvm.16H           w1, w1, w30

  bn.mulv.l.16H.acc.z.lo w30, w6, sw1.1
  bn.mulv.l.16H.lo       w30, w30, sw0.2
  bn.mulv.l.16H.acc.hi   w30, w30, sw0.0
  bn.subvm.16H           w6, w2, w30
  bn.addvm.16H           w2, w2, w30

  bn.mulv.l.16H.acc.z.lo w30, w7, sw1.1
  bn.mulv.l.16H.lo       w30, w30, sw0.2
  bn.mulv.l.16H.acc.hi   w30, w30, sw0.0
  bn.subvm.16H           w7, w3, w30
  bn.addvm.16H           w3, w3, w30

  bn.mulv.l.16H.acc.z.lo w30, w12, sw1.2
  bn.mulv.l.16H.lo       w30, w30, sw0.2
  bn.mulv.l.16H.acc.hi   w30, w30, sw0.0
  bn.subvm.16H           w12, w8, w30
  bn.addvm.16H           w8, w8, w30

  bn.mulv.l.16H.acc.z.lo w30, w13, sw1.2
  bn.mulv.l.16H.lo       w30, w30, sw0.2
  bn.mulv.l.16H.acc.hi   w30, w30, sw0.0
  bn.subvm.16H           w13, w9, w30
  bn.addvm.16H           w9, w9, w30

  bn.mulv.l.16H.acc.z.lo w30, w14, sw1.2
  bn.mulv.l.16H.lo       w30, w30, sw0.2
  bn.mulv.l.16H.acc.hi   w30, w30, sw0.0
  bn.subvm.16H           w14, w10, w30
  bn.addvm.16H           w10, w10, w30

  bn.mulv.l.16H.acc.z.lo w30, w15, sw1.2
  bn.mulv.l.16H.lo       w30, w30, sw0.2
  bn.mulv.l.16H.acc.hi   w30, w30, sw0.0
  bn.subvm.16H           w15, w11, w30
  bn.addvm.16H           w11, w11, w30

  /* Layer 3, stride 32 */

  bn.mulv.l.16H.acc.z.lo w30, w2, sw1.3
  bn.mulv.l.16H.lo       w30, w30, sw0.2
  bn.mulv.l.16H.acc.hi   w30, w30, sw0.0
  bn.subvm.16H           w2, w0, w30
  bn.addvm.16H           w0, w0, w30

  bn.mulv.l.16H.acc.z.lo w30, w3, sw1.3
  bn.mulv.l.16H.lo       w30, w30, sw0.2
  bn.mulv.l.16H.acc.hi   w30, w30, sw0.0
  bn.subvm.16H           w3, w1, w30
  bn.addvm.16H           w1, w1, w30

  bn.mulv.l.16H.acc.z.lo w30, w6, sw1.4
  bn.mulv.l.16H.lo       w30, w30, sw0.2
  bn.mulv.l.16H.acc.hi   w30, w30, sw0.0
  bn.subvm.16H           w6, w4, w30
  bn.addvm.16H           w4, w4, w30

  bn.mulv.l.16H.acc.z.lo w30, w7, sw1.4
  bn.mulv.l.16H.lo       w30, w30, sw0.2
  bn.mulv.l.16H.acc.hi   w30, w30, sw0.0
  bn.subvm.16H           w7, w5, w30
  bn.addvm.16H           w5, w5, w30

  bn.mulv.l.16H.acc.z.lo w30, w10, sw1.5
  bn.mulv.l.16H.lo       w30, w30, sw0.2
  bn.mulv.l.16H.acc.hi   w30, w30, sw0.0
  bn.subvm.16H           w10, w8, w30
  bn.addvm.16H           w8, w8, w30

  bn.mulv.l.16H.acc.z.lo w30, w11, sw1.5
  bn.mulv.l.16H.lo       w30, w30, sw0.2
  bn.mulv.l.16H.acc.hi   w30, w30, sw0.0
  bn.subvm.16H           w11, w9, w30
  bn.addvm.16H           w9, w9, w30

  bn.mulv.l.16H.acc.z.lo w30, w14, sw1.6
  bn.mulv.l.16H.lo       w30, w30, sw0.2
  bn.mulv.l.16H.acc.hi   w30, w30, sw0.0
  bn.subvm.16H           w14, w12, w30
  bn.addvm.16H           w12, w12, w30

  bn.mulv.l.16H.acc.z.lo w30, w15, sw1.6
  bn.mulv.l.16H.lo       w30, w30, sw0.2
  bn.mulv.l.16H.acc.hi   w30, w30, sw0.0
  bn.subvm.16H           w15, w13, w30
  bn.addvm.16H           w13, w13, w30

  /* Layer 4, stride 16 */

  bn.mulv.l.16H.acc.z.lo w30, w1, sw1.7
  bn.mulv.l.16H.lo       w30, w30, sw0.2
  bn.mulv.l.16H.acc.hi   w30, w30, sw0.0
  bn.subvm.16H           w1, w0, w30
  bn.addvm.16H           w0, w0, w30

  bn.mulv.l.16H.acc.z.lo w30, w3, sw1.8
  bn.mulv.l.16H.lo       w30, w30, sw0.2
  bn.mulv.l.16H.acc.hi   w30, w30, sw0.0
  bn.subvm.16H           w3, w2, w30
  bn.addvm.16H           w2, w2, w30

  bn.mulv.l.16H.acc.z.lo w30, w5, sw1.9
  bn.mulv.l.16H.lo       w30, w30, sw0.2
  bn.mulv.l.16H.acc.hi   w30, w30, sw0.0
  bn.subvm.16H           w5, w4, w30
  bn.addvm.16H           w4, w4, w30

  bn.mulv.l.16H.acc.z.lo w30, w7, sw1.10
  bn.mulv.l.16H.lo       w30, w30, sw0.2
  bn.mulv.l.16H.acc.hi   w30, w30, sw0.0
  bn.subvm.16H           w7, w6, w30
  bn.addvm.16H           w6, w6, w30

  bn.mulv.l.16H.acc.z.lo w30, w9, sw1.11
  bn.mulv.l.16H.lo       w30, w30, sw0.2
  bn.mulv.l.16H.acc.hi   w30, w30, sw0.0
  bn.subvm.16H           w9, w8, w30
  bn.addvm.16H           w8, w8, w30

  bn.mulv.l.16H.acc.z.lo w30, w11, sw1.12
  bn.mulv.l.16H.lo       w30, w30, sw0.2
  bn.mulv.l.16H.acc.hi   w30, w30, sw0.0
  bn.subvm.16H           w11, w10, w30
  bn.addvm.16H           w10, w10, w30

  bn.mulv.l.16H.acc.z.lo w30, w13, sw1.13
  bn.mulv.l.16H.lo       w30, w30, sw0.2
  bn.mulv.l.16H.acc.hi   w30, w30, sw0.0
  bn.subvm.16H           w13, w12, w30
  bn.addvm.16H           w12, w12, w30

  bn.mulv.l.16H.acc.z.lo w30, w15, sw1.14
  bn.mulv.l.16H.lo       w30, w30, sw0.2
  bn.mulv.l.16H.acc.hi   w30, w30, sw0.0
  bn.subvm.16H           w15, w14, w30
  bn.addvm.16H           w14, w14, w30

  /* Set the twiddle pointer for Layer 5 */

  /* Compute NTT Layers 5--7 */
  /* Transpose */
  /* First trans w24-w31 */
  bn.trn1.8S w24, w0, w1
  bn.trn2.8S w25, w0, w1 
  bn.trn1.8S w26, w2, w3  
  bn.trn2.8S w27, w2, w3
  bn.trn1.8S w28, w4, w5
  bn.trn2.8S w29, w4, w5
  bn.trn1.8S w30, w6, w7
  bn.trn2.8S w31, w6, w7 
  
  bn.trn1.4D w0, w24, w26
  bn.trn2.4D w2, w24, w26 
  bn.trn1.4D w1, w25, w27
  bn.trn2.4D w3, w25, w27 
  bn.trn1.4D w4, w28, w30 
  bn.trn2.4D w6, w28, w30 
  bn.trn1.4D w5, w29, w31
  bn.trn2.4D w7, w29, w31 
  
  bn.trn1.2Q w24, w0, w4 
  bn.trn2.2Q w28, w0, w4 
  bn.trn1.2Q w25, w1, w5 
  bn.trn2.2Q w29, w1, w5 
  bn.trn1.2Q w26, w2, w6
  bn.trn2.2Q w30, w2, w6
  bn.trn1.2Q w27, w3, w7
  bn.trn2.2Q w31, w3, w7  

  /* Second trans w0-w7 */
  bn.trn1.8S w0, w8, w9
  bn.trn2.8S w1, w8, w9 
  bn.trn1.8S w2, w10, w11  
  bn.trn2.8S w3, w10, w11
  bn.trn1.8S w4, w12, w13
  bn.trn2.8S w5, w12, w13
  bn.trn1.8S w6, w14, w15
  bn.trn2.8S w7, w14, w15 

  bn.trn1.4D w8, w0, w2
  bn.trn2.4D w10, w0, w2 
  bn.trn1.4D w9, w1, w3
  bn.trn2.4D w11, w1, w3 
  bn.trn1.4D w12, w4, w6 
  bn.trn2.4D w14, w4, w6 
  bn.trn1.4D w13, w5, w7
  bn.trn2.4D w15, w5, w7 

  bn.trn1.2Q w0, w8, w12 
  bn.trn2.2Q w4, w8, w12 
  bn.trn1.2Q w1, w9, w13 
  bn.trn2.2Q w5, w9, w13 
  bn.trn1.2Q w2, w10, w14
  bn.trn2.2Q w6, w10, w14
  bn.trn1.2Q w3, w11, w15
  bn.trn2.2Q w7, w11, w15 

  /* Layer 5, stride 8 */
  bn.lid x23, 32(x11) /* Load Twiddle factors */

  /* Butterflies */
  bn.mulv.16H.acc.z.lo w8, w28, w17
  bn.mulv.l.16H.lo     w8, w8, sw0.2
  bn.mulv.l.16H.acc.hi w8, w8, sw0.0
  bn.subvm.16H         w28, w24, w8
  bn.addvm.16H         w24, w24, w8

  bn.mulv.16H.acc.z.lo w8, w29, w17
  bn.mulv.l.16H.lo     w8, w8, sw0.2
  bn.mulv.l.16H.acc.hi w8, w8, sw0.0
  bn.subvm.16H         w29, w25, w8
  bn.addvm.16H         w25, w25, w8

  bn.mulv.16H.acc.z.lo w8, w30, w17
  bn.mulv.l.16H.lo     w8, w8, sw0.2
  bn.mulv.l.16H.acc.hi w8, w8, sw0.0
  bn.subvm.16H         w30, w26, w8
  bn.addvm.16H         w26, w26, w8

  bn.mulv.16H.acc.z.lo w8, w31, w17
  bn.mulv.l.16H.lo     w8, w8, sw0.2
  bn.mulv.l.16H.acc.hi w8, w8, sw0.0
  bn.subvm.16H         w31, w27, w8
  bn.addvm.16H         w27, w27, w8

  bn.lid x23, 64(x11) /* Load Twiddle factors */

  bn.mulv.16H.acc.z.lo w8, w4, w17
  bn.mulv.l.16H.lo     w8, w8, sw0.2
  bn.mulv.l.16H.acc.hi w8, w8, sw0.0
  bn.subvm.16H         w4, w0, w8
  bn.addvm.16H         w0, w0, w8

  bn.mulv.16H.acc.z.lo w8, w5, w17
  bn.mulv.l.16H.lo     w8, w8, sw0.2
  bn.mulv.l.16H.acc.hi w8, w8, sw0.0
  bn.subvm.16H         w5, w1, w8
  bn.addvm.16H         w1, w1, w8

  bn.mulv.16H.acc.z.lo w8, w6, w17
  bn.mulv.l.16H.lo     w8, w8, sw0.2
  bn.mulv.l.16H.acc.hi w8, w8, sw0.0
  bn.subvm.16H         w6, w2, w8
  bn.addvm.16H         w2, w2, w8

  bn.mulv.16H.acc.z.lo w8, w7, w17
  bn.mulv.l.16H.lo     w8, w8, sw0.2
  bn.mulv.l.16H.acc.hi w8, w8, sw0.0
  bn.subvm.16H         w7, w3, w8
  bn.addvm.16H         w3, w3, w8

  /* Layer 6, stride 4 */

  bn.lid x23, 96(x11) /* Load twiddle factors */ 

  /* Butterflies */
  bn.mulv.16H.acc.z.lo w8, w26, w17
  bn.mulv.l.16H.lo     w8, w8, sw0.2
  bn.mulv.l.16H.acc.hi w8, w8, sw0.0
  bn.subvm.16H         w26, w24, w8
  bn.addvm.16H         w24, w24, w8

  bn.mulv.16H.acc.z.lo w8, w27, w17
  bn.mulv.l.16H.lo     w8, w8, sw0.2
  bn.mulv.l.16H.acc.hi w8, w8, sw0.0
  bn.subvm.16H         w27, w25, w8
  bn.addvm.16H         w25, w25, w8

  bn.lid x23, 128(x11) /* Load twiddle factors */

  bn.mulv.16H.acc.z.lo w8, w30, w17
  bn.mulv.l.16H.lo     w8, w8, sw0.2
  bn.mulv.l.16H.acc.hi w8, w8, sw0.0
  bn.subvm.16H         w30, w28, w8
  bn.addvm.16H         w28, w28, w8

  bn.mulv.16H.acc.z.lo w8, w31, w17
  bn.mulv.l.16H.lo     w8, w8, sw0.2
  bn.mulv.l.16H.acc.hi w8, w8, sw0.0
  bn.subvm.16H         w31, w29, w8
  bn.addvm.16H         w29, w29, w8

  bn.lid x23, 160(x11) /* Load twiddle factors */

  bn.mulv.16H.acc.z.lo w8, w2, w17
  bn.mulv.l.16H.lo     w8, w8, sw0.2
  bn.mulv.l.16H.acc.hi w8, w8, sw0.0
  bn.subvm.16H         w2, w0, w8
  bn.addvm.16H         w0, w0, w8

  bn.mulv.16H.acc.z.lo w8, w3, w17
  bn.mulv.l.16H.lo     w8, w8, sw0.2
  bn.mulv.l.16H.acc.hi w8, w8, sw0.0
  bn.subvm.16H         w3, w1, w8
  bn.addvm.16H         w1, w1, w8

  bn.lid x23, 192(x11) /* Load twiddle factors */

  bn.mulv.16H.acc.z.lo w8, w6, w17
  bn.mulv.l.16H.lo     w8, w8, sw0.2
  bn.mulv.l.16H.acc.hi w8, w8, sw0.0
  bn.subvm.16H         w6, w4, w8
  bn.addvm.16H         w4, w4, w8

  bn.mulv.16H.acc.z.lo w8, w7, w17
  bn.mulv.l.16H.lo     w8, w8, sw0.2
  bn.mulv.l.16H.acc.hi w8, w8, sw0.0
  bn.subvm.16H         w7, w5, w8
  bn.addvm.16H         w5, w5, w8

  /* Layer 7, stride 2 */

  bn.lid x23, 224(x11) /* Load twiddle factors */

  /* Butterflies */
  bn.mulv.16H.acc.z.lo w8, w25, w17
  bn.mulv.l.16H.lo     w8, w8, sw0.2
  bn.mulv.l.16H.acc.hi w8, w8, sw0.0
  bn.subvm.16H         w25, w24, w8
  bn.addvm.16H         w24, w24, w8

  bn.lid x23, 256(x11) /* Load twiddle factors */

  bn.mulv.16H.acc.z.lo w8, w27, w17
  bn.mulv.l.16H.lo     w8, w8, sw0.2
  bn.mulv.l.16H.acc.hi w8, w8, sw0.0
  bn.subvm.16H         w27, w26, w8
  bn.addvm.16H         w26, w26, w8

  bn.lid x23, 288(x11) /* Load twiddle factors */

  bn.mulv.16H.acc.z.lo w8, w29, w17
  bn.mulv.l.16H.lo     w8, w8, sw0.2
  bn.mulv.l.16H.acc.hi w8, w8, sw0.0
  bn.subvm.16H         w29, w28, w8
  bn.addvm.16H         w28, w28, w8

  bn.lid x23, 320(x11) /* Load twiddle factors */

  bn.mulv.16H.acc.z.lo w8, w31, w17
  bn.mulv.l.16H.lo     w8, w8, sw0.2
  bn.mulv.l.16H.acc.hi w8, w8, sw0.0
  bn.subvm.16H         w31, w30, w8
  bn.addvm.16H         w30, w30, w8

  bn.lid x23, 352(x11) /* Load twiddle factors */

  bn.mulv.16H.acc.z.lo w8, w1, w17
  bn.mulv.l.16H.lo     w8, w8, sw0.2
  bn.mulv.l.16H.acc.hi w8, w8, sw0.0
  bn.subvm.16H         w1, w0, w8
  bn.addvm.16H         w0, w0, w8

  bn.lid x23, 384(x11) /* Load twiddle factors */

  bn.mulv.16H.acc.z.lo w8, w3, w17
  bn.mulv.l.16H.lo     w8, w8, sw0.2
  bn.mulv.l.16H.acc.hi w8, w8, sw0.0
  bn.subvm.16H         w3, w2, w8
  bn.addvm.16H         w2, w2, w8

  bn.lid x23, 416(x11) /* Load twiddle factors */

  bn.mulv.16H.acc.z.lo w8, w5, w17
  bn.mulv.l.16H.lo     w8, w8, sw0.2
  bn.mulv.l.16H.acc.hi w8, w8, sw0.0
  bn.subvm.16H         w5, w4, w8
  bn.addvm.16H         w4, w4, w8

  bn.lid x23, 448(x11) /* Load twiddle factors */

  bn.mulv.16H.acc.z.lo w8, w7, w17
  bn.mulv.l.16H.lo     w8, w8, sw0.2
  bn.mulv.l.16H.acc.hi w8, w8, sw0.0
  bn.subvm.16H         w7, w6, w8
  bn.addvm.16H         w6, w6, w8

  /* First trans w8-w15 */
  bn.trn1.8S w8, w0, w1
  bn.trn2.8S w9, w0, w1 
  bn.trn1.8S w10, w2, w3  
  bn.trn2.8S w11, w2, w3
  bn.trn1.8S w12, w4, w5
  bn.trn2.8S w13, w4, w5
  bn.trn1.8S w14, w6, w7
  bn.trn2.8S w15, w6, w7 
  
  bn.trn1.4D w0, w8, w10
  bn.trn2.4D w2, w8, w10 
  bn.trn1.4D w1, w9, w11
  bn.trn2.4D w3, w9, w11 
  bn.trn1.4D w4, w12, w14 
  bn.trn2.4D w6, w12, w14 
  bn.trn1.4D w5, w13, w15
  bn.trn2.4D w7, w13, w15 
  
  bn.trn1.2Q w8, w0, w4 
  bn.trn2.2Q w12, w0, w4 
  bn.trn1.2Q w9, w1, w5 
  bn.trn2.2Q w13, w1, w5 
  bn.trn1.2Q w10, w2, w6
  bn.trn2.2Q w14, w2, w6
  bn.trn1.2Q w11, w3, w7
  bn.trn2.2Q w15, w3, w7  

  /* Second trans w0-w7 */
  bn.trn1.8S w0, w24, w25
  bn.trn2.8S w1, w24, w25 
  bn.trn1.8S w2, w26, w27  
  bn.trn2.8S w3, w26, w27
  bn.trn1.8S w4, w28, w29
  bn.trn2.8S w5, w28, w29
  bn.trn1.8S w6, w30, w31
  bn.trn2.8S w7, w30, w31 

  bn.trn1.4D w24, w0, w2
  bn.trn2.4D w26, w0, w2 
  bn.trn1.4D w25, w1, w3
  bn.trn2.4D w27, w1, w3 
  bn.trn1.4D w28, w4, w6 
  bn.trn2.4D w30, w4, w6 
  bn.trn1.4D w29, w5, w7
  bn.trn2.4D w31, w5, w7 

  bn.trn1.2Q w0, w24, w28 
  bn.trn2.2Q w4, w24, w28 
  bn.trn1.2Q w1, w25, w29 
  bn.trn2.2Q w5, w25, w29 
  bn.trn1.2Q w2, w26, w30
  bn.trn2.2Q w6, w26, w30
  bn.trn1.2Q w3, w27, w31
  bn.trn2.2Q w7, w27, w31 

  /* Store output */
  bn.sid x4, 0(x12++)
  bn.sid x5, 0(x12++)
  bn.sid x6, 0(x12++)
  bn.sid x7, 0(x12++)
  bn.sid x3, 0(x12++)
  bn.sid x9, 0(x12++)
  bn.sid x13, 0(x12++)
  bn.sid x14, 0(x12++)
  bn.sid x15, 0(x12++)
  bn.sid x16, 0(x12++)
  bn.sid x17, 0(x12++)
  bn.sid x18, 0(x12++)
  bn.sid x19, 0(x12++)
  bn.sid x20, 0(x12++)
  bn.sid x21, 0(x12++)
  bn.sid x22, 0(x12++)

  ret
