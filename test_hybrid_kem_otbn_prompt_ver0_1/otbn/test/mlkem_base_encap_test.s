/* Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */
/* Modified by Ruben Niederhagen and Hoang Nguyen Hien Pham - authors of */
/* "Improving ML-KEM & ML-DSA on OpenTitan - Efficient Multiplication Vector Instructions for OTBN" */
/* (https://eprint.iacr.org/2025/2028) */
/* Copyright Ruben Niederhagen and Hoang Nguyen Hien Pham. */

/*
 * Testwrapper for mlkem_encap
*/

.section .text.start

/* Entry point. */
.globl main
main:
  /* Init all-zero register. */

  bn.xor  w0, w0, w0
  bn.xor  w1, w1, w1
  bn.xor  w2, w2, w2
  bn.xor  w3, w3, w3
  bn.xor  w4, w4, w4
  bn.xor  w5, w5, w5
  bn.xor  w6, w6, w6
  bn.xor  w7, w7, w7
  bn.xor  w8, w8, w8
  bn.xor  w9, w9, w9
  bn.xor  w10, w10, w10
  bn.xor  w11, w11, w11
  bn.xor  w12, w12, w12
  bn.xor  w13, w13, w13
  bn.xor  w14, w14, w14
  bn.xor  w15, w15, w15
  bn.xor  w16, w16, w16
  bn.xor  w17, w17, w17
  bn.xor  w18, w18, w18
  bn.xor  w19, w19, w19
  bn.xor  w20, w20, w20
  bn.xor  w21, w21, w21
  bn.xor  w22, w22, w22
  bn.xor  w23, w23, w23
  bn.xor  w24, w24, w24
  bn.xor  w25, w25, w25
  bn.xor  w26, w26, w26
  bn.xor  w27, w27, w27
  bn.xor  w28, w28, w28
  bn.xor  w29, w29, w29
  bn.xor  w30, w30, w30

  bn.xor  w31, w31, w31

  /* MOD <= dmem[modulus] = KYBER_Q */
  li      x5, 2
  la      x6, modulus
  bn.lid  x5, 0(x6)
  bn.wsrw 0x0, w2

  /* Load stack pointer */
  la   x2, stack_end
  la   x10, coins
  la   x11, ct
  la   x12, ss
  la   x13, ek
  jal  x1, crypto_kem_enc

  ecall

.data
.balign 32
.global stack
stack:
  .zero 20000
stack_end:
.globl ct
ct:
  .zero 1088
.globl ss
ss:
  .zero 32

.balign 32
.globl coins
coins:
    .word 0x667c4aeb
    .word 0x2dba4eef
    .word 0x8dc838db
    .word 0xb106c78b
    .word 0x210039d6
    .word 0x7b2a1798
    .word 0xa8ec4219
    .word 0xba01c0f6

