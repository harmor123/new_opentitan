/* Copyright lowRISC contributors (OpenTitan project). */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */
/*
 * ver1_1 (ML-KEM-768, 官方向量指令实现) —— KeyGen 测试/芯片仿真入口 + 内存布局
 *
 * 内存符号与 ver0_2 一致 (coins/ek/dk)，因此可直接复用 ver0_2 的期望向量
 * (kp.dexp: ek 1184 B, dk 2400 B)。
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

  /* 清零 scratchpad (NOLOAD: ISS 上未初始化, 32B 宽 bn.lid 读取需要合法 ECC) */
  la   x2, scratch_start
  la   x3, scratch_end
1:
  sw   x0, 0(x2)
  addi x2, x2, 4
  bne  x2, x3, 1b

  la   x10, coins
  la   x11, ek
  la   x12, dk
  jal  x1, crypto_kem_keypair

  ecall

.globl stack
.globl _expand_buf
.globl poly_slot0
.globl poly_slot1
.globl poly_slot2
.globl poly_slot_s_hat
.globl keygen_scale_const_2988
.globl seed_d_share0
.globl seed_d_share1
.globl seed_z_share0
.globl seed_z_share1
.globl pk_rho
.globl pk_t
.globl sk_s_share0
.globl sk_hpk
.globl sk_z_share0
.globl sk_z_share1
.globl _seed_buf
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
poly_slot_s_hat:
  .zero 3072

.balign 32
keygen_scale_const_2988:
  .zero 1024

.balign 32
.globl scratch_end
scratch_end:

.data
.balign 32

.globl coins
coins:
    .word 0xa035997c
    .word 0xaa9476b0
    .word 0xe4106d0c
    .word 0xdd1a6bdb
    .word 0x251ad82f
    .word 0x0348b1cc
    .word 0x9973cd2d
    .word 0x2d7f7336
    .word 0xcfd705b5
    .word 0x74491bad
    .word 0x863c3299
    .word 0x475e3286
    .word 0xaa67f292
    .word 0xca873ffa
    .word 0xb51cd060
    .word 0x2a20294f

.globl ek
ek:
  .zero 1184

.globl dk
dk:
  .zero 2400

/* ---- 内部工作缓冲 ---- */
seed_d_share0:
  .zero 64
seed_d_share1:
  .zero 64
seed_z_share0:
  .zero 32
seed_z_share1:
  .zero 32
pk_rho:
  .zero 32

.balign 32
pk_t:
  .zero 1152
sk_s_share0:
  .zero 1152
sk_hpk:
  .zero 32
sk_z_share0:
  .zero 32
sk_z_share1:
  .zero 32
_seed_buf:
  .zero 160

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
