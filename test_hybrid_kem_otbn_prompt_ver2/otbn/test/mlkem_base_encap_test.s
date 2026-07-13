

/* Entry point. */
.globl main
main:

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
  bn.lid  x5++, 0(x6)
  la      x6, modulus_inv
  bn.lid  x5, 0(x6)
  bn.or   w2, w2, w3 << 32 /* MOD = R | Q */
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

.globl modulus_inv
modulus_inv:
  .word 0x00000cff
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
  
.globl const_tomont
const_tomont:
  .word 0x05490549 /* 2^32 % KYBER_Q */
  .word 0x05490549
  .word 0x05490549
  .word 0x05490549
  .word 0x05490549
  .word 0x05490549
  .word 0x05490549
  .word 0x05490549

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
  .half 0x0a0b
  .half 0x0b9a
  .half 0x0714
  .half 0x05d5
  .half 0x058e
  .half 0x011f
  .half 0x00ca
  .half 0x0c56
  .half 0x026e
  .half 0x0629
  .half 0x00b6
  .half 0x03c2
  .half 0x084f
  .half 0x073f
  .half 0x05bc
  /* Padding */
  .half 0x0000
  /* Layer 5 */
  .word 0x023d023d
  .word 0x07d407d4
  .word 0x01080108
  .word 0x017f017f
  .word 0x09c409c4
  .word 0x05b205b2
  .word 0x06bf06bf
  .word 0x0c7f0c7f
  .word 0x0a580a58
  .word 0x03f903f9
  .word 0x02dc02dc
  .word 0x02600260
  .word 0x06fb06fb
  .word 0x019b019b
  .word 0x0c340c34
  .word 0x06de06de
  /* Layer 6 */
  .word 0x04c704c7
  .word 0x0ad90ad9
  .word 0x07f407f4
  .word 0x0be70be7
  .word 0x02040204
  .word 0x0bc10bc1
  .word 0x06af06af
  .word 0x007e007e
  .word 0x028c028c
  .word 0x03f703f7
  .word 0x05d305d3
  .word 0x06f906f9
  .word 0x0cf90cf9
  .word 0x0a670a67
  .word 0x08770877
  .word 0x05bd05bd
  .word 0x09ac09ac
  .word 0x0bf20bf2
  .word 0x006b006b
  .word 0x0c0a0c0a
  .word 0x0b730b73
  .word 0x071d071d
  .word 0x01c001c0
  .word 0x02a502a5
  .word 0x0ca70ca7
  .word 0x033e033e
  .word 0x07740774
  .word 0x094a094a
  .word 0x03c103c1
  .word 0x0a2c0a2c
  .word 0x08d808d8
  .word 0x08060806
  /* Layer 7 */
  .word 0x08b208b2
  .word 0x081e081e
  .word 0x01a601a6
  .word 0x0bde0bde
  .word 0x0c0b0c0b
  .word 0x09f809f8
  .word 0x06cb06cb
  .word 0x01a201a2
  .word 0x01ae01ae
  .word 0x03670367
  .word 0x024b024b
  .word 0x0b350b35
  .word 0x030a030a
  .word 0x05cb05cb
  .word 0x02840284
  .word 0x01490149
  .word 0x022b022b
  .word 0x060e060e
  .word 0x00b100b1
  .word 0x06260626
  .word 0x04870487
  .word 0x0aa70aa7
  .word 0x09990999
  .word 0x0c650c65
  .word 0x034b034b
  .word 0x00690069
  .word 0x0c160c16
  .word 0x06750675
  .word 0x0c6e0c6e
  .word 0x045f045f
  .word 0x015d015d
  .word 0x0cb60cb6
  .word 0x03310331
  .word 0x052a052a
  .word 0x08420842
  .word 0x09970997
  .word 0x08600860
  .word 0x071b071b
  .word 0x0c950c95
  .word 0x03be03be
  .word 0x04490449
  .word 0x07fc07fc
  .word 0x0c790c79
  .word 0x00dc00dc
  .word 0x07070707
  .word 0x09ab09ab
  .word 0x0bcd0bcd
  .word 0x074d074d
  .word 0x025b025b
  .word 0x07480748
  .word 0x04c204c2
  .word 0x085e085e
  .word 0x08030803
  .word 0x099b099b
  .word 0x03e403e4
  .word 0x05f205f2
  .word 0x02620262
  .word 0x01800180
  .word 0x07ca07ca
  .word 0x06860686
  .word 0x031a031a
  .word 0x01de01de
  .word 0x03df03df
  .word 0x065c065c