.globl ek
ek:
    .word 0xa151e6a8
    .word 0x24f285e6
    .word 0x4f95a878
    .word 0x71c77b00
    .word 0x7207931b
    .word 0x2e098fc7
    .word 0x3e8e8782
    .word 0x79367f93
    .word 0x13295367
    .word 0xfd3dd5a8
    .word 0xf8b1bff4
    .word 0x59466784
    .word 0x34cf0567
    .word 0x72b94251
    .word 0x2563f1a3
    .word 0x52290cc4
    .word 0x89257ba3
    .word 0x5ff35e7e
    .word 0xa473ebba
    .word 0xa0b6beac
    .word 0xce4299b8
    .word 0x1c5395b1
    .word 0x99070afc
    .word 0x3e485439
    .word 0xc087bc6c
    .word 0xf04fa76a
    .word 0x7e20c5ca
    .word 0x0a265b53
    .word 0x98118da9
    .word 0x05a67dc0
    .word 0x2010d1c4
    .word 0xbbf7c9f6
    .word 0x5634bb68
    .word 0xb7013ac7
    .word 0xd199bc10
    .word 0x17a53977
    .word 0x6601aa16
    .word 0x8b628b0c
    .word 0xba02562f
    .word 0xa97ef065
    .word 0x896e3393
    .word 0xc5f2836e
    .word 0x03bf1b73
    .word 0x6c5b0c46
    .word 0x74cbfe8a
    .word 0xe991e38e
    .word 0xc5a23489
    .word 0x9f064d7d
    .word 0x308bd850
    .word 0x386f96d6
    .word 0x49c67bc3
    .word 0xce3426b8
    .word 0x5c642277
    .word 0x635062cd
    .word 0xd6464636
    .word 0x57db99d6
    .word 0x74b65eb4
    .word 0xe46de165
    .word 0x18a806d4
    .word 0xcae1eab9
    .word 0x94256a91
    .word 0xa4089748
    .word 0xb088ea3c
    .word 0xd0034c2a
    .word 0x5c81449b
    .word 0xaf1c1097
    .word 0xcbbb4850
    .word 0x36e27a24
    .word 0x4b25dc6c
    .word 0xf42921a2
    .word 0xb30e3b5b
    .word 0xa391ca99
    .word 0x30284003
    .word 0x7bdb01ec
    .word 0xcf80a42c
    .word 0xb2090435
    .word 0x7b4b0916
    .word 0x3ce33a0c
    .word 0x24910ae1
    .word 0xab5196e8
    .word 0x53a21e90
    .word 0xd75b41c8
    .word 0xbb025f82
    .word 0xaf699322
    .word 0xf2282097
    .word 0x55ea7528
    .word 0xbcd316af
    .word 0x2e0cf769
    .word 0x285fb7e8
    .word 0x91d37db4
    .word 0xe3ad89f9
    .word 0x339c7214
    .word 0x194ca01f
    .word 0xc378b217
    .word 0x682860eb
    .word 0xad212851
    .word 0x45c625c8
    .word 0x631ece77
    .word 0x4a64d9b1
    .word 0xa3482961
    .word 0x1b7f3c48
    .word 0x0080259a
    .word 0x949601e3
    .word 0x2736404a
    .word 0xc7769c60
    .word 0xe05d6bea
    .word 0x43d26417
    .word 0x9e7b1179
    .word 0xdc4898a2
    .word 0x4b455c55
    .word 0xa51baece
    .word 0x4ac772cc
    .word 0x919c6bb9
    .word 0x6bd210b9
    .word 0x3956b288
    .word 0xe28a77d4
    .word 0x51617c6c
    .word 0xd76c9ca1
    .word 0x37548493
    .word 0xc5e46524
    .word 0x5a2429ec
    .word 0x37b53dcb
    .word 0xbfdae39d
    .word 0xc0a729a6
    .word 0xa853834a
    .word 0xac950c53
    .word 0x4bbb32b7
    .word 0xbb3219b8
    .word 0x48a8a72c
    .word 0x016836cd
    .word 0x23be4a44
    .word 0x6a363bc8
    .word 0xcfa3d687
    .word 0xc0240936
    .word 0x0ae9ba02
    .word 0x06485cf6
    .word 0xf252370b
    .word 0xb21adfba
    .word 0x55722072
    .word 0x7559504a
    .word 0xa7e69435
    .word 0xc91f7602
    .word 0xc4c88476
    .word 0x6b0a54a7
    .word 0xdec9fb07
    .word 0xaa74c987
    .word 0x28d90988
    .word 0xbfcbf4c7
    .word 0xa5ae4580
    .word 0x257866bc
    .word 0x21a505fd
    .word 0x53bfa4f1
    .word 0x11c71092
    .word 0x3e7bc33b
    .word 0xfccbb058
    .word 0xcb41c853
    .word 0xe21d37b0
    .word 0x89b911e5
    .word 0xc0707ccb
    .word 0x786d3623
    .word 0xf07ec3f9
    .word 0x0b72f847
    .word 0xa859c7e1
    .word 0xf6936bd9
    .word 0x4f11945a
    .word 0x9a0df6fa
    .word 0x995e7981
    .word 0x2a15715c
    .word 0xa6a59146
    .word 0xf3e1a902
    .word 0xc7379e59
    .word 0x10bcc768
    .word 0x66c09489
    .word 0x95dc3a9f
    .word 0xb6b4467d
    .word 0xe2686925
    .word 0x2e89d790
    .word 0xee6454a8
    .word 0x390f757a
    .word 0x2c15e3c5
    .word 0xd856fc2d
    .word 0xba24c9b0
    .word 0x689a958a
    .word 0xf6476509
    .word 0x38c82364
    .word 0x94572a98
    .word 0x3753e1b9
    .word 0x9a1a3371
    .word 0x82286c65
    .word 0x2691eb8b
    .word 0xe8950ea6
    .word 0x8306d9c5
    .word 0x7010772c
    .word 0xfbb17655
    .word 0x9d260795
    .word 0x5cc9f8da
    .word 0x2c9b71e9
    .word 0x2b11dda8
    .word 0x9fcc0be1
    .word 0x1bbd374a
    .word 0x3eb3ee1e
    .word 0xe96aa7cd
    .word 0x4b5d9af6
    .word 0x69a82329
    .word 0x611d6757
    .word 0x1cbe3593
    .word 0xce772c4c
    .word 0x981fc487
    .word 0x6446cca8
    .word 0x0a30fa60
    .word 0x1f305baf
    .word 0xc8091d0a
    .word 0x4dda658e
    .word 0x684fe68e
    .word 0xbb8921c0
    .word 0xaf4b58b3
    .word 0x5dc816f7
    .word 0x8a0454b6
    .word 0x48334300
    .word 0x74a09393
    .word 0x213ecd27
    .word 0x5f346a7e
    .word 0x132b2c6c
    .word 0x72337bc2
    .word 0x7bb2c071
    .word 0x0da0ba2d
    .word 0xb5007623
    .word 0xcfe894b5
    .word 0xea25d62d
    .word 0xd80ecf76
    .word 0x972c1299
    .word 0x18b0b496
    .word 0x80250470
    .word 0xcd77a449
    .word 0x498cd611
    .word 0xb0e7a0b9
    .word 0xac8cce0b
    .word 0xb3cb6478
    .word 0x84001475
    .word 0x06934c74
    .word 0x79ca9426
    .word 0xe7404f5c
    .word 0xa1c5c9ac
    .word 0xd8724088
    .word 0xb5af8dc3
    .word 0x8441ee01
    .word 0x9e815add
    .word 0x65c14ec2
    .word 0x62f96112
    .word 0x15727ab1
    .word 0x8c744aaa
    .word 0x386c8315
    .word 0x82673791
    .word 0x718d8304
    .word 0x4f5ba895
    .word 0x74b5a198
    .word 0x0979cdc4
    .word 0x3e831fcd
    .word 0x5548d1ff
    .word 0x379d2243
    .word 0xcdb5d948
    .word 0xb3b9176c
    .word 0x8bef4ab8
    .word 0x83e613ce
    .word 0xc7593673
    .word 0x15d64295
    .word 0xcd712a78
    .word 0xba92e7ee
    .word 0x4bdc1bb5
    .word 0x8e30e8bf
    .word 0xed443166
    .word 0x301849e8
    .word 0x63b498ad
    .word 0xa8ab644f
    .word 0x2742c0b9
    .word 0x0f925326
    .word 0x171a0c38
    .word 0xd7ce87ca
    .word 0x821cc4aa
    .word 0x18938788
    .word 0xe1766f1a
    .word 0x0eb9b797
    .word 0xbb4309f9
    .word 0x29914438
    .word 0x1e55d811
    .word 0x76c56654
    .word 0x61bcb07a
    .word 0x36f7a3a1
    .word 0x98c02e16
    .word 0x2db100a9
    .word 0xfbbbfad8
    .word 0x1dcbe83f
    .word 0x5f31e8c4
    .word 0x2fd3f02a
    .word 0x13ae1700
    .word 0x28f0196e


