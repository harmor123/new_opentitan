/* Copyright lowRISC contributors (OpenTitan project). */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */
/*
 * ver1_1 (ML-KEM-768, 官方向量指令实现) —— Encaps 测试/芯片仿真入口 + 内存布局
 *
 * 内存符号与输入向量 (coins/ek) 均取自 ver0_2，可直接复用其期望向量
 * (enc.dexp: ct 1088 B, ss 32 B)。
 */

.section .text.start

.globl main
main:
  /* 清零所有 WDR */
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

  /* 清零 scratchpad (ISS 上为 NOLOAD，需合法 ECC) */
  la   x2, scratch_start
  la   x3, scratch_end
1:
  sw   x0, 0(x2)
  addi x2, x2, 4
  bne  x2, x3, 1b

  la   x10, coins
  la   x11, ct
  la   x12, ss
  la   x13, ek
  jal  x1, crypto_kem_enc

  ecall

.globl stack
.globl _expand_buf
.globl poly_slot0
.globl poly_slot1
.globl poly_slot2
.globl poly_slot_y_hat
.globl keygen_scale_const_2988
.globl pk_t
.globl pk_rho
.globl res_ok
.globl _seed_buf
.globl const_3328_vec
.globl const_2988_wdr

.section .scratchpad
.balign 32
.globl scratch_start
scratch_start:

stack:
  .zero 1024

_expand_buf:
  .zero 672

poly_slot0:
  .zero 1024
poly_slot1:
  .zero 1024
poly_slot2:
  .zero 1024
poly_slot_y_hat:
  .zero 3072

.balign 32
keygen_scale_const_2988:
  .zero 1024

.balign 32
.globl scratch_end
scratch_end:

.data
.balign 32

.globl ct
ct:
  .zero 1088

.globl ss
ss:
  .zero 32

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

/* ---- 内部工作缓冲 ---- */
.balign 32
pk_t:
  .zero 1152
pk_rho:
  .zero 32
res_ok:
  .zero 4
_seed_buf:
  .zero 160

.balign 32
const_3328_vec:
.word 3328, 3328, 3328, 3328, 3328, 3328, 3328, 3328

/* ---- ML-KEM 常数 ---- */
.balign 32
.globl mlkem768_const_params
mlkem768_const_params:
.word 0x00000d01
.word 0x94570cff
.word 0x00000000
.word 0x00000000
.word 0x00000000
.word 0x00000000
.word 0x00000000
.word 0x00000000

.globl _compress_recip_m
.globl _compress_offset_1664
.globl _compress_modulus_3329
.globl _decompress_const_1665

.balign 32
_compress_recip_m:
.word 1290168, 0, 1290168, 1290168, 1290168, 1290168, 1290168, 1290168

.balign 32
_compress_offset_1664:
.word 1664, 1664, 1664, 1664, 1664, 1664, 1664, 1664

.balign 32
_compress_modulus_3329:
.word 3329, 0x94570cff, 0, 0, 0, 0, 0, 0

.balign 32
_decompress_const_1665:
.word 1665, 1665, 1665, 1665, 1665, 1665, 1665, 1665

.balign 32
const_2988_wdr:
.word 0x00000bac, 0x00000000, 0x00000bac, 0x00000000, 0x00000bac, 0x00000000, 0x00000bac, 0x00000000
