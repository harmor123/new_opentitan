/* Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */
/* Modified by Ruben Niederhagen and Hoang Nguyen Hien Pham - authors of */
/* "Improving ML-KEM & ML-DSA on OpenTitan - Efficient Multiplication Vector Instructions for OTBN" */
/* (https://eprint.iacr.org/2025/2028) */
/* Copyright Ruben Niederhagen and Hoang Nguyen Hien Pham. */


/*
 * Testwrapper for mlkem_decap
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
  la   x10, ct
  la   x11, dk 
  la   x12, ss
  jal  x1, crypto_kem_dec

  ecall

.data
.balign 32
.global stack
stack:
  .zero 20000
stack_end:
.globl ss
ss:
  .zero 32

.balign 32

.globl ct
ct:
    .word 0x03aefff8
    .word 0x56e126ca
    .word 0x62a53aaf
    .word 0x5941f8e6
    .word 0x983a6d59
    .word 0xa42de45a
    .word 0xba7151e4
    .word 0xfe1c8a7c
    .word 0xfd9e54e2
    .word 0x274b41dc
    .word 0x207969ff
    .word 0x06a0c8bf
    .word 0xb05116be
    .word 0x918fd1ec
    .word 0xf91d1fc9
    .word 0x782133e6
    .word 0x4045bac3
    .word 0xc5c09970
    .word 0xc8e923c2
    .word 0x97ed4b8d
    .word 0xe1a3d842
    .word 0xf46a1c25
    .word 0x9ff73cb0
    .word 0x74d87126
    .word 0xeb867c6e
    .word 0x540c0f27
    .word 0x692f36b3
    .word 0x9f538713
    .word 0x68167b5e
    .word 0x1f1cb50a
    .word 0xd498d093
    .word 0x8869b80c
    .word 0xb19eae27
    .word 0x19525fa8
    .word 0x61d58995
    .word 0x4011fba0
    .word 0xab88d8fa
    .word 0xe0fc030b
    .word 0x101d9d3a
    .word 0xe2fff069
    .word 0x3f2f3674
    .word 0x406e651b
    .word 0xef75302e
    .word 0xcdfd9cc2
    .word 0x63413a3d
    .word 0xb1e64cf7
    .word 0x62f46c56
    .word 0x4a54146d
    .word 0xf5dd332a
    .word 0xaf120686
    .word 0x6b7c335d
    .word 0xe0eaa755
    .word 0x01ca2214
    .word 0x59aa2b88
    .word 0xa6dd9e1f
    .word 0xfd2b6e97
    .word 0x7b2745f9
    .word 0xdb5c144c
    .word 0xb6225fea
    .word 0x6197dd36
    .word 0x18c5edf8
    .word 0xfd2332c3
    .word 0xe371d746
    .word 0x6db25697
    .word 0x8d7935fd
    .word 0xf971a03a
    .word 0x2250220d
    .word 0xc569480d
    .word 0x02ad3c9b
    .word 0x6e781e0b
    .word 0xd256c8b8
    .word 0xa1ff33ab
    .word 0x1cb65f60
    .word 0xde641cb9
    .word 0x1dcc5f69
    .word 0x9406ba61
    .word 0xcb36531b
    .word 0xb448e667
    .word 0xb2f27a19
    .word 0xd2eef497
    .word 0x216e99df
    .word 0xbfe0633d
    .word 0xc4864ab5
    .word 0x9d6a287b
    .word 0x0d585950
    .word 0xe40740ad
    .word 0x44b96fdc
    .word 0xf31737a5
    .word 0xb64ed925
    .word 0x3ec114a5
    .word 0x8e5f44fc
    .word 0xe3fdbf4e
    .word 0x950bb0d7
    .word 0x82ceeb5a
    .word 0x68954e6e
    .word 0x69ebe4c5
    .word 0x52bef3e0
    .word 0xcb41b4c7
    .word 0x44ee097f
    .word 0x5810c01b
    .word 0xdecc3a18
    .word 0x8873940a
    .word 0x999cf01b
    .word 0x51c6862a
    .word 0x5aee1913
    .word 0x00a86ff7
    .word 0xea11de79
    .word 0x099d8b7c
    .word 0x3408c347
    .word 0xa886655a
    .word 0x0ad0a5ed
    .word 0x4663a2a7
    .word 0x0cc9e2c3
    .word 0x2ee50917
    .word 0x2e29cae7
    .word 0x2bc2e189
    .word 0x9a444754
    .word 0x0fba08e5
    .word 0xe301c8e2
    .word 0x2ed1f6a0
    .word 0xd93bc922
    .word 0x19ce198d
    .word 0xd255a09a
    .word 0xdd1f4309
    .word 0xb5ea6bc4
    .word 0xd6fa20db
    .word 0xe1933bb5
    .word 0x5e7823e7
    .word 0x86d429bc
    .word 0x6a0d24fb
    .word 0x3e681348
    .word 0x05ff712e
    .word 0xb53ef5b4
    .word 0x2c8c067c
    .word 0xddb0f035
    .word 0x7be1d8ab
    .word 0x7747f848
    .word 0x7ad9d147
    .word 0xd13454ff
    .word 0xdde19cf0
    .word 0xbbc25d32
    .word 0x3d52795f
    .word 0xd35d18d4
    .word 0xb629368d
    .word 0x25763fe8
    .word 0xd6dcbb7b
    .word 0xdf1e3b96
    .word 0x5644dffb
    .word 0x64d2a6c6
    .word 0x085d031f
    .word 0x7f3aeea7
    .word 0xd36c041c
    .word 0xb90a55be
    .word 0x68fc5338
    .word 0xe1e01399
    .word 0xa13ba836
    .word 0x8f8d945f
    .word 0x6efd9c22
    .word 0x2f9cd112
    .word 0x7df1c9dd
    .word 0x8ab2e4fd
    .word 0x0409ac7e
    .word 0x374f1d3f
    .word 0x3192d4dd
    .word 0xd737e851
    .word 0x4dfcc9c9
    .word 0x7615dec9
    .word 0xf6506b68
    .word 0x40744493
    .word 0x9d43532d
    .word 0xba15a045
    .word 0x03c35865
    .word 0xb3e17125
    .word 0xe6c73b26
    .word 0xd149d5ca
    .word 0x49dd0f05
    .word 0x20cbb5f9
    .word 0x3b54cf24
    .word 0xb606b76f
    .word 0x546b1036
    .word 0xeaf838e9
    .word 0xbd9c4d66
    .word 0x4270ff75
    .word 0x54819ded
    .word 0x5d25da6b
    .word 0x35737d17
    .word 0xb506dfa7
    .word 0x8cc9edd0
    .word 0x8f317866
    .word 0x75ed3171
    .word 0x4d34d564
    .word 0x240248f5
    .word 0x2e504411
    .word 0x7b05cbed
    .word 0x3f1dcae3
    .word 0xa75fc6f8
    .word 0xdc217548
    .word 0x92b44d9d
    .word 0x15f8df65
    .word 0xa1e24c8b
    .word 0xbc993389
    .word 0xd2fcbbb4
    .word 0xc2d9f7c3
    .word 0xcded6e28
    .word 0x26805176
    .word 0x106f58d6
    .word 0x47029ea7
    .word 0xf98ffd7e
    .word 0x12b03139
    .word 0x0fadc610
    .word 0x623ad275
    .word 0x204480f6
    .word 0x27dd9705
    .word 0x9babeb7c
    .word 0x4cc7215c
    .word 0x634bd75c
    .word 0x97d5b6a8
    .word 0x0cc5f589
    .word 0x6c67e6ac
    .word 0xb20d9993
    .word 0x9ef3b4f7
    .word 0xac55f400
    .word 0x36122c00
    .word 0x0cfd7b7d
    .word 0xf07e32b0
    .word 0x8253c477
    .word 0x554245f0
    .word 0x941ae1b2
    .word 0x8b605422
    .word 0x01891bc4
    .word 0xe338be72
    .word 0xd00ed2ed
    .word 0x0670c328
    .word 0x90d56eaa
    .word 0x4761787c
    .word 0x7e3be548
    .word 0x7c2a24e3
    .word 0x2e550010
    .word 0x547ab6dd
    .word 0x0888fe36
    .word 0xe99936d5
    .word 0x0f193cbb
    .word 0x1f6a965b
    .word 0x68dab1db
    .word 0x0d63fce8
    .word 0xf5631c84
    .word 0x1b16e7fb
    .word 0xbf7006aa
    .word 0x613e0c97
    .word 0x2cc1aa7a
    .word 0x1d3cff83
    .word 0x741b7619
    .word 0x1f5f6821
    .word 0xeb939c6c
    .word 0x540e9035
    .word 0xd94407f1
    .word 0x4e444d0f
    .word 0x2a5ec406
    .word 0xa9f1ae9f
    .word 0x2d750b6f
    .word 0x86dff14d
    .word 0x8d3d50a9
    .word 0xa6f8cd99
    .word 0x4a182226
    .word 0xdf199e91
    .word 0x01e73082
    .word 0x1a415f7d
    .word 0x4b30da89
    .word 0xc33ce667
    .word 0xf901d9e3
    .word 0xca63f598
    .word 0xbec9d49b
.globl dk
dk:
    .word 0xdf849385
    .word 0xa607c2c0
    .word 0xbccb6c46
    .word 0xdf267c50
    .word 0xe013a4ec
    .word 0x0ce3466e
    .word 0x572885f1
    .word 0x08c1767b
    .word 0x6e1b1ec3
    .word 0x04418bfa
    .word 0x15b24f4a
    .word 0x91f33f2d
    .word 0xb54364bc
    .word 0x65ae6070
    .word 0xbafc0e5b
    .word 0x329088bc
    .word 0xd286c9ec
    .word 0x3c1544a1
    .word 0x5c508981
    .word 0x14bbc637
    .word 0x8ceae571
    .word 0x0d772115
    .word 0xa1882e73
    .word 0x4e62b0a3
    .word 0x66422a5a
    .word 0x6743171c
    .word 0x6b299175
    .word 0x69714481
    .word 0xf8605163
    .word 0x1cf3610d
    .word 0x355d0a42
    .word 0xa3feadf5
    .word 0xbe54427e
    .word 0x191e7439
    .word 0x2c085670
    .word 0x0a39d91b
    .word 0x632a0b03
    .word 0xa5df37fc
    .word 0x1d09ae61
    .word 0x6411dad9
    .word 0x6440b79b
    .word 0xc28b8364
    .word 0x2324873c
    .word 0x345e51b7
    .word 0x2b86fb44
    .word 0xec1bd5a7
    .word 0x459bcfab
    .word 0x0529308f
    .word 0xd083f9cf
    .word 0x89ad7805
    .word 0x43216768
    .word 0x2b782122
    .word 0xe034a1a7
    .word 0x87a7bb52
    .word 0x4c65369a
    .word 0x3b4c1e08
    .word 0x761c5a61
    .word 0xfb8a124c
    .word 0xd8f09ed7
    .word 0xafe5c716
    .word 0x44515a13
    .word 0x3ccf148c
    .word 0x22e07261
    .word 0x9d881b74
    .word 0x08c285a4
    .word 0xbb909189
    .word 0x0b09b82c
    .word 0x21f8b7d2
    .word 0x90e01332
    .word 0x3c9c7ab2
    .word 0x0287bf56
    .word 0x00e3d24b
    .word 0x1b03ea1c
    .word 0x9b950ee2
    .word 0x8152a7c1
    .word 0x9f63a3b8
    .word 0xf4127c48
    .word 0x45e58607
    .word 0x7d74148b
    .word 0x290e5e96
    .word 0xa4d64749
    .word 0x3849d487
    .word 0xd02908d5
    .word 0x08913a72
    .word 0x6e37b906
    .word 0x41014876
    .word 0xcf570796
    .word 0x03ace237
    .word 0x7a76a6b4
    .word 0x691a3868
    .word 0x275cb4f6
    .word 0x00b8624c
    .word 0x991c3c40
    .word 0xd3840b2d
    .word 0x6b0d5636
    .word 0xa3d4fe4b
    .word 0x3ccadc8e
    .word 0x319d6961
    .word 0x8cb86bcb
    .word 0xc69c9010
    .word 0xc91b1d08
    .word 0x04f649a5
    .word 0xf2763537
    .word 0x454db1b5
    .word 0x765cec3e
    .word 0x9fa3b573
    .word 0x226a8bfa
    .word 0x9f017239
    .word 0x0b30e70e
    .word 0x74a72dc8
    .word 0x3641e414
    .word 0xc88fb648
    .word 0xc61db5e7
    .word 0x0983f0cb
    .word 0x2c2f1a8c
    .word 0x2ae580c6
    .word 0x64897a9e
    .word 0xf12dcbea
    .word 0xd6a18d8b
    .word 0x98723103
    .word 0x17bc97b7
    .word 0x33a04e52
    .word 0x413bba76
    .word 0xb2b1f10f
    .word 0xebd32635
    .word 0x3855827a
    .word 0xd9c59307
    .word 0x491e8638
    .word 0x3cd2d483
    .word 0xbb343aad
    .word 0xdc346425
    .word 0x0cc415c3
    .word 0x219d0a8d
    .word 0xb795a532
    .word 0x55b6fb8d
    .word 0x1a36f2f9
    .word 0x70479037
    .word 0xcfe50064
    .word 0xc74a65a1
    .word 0x071c8479
    .word 0x1d8cac67
    .word 0x595472d2
    .word 0xf3d93791
    .word 0xcd285335
    .word 0xe181e534
    .word 0x4cd6bde1
    .word 0x29aa2e08
    .word 0x1016f7a7
    .word 0x886657b6
    .word 0x1004a82c
    .word 0x5ebce06c
    .word 0x440a6320
    .word 0x7df85fbc
    .word 0xcfc291b4
    .word 0x15b34677
    .word 0xbd3aa00b
    .word 0xd8967090
    .word 0x03a24f00
    .word 0x4f15fb84
    .word 0xbb593655
    .word 0x9cc051c4
    .word 0x30a4420d
    .word 0xc24c9935
    .word 0x8b794f4b
    .word 0xc661c9c7
    .word 0xf2924cc6
    .word 0x14873ec6
    .word 0x82e9899d
    .word 0x7f33a921
    .word 0x2632970a
    .word 0x95567055
    .word 0xab05bc2b
    .word 0xecc746ba
    .word 0x72b2e16c
    .word 0x6887041a
    .word 0xf6cf167c
    .word 0xbdd50cb5
    .word 0xa73c4459
    .word 0x48383565
    .word 0x3e3242aa
    .word 0x6c77d3be
    .word 0xd8604d01
    .word 0xb3d6b6a6
    .word 0x116fe21d
    .word 0x992258c1
    .word 0x6cf74912
    .word 0x5d733031
    .word 0xd4d5222c
    .word 0x340a55b4
    .word 0x49430028
    .word 0x293f3e07
    .word 0x3a6c286a
    .word 0xc372650d
    .word 0x27fdb383
    .word 0x5ac83974
    .word 0x582bb403
    .word 0x77b5974c
    .word 0x5b672d9a
    .word 0x9424e06d
    .word 0x87aa3894
    .word 0xc9ebae00
    .word 0xc810caff
    .word 0x6bca27b3
    .word 0x9d897b91
    .word 0xc417d83e
    .word 0x28df3c54
    .word 0x2e9c488b
    .word 0x952faaf3
    .word 0x68b010f3
    .word 0xaa813e8e
    .word 0x71550083
    .word 0x67522a81
    .word 0x1cc21a78
    .word 0x1fc4f792
    .word 0x48e79d35
    .word 0x2491c177
    .word 0x3a2b46fa
    .word 0x85d81b18
    .word 0x4f53c3a3
    .word 0xfe9ad916
    .word 0x436abba4
    .word 0xc977e14c
    .word 0x80c82090
    .word 0xd28f36eb
    .word 0x72112611
    .word 0xe47abbf0
    .word 0xaac90f27
    .word 0x98b5fd6d
    .word 0x9f061c5a
    .word 0x27e91518
    .word 0xcd24ee7b
    .word 0x0cbaecb1
    .word 0x81c4c3f2
    .word 0xa240f500
    .word 0xf950404e
    .word 0x808676b3
    .word 0x36518098
    .word 0x0c1573e6
    .word 0xea737b95
    .word 0xb0ba7b3e
    .word 0xd259b476
    .word 0x509e7e15
    .word 0x0b503417
    .word 0xb974b5d2
    .word 0xcaa763c5
    .word 0x6c3bd88a
    .word 0x7276ecfb
    .word 0x613c1d7b
    .word 0x8f9589c2
    .word 0xe65a80c8
    .word 0x525a45e4
    .word 0x3890e857
    .word 0x1251e354
    .word 0x1846cdb7
    .word 0x3963a15e
    .word 0xe13808dc
    .word 0xba1c9718
    .word 0x5f02785a
    .word 0x33947486
    .word 0x9bb78aa3
    .word 0x88e6e658
    .word 0x0e470350
    .word 0x17358720
    .word 0x38d7827f
    .word 0x2da5f7c3
    .word 0x2a748b84
    .word 0xa515d175
    .word 0x5091f428
    .word 0xbb2f6378
    .word 0x66459163
    .word 0x304c508b
    .word 0x2969b9ab
    .word 0x5dec5fa7
    .word 0x7309e9ea
    .word 0x681d43b2
    .word 0x8dc9745f
    .word 0x3b26db36
    .word 0xd7736cbb
    .word 0x3e997419
    .word 0x4202b513
    .word 0x26107116
    .word 0x06b48e2a
    .word 0x1e4887c9
    .word 0x0644cdaa
    .word 0xb9c2539d
    .word 0xd23d0067
    .word 0xd879b9dc
    .word 0x23f6971a
    .word 0xc44b3451
    .word 0x30206b0a
    .word 0x408c9183
    .word 0xa29e45aa
    .word 0x519208e2
    .word 0x62554947
    .word 0xb34c5394
    .word 0xf148b9e3
    .word 0x41a9f7c0
    .word 0x7498e4fd
    .word 0x3a9709c6
    .word 0x115b844e
    .word 0x4b975624
    .word 0x7798af3a
    .word 0x7e9b15b3
    .word 0x23c4c4d0
    .word 0x8b8a9c88
    .word 0x40335b1c
    .word 0x266b8c9a
    .word 0x66a673f5
    .word 0xc7e05f8a
    .word 0x28cad04a
    .word 0x7a1c4d30
    .word 0xbc938a49
    .word 0x391d9208
    .word 0x982f0443
    .word 0xccab3864
    .word 0xc658a361
    .word 0xa5392848
    .word 0x045b8424
    .word 0xcb16caff
    .word 0xb57d1f74
    .word 0xb9d7afb0
    .word 0x536b4b87
    .word 0xe0b356d1
    .word 0x1ed4b336
    .word 0xac273b96
    .word 0x11b4870c
    .word 0x59716443
    .word 0x5e630110
    .word 0x3a904064
    .word 0x2a30380b
    .word 0x7f77c892
    .word 0x29e54d26
    .word 0x11e5d10d
    .word 0x680a7cbc
    .word 0x826826e3
    .word 0xac30ddce
    .word 0x968592a8
    .word 0x28fbafb7
    .word 0x11874db9
    .word 0x9e8c1ae3
    .word 0x56a9c25a
    .word 0x0d63557b
    .word 0x7e62f85f
    .word 0x08643852
    .word 0xc23bbba1
    .word 0x7c0ab9d6
    .word 0xaa4ac033
    .word 0x6e04e960
    .word 0x419bd810
    .word 0xe2e3b8fb
    .word 0xc127bc6c
    .word 0x144162c0
    .word 0xd622cc36
    .word 0x1c02dd37
    .word 0x72693bb9
    .word 0x5cee7acb
    .word 0x0064ad98
    .word 0x70d00c6b
    .word 0xd499adb0
    .word 0x858c1567
    .word 0x66882b85
    .word 0x29dea16b
    .word 0x7304a3cf
    .word 0xdcbda596
    .word 0xabafb176
    .word 0x2e622da6
    .word 0xe146f817
    .word 0x67a18774
    .word 0x07459bca
    .word 0x6e520903
    .word 0x649187e0
    .word 0xb781ee7c
    .word 0xa91cf2af
    .word 0xa7097d7c
    .word 0x0d88a2b0
    .word 0x610411b0
    .word 0xf5a868f1
    .word 0x5804faba
    .word 0x17323764
    .word 0x22d15eb0
    .word 0x0ab0d03f
    .word 0xe310781d
    .word 0xe65cc141
    .word 0x26e86795
    .word 0x8b911051
    .word 0x46257f85
    .word 0x1d76b5be
    .word 0xde9f84e3
    .word 0xc62c1e97
    .word 0xc063c349
    .word 0x2d6e29ef
    .word 0x49074bc9
    .word 0x1b856998
    .word 0x482203a3
    .word 0x2928a6e4
    .word 0x6f6c624d
    .word 0x3025c438
    .word 0xd65279a0
    .word 0x01654bb4
    .word 0x8d7cf712
    .word 0x9193c5f5
    .word 0x810c0902
    .word 0xf361db88
    .word 0xc4933e71
    .word 0xc9612aa2
    .word 0xea79ea1f
    .word 0x4413bb06
    .word 0x38d6cca5
    .word 0xa840f512
    .word 0xf6fc7f90
    .word 0x34d7bd2f
    .word 0x9540744a
    .word 0x50f65dbc
    .word 0x36f8dc47
    .word 0xf9bf382a
    .word 0x98605b2b
    .word 0x62e93a89
    .word 0x9f19f486
    .word 0x35c57d85
    .word 0x0422961b
    .word 0x21947b80
    .word 0x000f2a60
    .word 0xb6822a22
    .word 0xaf5d78f4
    .word 0xf9543330
    .word 0x74cb97c0
    .word 0xbf3c72a0
    .word 0xc45305da
    .word 0x4e45b4b0
    .word 0x691cd11e
    .word 0xe96b3926
    .word 0x60d15cad
    .word 0xa133d311
    .word 0x23e180a8
    .word 0x54434293
    .word 0x84a07627
    .word 0x44cc0c8b
    .word 0x7c11cb2b
    .word 0x422c9824
    .word 0x681005d1
    .word 0x4a537d3e
    .word 0x31667cc4
    .word 0x0387b1ac
    .word 0x7d8b099d
    .word 0x68b851e5
    .word 0x42fc8fa2
    .word 0xae532211
    .word 0x4c6ff8f0
    .word 0x80778c35
    .word 0x0c0cb317
    .word 0x4e251035
    .word 0x6650bf6a
    .word 0x194cb54f
    .word 0x79bbac7b
    .word 0x35a9320c
    .word 0xc8933078
    .word 0x5cb62789
    .word 0x696c695c
    .word 0x844aab5c
    .word 0x1922265b
    .word 0xf0c439c6
    .word 0x3966cf7d
    .word 0x1d4b0914
    .word 0x41d08db5
    .word 0xbcc6d705
    .word 0x2d39b632
    .word 0x54f91b48
    .word 0x75acacab
    .word 0xbd30cb70
    .word 0x55e965f2
    .word 0xa3f31dac
    .word 0xc859ab56
    .word 0xdbc60c9b
    .word 0x8541cf7e
    .word 0xafa91bf8
    .word 0x47caa87b
    .word 0x78a269bf
    .word 0x821c1c68
    .word 0x48bbca16
    .word 0x2066a387
    .word 0x46761841
    .word 0x509d2069
    .word 0xc83be62b
    .word 0xe72914f2
    .word 0x1b384b43
    .word 0x535cc955
    .word 0x334e86da
    .word 0x81e7133c
    .word 0x8a784486
    .word 0xa4151238
    .word 0xa0f34c95
    .word 0x7ce2da38
    .word 0x134b68a4
    .word 0x6c436802
    .word 0x00a12fc2
    .word 0xd643d8eb
    .word 0xd00da2d9
    .word 0x8dbcc4b8
    .word 0xd39f8956
    .word 0xa12c27e4
    .word 0x42c91a30
    .word 0x7a978699
    .word 0xa710499a
    .word 0x29069985
    .word 0xf27efcdf
    .word 0x64aa3a09
    .word 0x5e824167
    .word 0x436cac53
    .word 0x62b562b9
    .word 0xa5314d4a
    .word 0x6a4354e0
    .word 0x04887b2b
    .word 0x6220a560
    .word 0xb2c9c5e4
    .word 0xdc2522e7
    .word 0x4dd45523
    .word 0x182ab2d6
    .word 0x09056aca
    .word 0xb2d3f84b
    .word 0x138cc5a0
    .word 0x44be7b77
    .word 0x2b18d08f
    .word 0x6e596a87
    .word 0xe7d45a59
    .word 0xc1f0b69d
    .word 0x5543e1b4
    .word 0x2b2e8007
    .word 0x25dc9e53
    .word 0xe7230b82
    .word 0xe1557612
    .word 0xaaa5341b
    .word 0x1ac125ff
    .word 0xd77e617b
    .word 0xc9503608
    .word 0xa7620403
    .word 0xe67bb79a
    .word 0x5fa48037
    .word 0xcb6da98c
    .word 0x568e3515
    .word 0x3631dcae
    .word 0x0130200b
    .word 0x67ca8202
    .word 0x9916e5cd
    .word 0x8e80fa93
    .word 0xa0bd75e4
    .word 0x16c249af
    .word 0x330695af
    .word 0x84039b0c
    .word 0x513c2cbd
    .word 0xf0cf14b8
    .word 0x0c533c9b
    .word 0x79e654a7
    .word 0x442ec266
    .word 0xb75086f6
    .word 0x23787f11
    .word 0x9225845d
    .word 0x6b521698
    .word 0x47f6460a
    .word 0x29795aa8
    .word 0x7a679db4
    .word 0x68834138
    .word 0xfd901509
    .word 0x96ee7612
    .word 0x4439e629
    .word 0xb77047db
    .word 0xb2302ec2
    .word 0xb6a5fbcf
    .word 0x129a6ad4
    .word 0x44fab717
    .word 0x66824bb5
    .word 0xb35475f0
    .word 0xc30c97ea
    .word 0xc0921e0d
    .word 0x2ace413f
    .word 0x8af59320
    .word 0x53431a83
    .word 0xcb9323e0
    .word 0x82a56989
    .word 0xec4555d5
    .word 0x0411a639
    .word 0xf05b2eba
    .word 0x57d9d082
    .word 0x26cc8839
    .word 0x27229b08
    .word 0xcf9bd218
    .word 0x5b3665b3
    .word 0x559c52d9
    .word 0x3556baaa
    .word 0xb3090885
    .word 0x91406105
    .word 0xb48b7e24
    .word 0x3a501573
    .word 0xd47e3307
    .word 0x3c9da70c
    .word 0x0d248d8b
    .word 0x8a8cf33a
    .word 0x18ed657a
    .word 0x60927b04
    .word 0xb59ef00f
    .word 0x0e0f8209
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