/* Modulus: KYBER_Q = 3329 */
.globl modulus
modulus:
  .word 0x00000d01
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000

/* 1/Q mod 2^32 */
.globl qinv
qinv:
  .word 0x6ba8f301
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000

.globl modulus_bn
modulus_bn:
  .word 0x0d010d01
  .word 0x0d010d01
  .word 0x0d010d01
  .word 0x0d010d01
  .word 0x0d010d01
  .word 0x0d010d01
  .word 0x0d010d01
  .word 0x0d010d01

.globl modulus_over_2
modulus_over_2:
  .word 0x06810681
  .word 0x06810681
  .word 0x06810681
  .word 0x06810681
  .word 0x06810681
  .word 0x06810681
  .word 0x06810681
  .word 0x06810681

.globl const_0x0fff
const_0x0fff:
  .word 0x0fff0fff
  .word 0x0fff0fff
  .word 0x0fff0fff
  .word 0x0fff0fff
  .word 0x0fff0fff
  .word 0x0fff0fff
  .word 0x0fff0fff
  .word 0x0fff0fff

.globl const_1290167
const_1290167:
  .word 0x0013afb7
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000

.globl const_8
const_8:
  .word 0x00080008
  .word 0x00080008
  .word 0x00080008
  .word 0x00080008
  .word 0x00080008
  .word 0x00080008
  .word 0x00080008
  .word 0x00080008

