/* Copyright lowRISC contributors (OpenTitan project). */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/**
 * Standalone elliptic curve P-256 ECDH shared key generation test
 *
 * Uses OTBN ECC P-256 lib to perform a scalar multiplication with a valid
 * example curve point and an example scalar. Both scalar and coordinates of
 * the curve point are contained in the .data section below.
 * The x coordinate of the resulting curve point is masked arithmetically
 * with a random value. As the x coorodinate represents the actual
 * shared key, the x coordinate and its mask are then converted from an
 * arithmetic to a boolean masking scheme.
 *
 * The result of arithmetical unmasking as well as the result of boolean
 * unmasking are compared with an expected value.
   ECDH 共享密钥就是结果点的 X 坐标
 */

.section .text.start

p256_ecdh_shared_key_test:

  /* Call P-256 shared key generation to get a boolean-masked key.
       dmem[x] <= x0
       dmem[y] <= x1
       (MOD is set up internally by scalar_mult_int → setup_modp) */
  jal      x1, p256_shared_key 

  /* Load the two shares.
       w11 <= dmem[x] = x0
       w12 <= dmem[y] = x1 */
  li        x3, 11
  la        x4, x
  bn.lid    x3++, 0(x4)
  la        x4, y
  bn.lid    x3, 0(x4)

  /* Unmask the shared key, x.
       w11 <= x0 ^ x1 = x */
  bn.xor    w11, w11, w12

  /* Store the unmasked x-coordinate for dexp verification.
     TODO: remove after Phase 1 verification. */
  la        x16, shared_key_x
  li        x17, 11
  bn.sid    x17, 0(x16)

  ecall


.data

/* Secret key d in arithmetic shares. */
.globl d0
.balign 32
d0:  /* 标量 d 的第一个算术份额 */
  .word 0xfe6d1071
  .word 0x21d0a016
  .word 0xb0b2c781
  .word 0x9590ef5d
  .word 0x3fdfa379
  .word 0x1b76ebe8
  .word 0x74210263
  .word 0x1420fc41
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
.globl d1
.balign 32
d1: /* 标量 d 的第二个算术份额（全零，即 d 本身是 d0） */
  .zero 64

/* P-256 base point G x-coordinate */
.globl x
.balign 32
x:
  .word 0xd898c296
  .word 0xf4a13945
  .word 0x2deb33a0
  .word 0x77037d81
  .word 0x63a440f2
  .word 0xf8bce6e5
  .word 0xe12c4247
  .word 0x6b17d1f2

/* P-256 base point G y-coordinate */
.globl y
.balign 32
y:
  .word 0x37bf51f5
  .word 0xcbb64068
  .word 0x6b315ece
  .word 0x2bce3357
  .word 0x7c0f9e16
  .word 0x8ee7eb4a
  .word 0xfe1a7f9b
  .word 0x4fe342e2

/* Unmasked shared key x-coordinate (x0 ^ x1). */
.globl shared_key_x
.balign 32
shared_key_x:
  .zero 32

/* Public key z-coordinate. */
.globl z
.balign 32
z:
  .zero 32

/* affine x-coordinate value before A2B */
.globl x_a
.balign 32
x_a: /* 仿射的算术掩码后 x 坐标（未使用，预留） */
  .zero 32