.globl twiddles_intt
twiddles_intt:
  /* Layer 7 */
  .word 0x06a506a5
  .word 0x09220922
  .word 0x0b230b23
  .word 0x09e709e7
  .word 0x067b067b
  .word 0x05370537
  .word 0x0b810b81
  .word 0x0a9f0a9f
  .word 0x070f070f
  .word 0x091d091d
  .word 0x03660366
  .word 0x04fe04fe
  .word 0x04a304a3
  .word 0x083f083f
  .word 0x05b905b9
  .word 0x0aa60aa6
  .word 0x05b405b4
  .word 0x01340134
  .word 0x03560356
  .word 0x05fa05fa
  .word 0x0c250c25
  .word 0x00880088
  .word 0x05050505
  .word 0x08b808b8
  .word 0x09430943
  .word 0x006c006c
  .word 0x05e605e6
  .word 0x04a104a1
  .word 0x036a036a
  .word 0x04bf04bf
  .word 0x07d707d7
  .word 0x09d009d0
  .word 0x004b004b
  .word 0x0ba40ba4
  .word 0x08a208a2
  .word 0x00930093
  .word 0x068c068c
  .word 0x00eb00eb
  .word 0x0c980c98
  .word 0x09b609b6
  .word 0x009c009c
  .word 0x03680368
  .word 0x025a025a
  .word 0x087a087a
  .word 0x06db06db
  .word 0x0c500c50
  .word 0x06f306f3
  .word 0x0ad60ad6
  .word 0x0bb80bb8
  .word 0x0a7d0a7d
  .word 0x07360736
  .word 0x09f709f7
  .word 0x01cc01cc
  .word 0x0ab60ab6
  .word 0x099a099a
  .word 0x0b530b53
  .word 0x0b5f0b5f
  .word 0x06360636
  .word 0x03090309
  .word 0x00f600f6
  .word 0x01230123
  .word 0x0b5b0b5b
  .word 0x04e304e3
  .word 0x044f044f
  /* Layer 6 */
  .word 0x04fb04fb
  .word 0x04290429
  .word 0x02d502d5
  .word 0x09400940
  .word 0x03b703b7
  .word 0x058d058d
  .word 0x09c309c3
  .word 0x005a005a
  .word 0x0a5c0a5c
  .word 0x0b410b41
  .word 0x05e405e4
  .word 0x018e018e
  .word 0x00f700f7
  .word 0x0c960c96
  .word 0x010f010f
  .word 0x03550355
  .word 0x07440744
  .word 0x048a048a
  .word 0x029a029a
  .word 0x00080008
  .word 0x06080608
  .word 0x072e072e
  .word 0x090a090a
  .word 0x0a750a75
  .word 0x0c830c83
  .word 0x06520652
  .word 0x01400140
  .word 0x0afd0afd
  .word 0x011a011a
  .word 0x050d050d
  .word 0x02280228
  .word 0x083a083a
  /* Layer 5 */
  .word 0x06230623
  .word 0x00cd00cd
  .word 0x0b660b66
  .word 0x06060606
  .word 0x0aa10aa1
  .word 0x0a250a25
  .word 0x09080908
  .word 0x02a902a9
  .word 0x00820082
  .word 0x06420642
  .word 0x074f074f
  .word 0x033d033d
  .word 0x0b820b82
  .word 0x0bf90bf9
  .word 0x052d052d
  .word 0x0ac40ac4
  /* Layer 4--2 */
  .half 0x0745
  .half 0x05c2
  .half 0x04b2
  .half 0x093f
  .half 0x0c4b
  .half 0x06d8
  .half 0x0a93
  .half 0x00ab
  .half 0x0c37
  .half 0x0be2
  .half 0x0773
  .half 0x072c
  .half 0x05ed
  .half 0x0167
  /* Layer 1 */
  .half 0x078c /* ((758*2^16) mod KYBER_Q)*(1/128) mod KYBER_Q */
  /* [(2^32 mod KYBER_Q)*(1/128)] mod KYBER_Q */
  .half 0x05a1

.globl twiddles_basemul
twiddles_basemul:
  .word 0x081e08b2
  .word 0x04e3044f
  .word 0x036701ae
  .word 0x099a0b53
  .word 0x060e022b
  .word 0x06f30ad6
  .word 0x0069034b
  .word 0x0c9809b6

  .word 0x0bde01a6
  .word 0x01230b5b
  .word 0x0b35024b
  .word 0x01cc0ab6
  .word 0x062600b1
  .word 0x06db0c50
  .word 0x06750c16
  .word 0x068c00eb

  .word 0x09f80c0b
  .word 0x030900f6
  .word 0x05cb030a
  .word 0x073609f7
  .word 0x0aa70487
  .word 0x025a087a
  .word 0x045f0c6e
  .word 0x08a20093

  .word 0x01a206cb
  .word 0x0b5f0636
  .word 0x01490284
  .word 0x0bb80a7d
  .word 0x0c650999
  .word 0x009c0368
  .word 0x0cb6015d
  .word 0x004b0ba4

  .word 0x052a0331
  .word 0x07d709d0
  .word 0x07fc0449
  .word 0x050508b8
  .word 0x0748025b
  .word 0x05b90aa6
  .word 0x01800262
  .word 0x0b810a9f

  .word 0x09970842
  .word 0x036a04bf
  .word 0x00dc0c79
  .word 0x0c250088
  .word 0x085e04c2
  .word 0x04a3083f
  .word 0x068607ca
  .word 0x067b0537

  .word 0x071b0860
  .word 0x05e604a1
  .word 0x09ab0707
  .word 0x035605fa
  .word 0x099b0803
  .word 0x036604fe
  .word 0x01de031a
  .word 0x0b2309e7

  .word 0x03be0c95
  .word 0x0943006c
  .word 0x074d0bcd
  .word 0x05b40134
  .word 0x05f203e4
  .word 0x070f091d
  .word 0x065c03df
  .word 0x06a50922