.globl const_toplant
const_toplant:
  .word 0x97f44fab
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000

.globl cbd2_const
cbd2_const:
  /* const1 */
  .word 0x55555555
  .word 0x55555555
  .word 0x55555555
  .word 0x55555555
  .word 0x55555555
  .word 0x55555555
  .word 0x55555555
  .word 0x55555555
  /* const2 */ 
  .word 0x33333333
  .word 0x33333333
  .word 0x33333333
  .word 0x33333333
  .word 0x33333333
  .word 0x33333333
  .word 0x33333333
  .word 0x33333333

.globl cbd3_const
cbd3_const:
  /* const1 */
  .word 0x49249249
  .word 0x92492492
  .word 0x24924924
  .word 0x49249249
  .word 0x92492492
  .word 0x24924924
  .word 0x49249249
  .word 0x12492492
  /* const2 */
  .word 0xc71c71c7
  .word 0x71c71c71
  .word 0x1c71c71c
  .word 0xc71c71c7
  .word 0x71c71c71
  .word 0x1c71c71c
  .word 0xc71c71c7
  .word 0x71c71c71

.globl twiddles_ntt
twiddles_ntt:
  /* Layer 1--4 */ 
  .word 0x84f5c5b6, 0x00000000
  .word 0xc666e465, 0x00000000
  .word 0xfcec8b58, 0x00000000
  .word 0xcb2b72d0, 0x00000000
  .word 0x30726d5b, 0x00000000
  .word 0x91e11612, 0x00000000
  .word 0x41360f89, 0x00000000
  .word 0x51aaf2da, 0x00000000
  .word 0x93922fd5, 0x00000000
  .word 0x0ed77946, 0x00000000
  .word 0x3d4a0dff, 0x00000000
  .word 0xd63e49fb, 0x00000000
  .word 0xfab1a391, 0x00000000
  .word 0x2bc18ea7, 0x00000000
  .word 0x864470e4, 0x00000000
  /* Padding */
  .word 0x00000000, 0x00000000
  /* Layer 5 - 1 */
  .word 0x16c32c11, 0x00000000
  /* Layer 6 - 1 */
  .word 0x16395e0d, 0x00000000
  .word 0x19743224, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 7 - 1 */
  .word 0x014eab2e, 0x00000000
  .word 0xd4522112, 0x00000000
  .word 0x2cd52aae, 0x00000000
  .word 0xcbb540d4, 0x00000000
  /* Layer 5 - 2 */
  .word 0xbc2c9a1c, 0x00000000
  /* Layer 6 - 2 */
  .word 0xfa27d58e, 0x00000000
  .word 0x87094e0e, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 7 - 2 */
  .word 0x7de29fcd, 0x00000000
  .word 0x379942fb, 0x00000000
  .word 0xaff27732, 0x00000000
  .word 0x54970814, 0x00000000
  /* Layer 5 - 3 */
  .word 0x66f8144e, 0x00000000
  /* Layer 6 - 3 */
  .word 0x5c0c9c92, 0x00000000
  .word 0xb12d72a9, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 7 - 3 */
  .word 0x6c5a2074, 0x00000000
  .word 0xccb52d24, 0x00000000
  .word 0xfc4f0d9d, 0x00000000
  .word 0x11eaedee, 0x00000000
  /* Layer 5 - 4 */
  .word 0x71811d74, 0x00000000
  /* Layer 6 - 4 */
  .word 0xaf19ea51, 0x00000000
  .word 0x9e078945, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 7 - 4 */
  .word 0x3a22e9a0, 0x00000000
  .word 0xa5cbdca1, 0x00000000
  .word 0xe7da790b, 0x00000000
  .word 0xea8b7f1e, 0x00000000
  /* Layer 5 - 5 */
  .word 0xea3cc040, 0x00000000
  /* Layer 6 - 5 */
  .word 0x31fc27af, 0x00000000
  .word 0x9807ff63, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 7 - 5 */
  .word 0x82f5ed16, 0x00000000
  .word 0x7ef63bd5, 0x00000000
  .word 0xd6795921, 0x00000000
  .word 0x8992f4b3, 0x00000000
  /* Layer 5 - 6 */
  .word 0x044e701f, 0x00000000
  /* Layer 6 - 6 */
  .word 0xc13fe765, 0x00000000
  .word 0x3099ccc9, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 7 - 6 */
  .word 0x8e08c440, 0x00000000
  .word 0x4935720b, 0x00000000
  .word 0x7059d1b5, 0x00000000
  .word 0xcea1560e, 0x00000000
  /* Layer 5 - 7 */
  .word 0xac4184cf, 0x00000000
  /* Layer 6 - 7 */
  .word 0xdc518394, 0x00000000
  .word 0x0289a6a5, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 7 - 7 */
  .word 0x483585bb, 0x00000000
  .word 0xb17c3187, 0x00000000
  .word 0xbb67bcf2, 0x00000000
  .word 0xb7a31ad7, 0x00000000
  /* Layer 5 - 8 */
  .word 0x6681f601, 0x00000000
  /* Layer 6 - 8 */
  .word 0x658209b1, 0x00000000
  .word 0x934370f8, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 7 - 8 */
  .word 0x385e2025, 0x00000000
  .word 0xb3b7194d, 0x00000000
  .word 0x149bf401, 0x00000000
  .word 0x314afa3c, 0x00000000
  /* Layer 5 - 9 */
  .word 0x6da8cba2, 0x00000000
  /* Layer 6 - 9 */
  .word 0xb254be68, 0x00000000
  .word 0x6e59f915, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 7 - 9 */
  .word 0x79cf3ed4, 0x00000000
  .word 0xb0b7545c, 0x00000000
  .word 0x9ca52e5f, 0x00000000
  .word 0xf79e2ee9, 0x00000000
  /* Layer 5 - 10 */
  .word 0xa1074e36, 0x00000000
  /* Layer 6 - 10 */
  .word 0x3e0eeb29, 0x00000000
  .word 0x22c23fd4, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 7 - 10 */
  .word 0x1cd665aa, 0x00000000
  .word 0xc4049d2f, 0x00000000
  .word 0xa0b88f58, 0x00000000
  .word 0x7e801d88, 0x00000000
  /* Layer 5 - 11 */
  .word 0x2924384b, 0x00000000
  /* Layer 6 - 11 */
  .word 0x6e95083b, 0x00000000
  .word 0xdc8c92ba, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 7 - 11 */
  .word 0x51bea292, 0x00000000
  .word 0x1887f58b, 0x00000000
  .word 0xd53e5dab, 0x00000000
  .word 0x3a369957, 0x00000000
  /* Layer 5 - 12 */
  .word 0xdda02ec2, 0x00000000
  /* Layer 6 - 12 */
  .word 0x75f6ed02, 0x00000000
  .word 0xb8b6b6df, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 7 - 12 */
  .word 0xa169bccb, 0x00000000
  .word 0x2b2410ec, 0x00000000
  .word 0xbda2a4b9, 0x00000000
  .word 0xc77a806d, 0x00000000
  /* Layer 5 - 13 */
  .word 0xb805896c, 0x00000000
  /* Layer 6 - 13 */
  .word 0xcb8de165, 0x00000000
  .word 0xc93f49e7, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 7 - 13 */
  .word 0xd7a0a4e0, 0x00000000
  .word 0x53f98a58, 0x00000000
  .word 0x1efd9db9, 0x00000000
  .word 0x4ee63d0f, 0x00000000
  /* Layer 5 - 14 */
  .word 0xdd651f9c, 0x00000000
  /* Layer 6 - 14 */
  .word 0x71e38c09, 0x00000000
  .word 0x31d4c840, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 7 - 14 */
  .word 0x57e58be2, 0x00000000
  .word 0xa555be54, 0x00000000
  .word 0xd565bd19, 0x00000000
  .word 0x442224c3, 0x00000000
  /* Layer 5 - 15 */
  .word 0x97ccf03d, 0x00000000
  /* Layer 6 - 15 */
  .word 0xbe402274, 0x00000000
  .word 0xef28ae1a, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 7 - 15 */
  .word 0x846bf7b2, 0x00000000
  .word 0x5d33e851, 0x00000000
  .word 0x901c4c98, 0x00000000
  .word 0x4f214c36, 0x00000000
  /* Layer 5 - 16 */
  .word 0x3f228731, 0x00000000
  /* Layer 6 - 16 */
  .word 0x5e5b3410, 0x00000000
  .word 0x45fa9df4, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 7 - 16 */
  .word 0xa24249ac, 0x00000000
  .word 0xe1b38fba, 0x00000000
  .word 0x440e750b, 0x00000000
  .word 0xa5a47d32, 0x00000000

