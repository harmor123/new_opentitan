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
    .word 0x5f5a833b
    .word 0x7a3845a1
    .word 0xdac41908
    .word 0xbe5fe6a1
    .word 0x0a40a52b
    .word 0xbb40d6fc
    .word 0x58e3bbdd
    .word 0xddbe245f
    .word 0x94962851
    .word 0x3c64fea4
    .word 0x8e9cafd5
    .word 0xf1c377b2
    .word 0x7a347a87
    .word 0x8aeaeb97
    .word 0xc6717903
    .word 0xe49379b3
    .word 0x58afcf33
    .word 0x7f4bba0e
    .word 0x540d99da
    .word 0xca604dbf
    .word 0xfccad1f9
    .word 0x56d97f47
    .word 0x0b07e6f8
    .word 0x77c6ee6a
    .word 0x8314b86e
    .word 0xf7b50754
    .word 0x7294db05
    .word 0xe0161d70
    .word 0x4a025506
    .word 0xdd149b30
    .word 0x22d236bf
    .word 0x479650bb
    .word 0xd549a0a5
    .word 0xad496f81
    .word 0xdd75299f
    .word 0xf02d4cb6
    .word 0x4cb2fe5f
    .word 0xa7243f6a
    .word 0xf6f4db86
    .word 0xc56f66d5
    .word 0x3935b75f
    .word 0x5bc19d67
    .word 0x6c4ffb72
    .word 0x28eb8fe3
    .word 0x08c9281d
    .word 0xb75d19d5
    .word 0x97158300
    .word 0xc6d2f98e
    .word 0xccdbc47d
    .word 0x7a466249
    .word 0x23f7442d
    .word 0xbd4ea55f
    .word 0x32ecbd88
    .word 0x7a1f8b40
    .word 0x20841bff
    .word 0x51560764
    .word 0xfd3a3af0
    .word 0x1fed2127
    .word 0x871affe4
    .word 0xd9b4c675
    .word 0x54556457
    .word 0xf8f2cf12
    .word 0x900444aa
    .word 0x5f58330f
    .word 0x09b7d10b
    .word 0x01f8cf55
    .word 0x40c2dc30
    .word 0x74e92039
    .word 0xa90d3d4a
    .word 0x61554014
    .word 0x32bbb2ec
    .word 0xdb7a0b12
    .word 0xe9d8f4d2
    .word 0x30467ba0
    .word 0xf88d0b48
    .word 0x4f9368c0
    .word 0xb8c99bfd
    .word 0xee88a855
    .word 0x210f09ca
    .word 0x74e00519
    .word 0x68ab78a0
    .word 0x45747e91
    .word 0xe3c7c7a6
    .word 0x3c750394
    .word 0x14669be1
    .word 0xab22d2b9
    .word 0xa663f299
    .word 0xc0c6ce81
    .word 0xf07e5837
    .word 0x29f7f051
    .word 0x2865374e
    .word 0xa58917b3
    .word 0x58223430
    .word 0xae991c24
    .word 0xcd4b387d
    .word 0x322a0161
    .word 0x38c677a9
    .word 0xc13b9ab0
    .word 0x47aa336a
    .word 0x127f2dcf
    .word 0xa58a9dd7
    .word 0xc5c8630f
    .word 0x0098433c
    .word 0xba9bedb2
    .word 0x18eb8194
    .word 0xed44421b
    .word 0x69627d06
    .word 0xdf996a5d
    .word 0x8887bfd7
    .word 0xafca59c1
    .word 0xa9fde994
    .word 0x3fa9c52a
    .word 0x7cdfa059
    .word 0x41bd9b0f
    .word 0x45cfb87c
    .word 0x066007d1
    .word 0x589e8ae0
    .word 0x39d7e45e
    .word 0x2a586542
    .word 0x161f6487
    .word 0xdf9ebe53
    .word 0xe6014419
    .word 0xc493eee4
    .word 0x1b4a05ab
    .word 0xbfe3816e
    .word 0xf226fd01
    .word 0x5bdba6e9
    .word 0xd2dbc0f6
    .word 0xe1c2141e
    .word 0xf0cfa4a5
    .word 0x95ed67b2
    .word 0x040b7b42
    .word 0xbc7fff9e
    .word 0x45053b09
    .word 0x23855710
    .word 0xcc327aac
    .word 0xcfdf8e1f
    .word 0x716c8a07
    .word 0x8e78e6e6
    .word 0x7b7ddadf
    .word 0xf775d3ad
    .word 0xafef11d9
    .word 0x6e40cbb9
    .word 0x98c58b96
    .word 0x09fb1894
    .word 0x1cd59e72
    .word 0xaeaec492
    .word 0x84638410
    .word 0xc491a0f4
    .word 0x7785ad05
    .word 0xe8ade03f
    .word 0xd6dfed16
    .word 0xa50eba18
    .word 0xc43cb7de
    .word 0x63e09235
    .word 0x02185101
    .word 0x1e874255
    .word 0x44f8607a
    .word 0xd6c3b2a6
    .word 0xf8c6f930
    .word 0xd2e89157
    .word 0x8f57f3bd
    .word 0xe82826f9
    .word 0xb802afac
    .word 0x7f79798d
    .word 0x1530acb1
    .word 0xadfc0132
    .word 0xd4fb3422
    .word 0xfa84fcf2
    .word 0xfbb62a7d
    .word 0x559b4d2e
    .word 0x1ad91df1
    .word 0x10268779
    .word 0xc342687c
    .word 0x89caa1e7
    .word 0xfea83550
    .word 0xe3581070
    .word 0xbb176e42
    .word 0xe7234cf0
    .word 0x3e28fb8f
    .word 0x631c7e02
    .word 0xdef91c6b
    .word 0x9e90f5d3
    .word 0x63fcb0bc
    .word 0x8c918e60
    .word 0xf7a7a99e
    .word 0xe7ecd3b6
    .word 0x28c1da27
    .word 0x0f7c1bd3
    .word 0x04439efd
    .word 0x3ca5e66a
    .word 0x0e8d8825
    .word 0x02232b60
    .word 0xa8dc55e2
    .word 0xc0108cc5
    .word 0x52912610
    .word 0x8f592c58
    .word 0xf4b8a0dd
    .word 0xa11e313e
    .word 0x0d6ea95b
    .word 0x6f93f39f
    .word 0x1f63185f
    .word 0x2030d0b9
    .word 0x7b6442e3
    .word 0x2ac178e0
    .word 0x4b477594
    .word 0xab55ee3d
    .word 0x80dde3c0
    .word 0x92fd734d
    .word 0x4af96a9b
    .word 0xc327dd67
    .word 0xc9c25f5b
    .word 0xb800e5bc
    .word 0x44983b10
    .word 0x46c7ce23
    .word 0x815b1a23
    .word 0x13eacd9a
    .word 0x0ae71688
    .word 0xa95e0095
    .word 0xb632722f
    .word 0xc072e766
    .word 0x205ef960
    .word 0xdab72e61
    .word 0x347a29d3
    .word 0xc717782a
    .word 0x8a31243e
    .word 0x6215760b
    .word 0xb5b6ccd1
    .word 0xe0cb18d6
    .word 0x7b1e4b6f
    .word 0x836b1b35
    .word 0x7934c81f
    .word 0x94bf34eb
    .word 0xa1b3687b
    .word 0x86ad57b5
    .word 0x6c657268
    .word 0x57e7599f
    .word 0x4de86180
    .word 0xaf00e9ba
    .word 0xf1be0133
    .word 0x42c6a0ea
    .word 0x29304647
    .word 0x5c68bb30
    .word 0x21973d8f
    .word 0x1bd61e52
    .word 0xd5a448b6
    .word 0xbf4e5c33
    .word 0x86f86130
    .word 0x52954139
    .word 0xc8eefe42
    .word 0x82826264
    .word 0xf560f439
    .word 0x10def95c
    .word 0x2756daba
    .word 0x8332d3f9
    .word 0xa0add662
    .word 0xc6f0708f
    .word 0x5b155a5c
    .word 0x5661a62d
    .word 0x55e5aaa6
    .word 0x281337c0
    .word 0xe0284992
    .word 0xaa5d1346
    .word 0xc1868bf4
    .word 0x6fb578ea
    .word 0x79b2af40
    .word 0x964bb74f
    .word 0x3aa4e227
    .word 0x7ae1f3ab
    .word 0xd37aee84
    .word 0xb29ef70c
    .word 0x69ac720a