.globl twiddles_intt
twiddles_intt:
  /* Layer 7 - 1 */
  .word 0x5a5b82cf, 0x00000000
  .word 0xbbf18af6, 0x00000000
  .word 0x1e4c7047, 0x00000000
  .word 0x5dbdb655, 0x00000000
  /* Layer 6 - 1 */
  .word 0xba05620d, 0x00000000
  .word 0xa1a4cbf1, 0x00000000
  /* Layer 5 - 1 */
  .word 0xc0dd78d0, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 7 - 2 */
  .word 0xb0deb3cb, 0x00000000
  .word 0x6fe3b369, 0x00000000
  .word 0xa2cc17b0, 0x00000000
  .word 0x7b94084f, 0x00000000
  /* Layer 6 - 2 */
  .word 0x10d751e7, 0x00000000
  .word 0x41bfdd8d, 0x00000000
  /* Layer 5 - 2 */
  .word 0x68330fc4, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 7 - 3 */
  .word 0xbbdddb3e, 0x00000000
  .word 0x2a9a42e8, 0x00000000
  .word 0x5aaa41ad, 0x00000000
  .word 0xa81a741f, 0x00000000
  /* Layer 6 - 3 */
  .word 0xce2b37c1, 0x00000000
  .word 0x8e1c73f8, 0x00000000
  /* Layer 5 - 3 */
  .word 0x229ae065, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 7 - 4 */
  .word 0xb119c2f2, 0x00000000
  .word 0xe1026248, 0x00000000
  .word 0xac0675a9, 0x00000000
  .word 0x285f5b21, 0x00000000
  /* Layer 6 - 4 */
  .word 0x36c0b61a, 0x00000000
  .word 0x34721e9c, 0x00000000
  /* Layer 5 - 4 */
  .word 0x47fa7695, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 7 - 5 */
  .word 0x38857f94, 0x00000000
  .word 0x425d5b48, 0x00000000
  .word 0xd4dbef15, 0x00000000
  .word 0x5e964336, 0x00000000
  /* Layer 6 - 5 */
  .word 0x47494922, 0x00000000
  .word 0x8a0912ff, 0x00000000
  /* Layer 5 - 5 */
  .word 0x225fd13f, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 7 - 6 */
  .word 0xc5c966aa, 0x00000000
  .word 0x2ac1a256, 0x00000000
  .word 0xe7780a76, 0x00000000
  .word 0xae415d6f, 0x00000000
  /* Layer 6 - 6 */
  .word 0x23736d47, 0x00000000
  .word 0x916af7c6, 0x00000000
  /* Layer 5 - 6 */
  .word 0xd6dbc7b6, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 7 - 7 */
  .word 0x817fe279, 0x00000000
  .word 0x5f4770a9, 0x00000000
  .word 0x3bfb62d2, 0x00000000
  .word 0xe3299a57, 0x00000000
  /* Layer 6 - 7 */
  .word 0xdd3dc02d, 0x00000000
  .word 0xc1f114d8, 0x00000000
  /* Layer 5 - 7 */
  .word 0x5ef8b1cb, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 7 - 8 */
  .word 0x0861d118, 0x00000000
  .word 0x635ad1a2, 0x00000000
  .word 0x4f48aba5, 0x00000000
  .word 0x8630c12d, 0x00000000
  /* Layer 6 - 8 */
  .word 0x91a606ec, 0x00000000
  .word 0x4dab4199, 0x00000000
  /* Layer 5 - 8 */
  .word 0x9257345f, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 7 - 9 */
  .word 0xceb505c5, 0x00000000
  .word 0xeb640c00, 0x00000000
  .word 0x4c48e6b4, 0x00000000
  .word 0xc7a1dfdc, 0x00000000
  /* Layer 6 - 9 */
  .word 0x6cbc8f09, 0x00000000
  .word 0x9a7df650, 0x00000000
  /* Layer 5 - 9 */
  .word 0x997e0a00, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 7 - 10 */
  .word 0x485ce52a, 0x00000000
  .word 0x4498430f, 0x00000000
  .word 0x4e83ce7a, 0x00000000
  .word 0xb7ca7a46, 0x00000000
  /* Layer 6 - 10 */
  .word 0xfd76595c, 0x00000000
  .word 0x23ae7c6d, 0x00000000
  /* Layer 5 - 10 */
  .word 0x53be7b32, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 7 - 11 */
  .word 0x315ea9f3, 0x00000000
  .word 0x8fa62e4c, 0x00000000
  .word 0xb6ca8df6, 0x00000000
  .word 0x71f73bc1, 0x00000000
  /* Layer 6 - 11 */
  .word 0xcf663338, 0x00000000
  .word 0x3ec0189c, 0x00000000
  /* Layer 5 - 11 */
  .word 0xfbb18fe2, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 7 - 12 */
  .word 0x766d0b4e, 0x00000000
  .word 0x2986a6e0, 0x00000000
  .word 0x8109c42c, 0x00000000
  .word 0x7d0a12eb, 0x00000000
  /* Layer 6 - 12 */
  .word 0x67f8009e, 0x00000000
  .word 0xce03d852, 0x00000000
  /* Layer 5 - 12 */
  .word 0x15c33fc1, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 7 - 13 */
  .word 0x157480e3, 0x00000000
  .word 0x182586f6, 0x00000000
  .word 0x5a342360, 0x00000000
  .word 0xc5dd1661, 0x00000000
  /* Layer 6 - 13 */
  .word 0x61f876bc, 0x00000000
  .word 0x50e615b0, 0x00000000
  /* Layer 5 - 13 */
  .word 0x8e7ee28d, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 7 - 14 */
  .word 0xee151213, 0x00000000
  .word 0x03b0f264, 0x00000000
  .word 0x334ad2dd, 0x00000000
  .word 0x93a5df8d, 0x00000000
  /* Layer 6 - 14 */
  .word 0x4ed28d58, 0x00000000
  .word 0xa3f3636f, 0x00000000
  /* Layer 5 - 14 */
  .word 0x9907ebb3, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 7 - 15 */
  .word 0xab68f7ed, 0x00000000
  .word 0x500d88cf, 0x00000000
  .word 0xc866bd06, 0x00000000
  .word 0x821d6034, 0x00000000
  /* Layer 6 - 15 */
  .word 0x78f6b1f3, 0x00000000
  .word 0x05d82a73, 0x00000000
  /* Layer 5 - 15 */
  .word 0x43d365e5, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 7 - 16 */
  .word 0x344abf2d, 0x00000000
  .word 0xd32ad553, 0x00000000
  .word 0x2baddeef, 0x00000000
  .word 0xfeb154d3, 0x00000000
  /* Layer 6 - 16 */
  .word 0xe68bcddd, 0x00000000
  .word 0xe9c6a1f4, 0x00000000
  /* Layer 5 - 16 */
  .word 0xe93cd3f0, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 4--1 */ 
  .word 0x79bb8f1d, 0x00000000
  .word 0xd43e715a, 0x00000000
  .word 0x054e5c70, 0x00000000
  .word 0x29c1b606, 0x00000000
  .word 0xc2b5f202, 0x00000000
  .word 0xf12886bb, 0x00000000
  .word 0x6c6dd02c, 0x00000000
  .word 0xae550d27, 0x00000000
  .word 0xbec9f078, 0x00000000
  .word 0x6e1ee9ef, 0x00000000
  .word 0xcf8d92a6, 0x00000000
  .word 0x34d48d31, 0x00000000
  .word 0x031374a9, 0x00000000
  .word 0x39991b9c, 0x00000000
  .word 0x6b6de3db, 0x00000000
  /* n_inv */ 
  .word 0x912fe8a0, 0x00000000

.globl context
context:
  .balign 32
  .zero 212

.globl rc
.balign 32
rc:
  .balign 32
  .dword 0x0000000000000001
  .balign 32
  .dword 0x0000000000008082
  .balign 32
  .dword 0x800000000000808a
  .balign 32
  .dword 0x8000000080008000
  .balign 32
  .dword 0x000000000000808b
  .balign 32
  .dword 0x0000000080000001
  .balign 32
  .dword 0x8000000080008081
  .balign 32
  .dword 0x8000000000008009
  .balign 32
  .dword 0x000000000000008a
  .balign 32
  .dword 0x0000000000000088
  .balign 32
  .dword 0x0000000080008009
  .balign 32
  .dword 0x000000008000000a
  .balign 32
  .dword 0x000000008000808b
  .balign 32
  .dword 0x800000000000008b
  .balign 32
  .dword 0x8000000000008089
  .balign 32
  .dword 0x8000000000008003
  .balign 32
  .dword 0x8000000000008002
  .balign 32
  .dword 0x8000000000000080
  .balign 32
  .dword 0x000000000000800a
  .balign 32
  .dword 0x800000008000000a
  .balign 32
  .dword 0x8000000080008081
  .balign 32
  .dword 0x8000000000008080
  .balign 32
  .dword 0x0000000080000001
  .balign 32
  .dword 0x8000000080008008