.globl dk
dk:
    .word 0xb6c70ada
    .word 0x614e4060
    .word 0x80f9a13a
    .word 0x6db30c38
    .word 0x32d218ba
    .word 0x7a26c756
    .word 0xa67ba600
    .word 0x4cb1a2c2
    .word 0x66394241
    .word 0x44bd682f
    .word 0xf3fd8e6c
    .word 0x89a05666
    .word 0x23c63c1a
    .word 0x57b668fc
    .word 0xa6297b2f
    .word 0x148012de
    .word 0x19e41e41
    .word 0x7180d006
    .word 0xe35648f9
    .word 0x402b836a
    .word 0x35748d33
    .word 0xd29b6516
    .word 0x07c07958
    .word 0x58c92ba5
    .word 0x6a87796f
    .word 0xa3c9c6fa
    .word 0x24ac8f0d
    .word 0x2524d23b
    .word 0x42ceadd6
    .word 0x90d37eab
    .word 0x957a7514
    .word 0x45a7c88b
    .word 0x2319f065
    .word 0x344bf04f
    .word 0xd0d63e89
    .word 0x72c30155
    .word 0xae9a2355
    .word 0x8c9fc12a
    .word 0x0059ac75
    .word 0x0d30e8da
    .word 0xdc10a7bb
    .word 0xbce1aa2c
    .word 0x588ca3a3
    .word 0x6b282b34
    .word 0x36f11885
    .word 0xf7b915ad
    .word 0xa506bbbc
    .word 0x75b37d60
    .word 0x4576e9db
    .word 0x59c6267c
    .word 0x1b535782
    .word 0xe76efb2c
    .word 0x849115f5
    .word 0x83c30408
    .word 0x276c3788
    .word 0xda138414
    .word 0x0b92929e
    .word 0x9e069afd
    .word 0x72d28b01
    .word 0x77a83d05
    .word 0x9f730b5c
    .word 0x10b21d76
    .word 0x435af37c
    .word 0x7eb0694d
    .word 0x74b8cd5b
    .word 0x0c8b1334
    .word 0x1b7656b5
    .word 0x74a522a5
    .word 0x7d74287b
    .word 0x6c9deb80
    .word 0xe5be73c6
    .word 0xb9779376
    .word 0xeb6cd396
    .word 0xd97e0c0c
    .word 0x335358a6
    .word 0x189c8624
    .word 0x316fa3a1
    .word 0xc5140f47
    .word 0x07ab49ae
    .word 0x24f80705
    .word 0xb404e49c
    .word 0x3e8c0a9c
    .word 0x96ea2fe4
    .word 0x0d1afa31
    .word 0x936bd810
    .word 0xe3e086f9
    .word 0x3b702ea8
    .word 0x61aee574
    .word 0x21242401
    .word 0x7fa09aa8
    .word 0x468885e6
    .word 0x8736aa0b
    .word 0x726a4886
    .word 0x2d4df2e4
    .word 0x03fc6cd7
    .word 0xbaa594b6
    .word 0xa055a791
    .word 0xf93b8fb9
    .word 0xabc00733
    .word 0xea9a6364
    .word 0xa398647a
    .word 0x71c5ddc3
    .word 0xa4bc1a14
    .word 0xe2d28c67
    .word 0x88fb57b8
    .word 0xa5ca00f6
    .word 0xc44bb496
    .word 0x280b2522
    .word 0x5f51e019
    .word 0x18397204
    .word 0x010b7053
    .word 0x3f45f9ef
    .word 0xb77618d1
    .word 0x7da059c7
    .word 0xbaca45d8
    .word 0x4a265545
    .word 0x93517682
    .word 0x621bf8fd
    .word 0x921f1e0a
    .word 0x4244b23f
    .word 0x94be1ccd
    .word 0xec035017
    .word 0xa377ce06
    .word 0xc19344c6
    .word 0x307a9899
    .word 0x3cc5950c
    .word 0xd6b58900
    .word 0x97ea925c
    .word 0x93fa2f1b
    .word 0x1e462ab5
    .word 0x198caca2
    .word 0x2b4c2f9c
    .word 0xce974270
    .word 0xe049393c
    .word 0xa1a85e73
    .word 0x8d9ea54a
    .word 0x83870cec
    .word 0x7470ff99
    .word 0xce44b27a
    .word 0x23f2b546
    .word 0x3d327304
    .word 0xe66fc625
    .word 0xf4b119b4
    .word 0x21e512a1
    .word 0x6b253540
    .word 0x2bfd3fc4
    .word 0x87377b6b
    .word 0x70b4a669
    .word 0x35b6bf00
    .word 0x4b81457d
    .word 0x7d85f3ae
    .word 0xb82f9e37
    .word 0x1a20e5b5
    .word 0xbb7462b2
    .word 0x32ad701b
    .word 0x9b43d02c
    .word 0xcf09b12d
    .word 0xe6f8a2f0
    .word 0x71559900
    .word 0x598cc3ff
    .word 0x61c7c40b
    .word 0xc9d0695c
    .word 0xf330f48e
    .word 0x72a76108
    .word 0x70c0ff38
    .word 0xd675e461
    .word 0xb4d10aa3
    .word 0xc339d07f
    .word 0x2d7647a4
    .word 0xc31d21b2
    .word 0xcfca0a1d
    .word 0xa59058d5
    .word 0xf9984782
    .word 0x1374adae
    .word 0xb128e0df
    .word 0xb6e82b01
    .word 0x662610ca
    .word 0x94bcc66a
    .word 0xb549a440
    .word 0xa7bbd81a
    .word 0xd41d92b0
    .word 0x78a5b4d8
    .word 0x051a6d13
    .word 0x85cc38db
    .word 0x51b23784
    .word 0xc2c3d161
    .word 0xbc7be08e
    .word 0x1149b2f2
    .word 0x1d78220d
    .word 0x8c0d05c3
    .word 0x960009c0
    .word 0x06858ab3
    .word 0x9e6ef896
    .word 0x5232ab6b
    .word 0x8624b271
    .word 0x68190175
    .word 0x09812850
    .word 0xc0fa9704
    .word 0x1a3c84af
    .word 0x81dd76ea
    .word 0x12c029cf
    .word 0xb72762c6
    .word 0x61996df0
    .word 0x62029b30
    .word 0xa4c932f7
    .word 0x67d0bbd0
    .word 0x37b8ab27
    .word 0x18c1f21f
    .word 0x3798a099
    .word 0x1605465c
    .word 0xbc88ccb2
    .word 0xe3ed28f6
    .word 0x333b8f7d
    .word 0x0a49e442
    .word 0xc06e6085
    .word 0x029ba23d
    .word 0x82532756
    .word 0xc03d31a3
    .word 0x01481141
    .word 0x9f512c03
    .word 0x6a3e0c35
    .word 0x3be3c3ba
    .word 0x9fa1b493
    .word 0xe566547c
    .word 0x14dcb18c
    .word 0x476ca9b4
    .word 0x71f92957
    .word 0xcd73f1bd
    .word 0x4d8254f3
    .word 0xf9279401
    .word 0x4a4a3b5b
    .word 0x478e954a
    .word 0x91696e6a
    .word 0xcb066fce
    .word 0xd4a7fc5d
    .word 0x923d0c38
    .word 0xac11570b
    .word 0x4bafcb1f
    .word 0xb900c89a
    .word 0x76ecd176
    .word 0xc16c626a
    .word 0xb3660b90
    .word 0xc562dca9
    .word 0x7a5244c1
    .word 0x70af6b29
    .word 0x57f63b43
    .word 0x877f43c0
    .word 0xc8d77b59
    .word 0xbc9abebb
    .word 0x31090537
    .word 0x8269a8a4
    .word 0x748a02a2
    .word 0x819b4c45
    .word 0x70d1880c
    .word 0x8ac98c1c
    .word 0x07a14c1d
    .word 0x965eb2a6
    .word 0xb0b6e42f
    .word 0x3245953c
    .word 0x2207b860
    .word 0x9ecc3786
    .word 0x09cc2ab1
    .word 0x529a9554
    .word 0x97d154ae
    .word 0xa0ab0073
    .word 0x60142cba
    .word 0x118cb29b
    .word 0xcac5fad5
    .word 0x609782c8
    .word 0x67e88332
    .word 0x668364a3
    .word 0x35d924c7
    .word 0x96a1d74c
    .word 0x2f80d9db
    .word 0xfad3887b
    .word 0x979c1f00
    .word 0x62542273
    .word 0x35915e23
    .word 0x1f79202a
    .word 0xe37fb8d8
    .word 0xa3c67e37
    .word 0x30110b94
    .word 0xe704bba0
    .word 0xe2340a41
    .word 0x1d070d58
    .word 0x2020566c
    .word 0x657a7886
    .word 0x9343f890
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
    .word 0x666272f5
    .word 0xe8cd5813
    .word 0x90f9ebd3
    .word 0x5b1dfde5
    .word 0x2c996c89
    .word 0x52dbaacf
    .word 0xbf8bb656
    .word 0x32b14359
    .word 0xcfd705b5
    .word 0x74491bad
    .word 0x863c3299
    .word 0x475e3286
    .word 0xaa67f292
    .word 0xca873ffa
    .word 0xb51cd060
    .word 0x2a20294f


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