/* Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/*
 * Name:        indcpa_dec
 *
 * Description: Decryption function of the CPA-secure
 *              public-key encryption scheme underlying Kyber.
 *
 * Arguments:   - uint8_t *m: pointer to output decrypted message
 *                            (of length 32)
 *              - const uint8_t *c: pointer to input ciphertext
 *                                  (of length 1088)
 *              - const uint8_t *sk: pointer to input secret key
 *                                   (of length 1152) 
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10 (x10): dmem pointer to input ciphertext 
 * @param[in]  x11 (x11): dmem pointer to input packed sk
 * @param[out] x13 (x13): dmem pointer to output message
 *
 * clobbered registers: x10-x14, x5-x30, w8, w16
 */
.global indcpa_dec
indcpa_dec:

  /* Store parameters to stack */
  sw x13, -32(fp)  # 0x3d40
  
  /*** unpack_ciphertext ***/
  li  x12, -3616
  add x12, fp, x12 
  la  x13, const_8
  la  x14, modulus
  la  x15, const_0x0fff
  jal x1, unpack_ciphertext

  /*** unpack_sk ***/
  jal x1, unpack_sk

  /*** NTT ***/
  li  x10, -3616
  add x10, fp, x10 
  add x12, x0, x10 
  .rept 3 
    la  x11, twiddles_ntt
    jal x1, ntt
  .endr 

  /*** Vector vector multiplication ***/
  addi x29, x10, -1536
  addi x11, x12, 512
  add  x13, x0, x29
  la   x28, twiddles_ntt
  jal  x1, basemul
  /*** .rept 3-1 ***/
  .rept 2
    addi x13, x13, -512
    la   x28, twiddles_ntt
    jal  x1, basemul_acc 
  .endr 

  /* reduce */
  li  x10, -3616
  add x10, fp, x10
  la  x12, const_1290167
  jal x1, poly_reduce

  /*** INTT ***/
  add x10, x10, -512 
  la  x11, twiddles_intt
  add x12, x0, x10 
  jal x1, intt

  /*** SUB ***/
  li   x10, -2080
  add  x10, fp, x10 
  addi x11, x12, -512
  addi x12, x12, -512 
  jal  x1, poly_sub 

  /*** poly_tomsg ***/
  addi x10, x11, -512 
  la   x11, modulus_over_2
  lw   x12, -32(fp)
  la   x13, const_1290167
  jal  x1, poly_tomsg

  ret

/*
 * Name:        crypto_kem_dec
 *
 * Description: Generates shared secret for given
 *              cipher text and private key
 *
 * Arguments:   - uint8_t *ss: pointer to output shared secret
 *                (an already allocated array of 32 bytes)
 *              - const uint8_t *ct: pointer to input cipher text
 *                (an already allocated array of 1088 bytes)
 *              - const uint8_t *sk: pointer to input private key
 *                (an already allocated array of 2400 bytes)
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10 (x10): dmem pointer to input ct
 * @param[in]  x11 (x11): dmem pointer to input sk 
 * @param[out] x12 (x12): dmem pointer to output key_a
 *
 * clobbered registers: x10-x14, x5-x30, w8, w16
 */
.globl crypto_kem_dec
crypto_kem_dec:

  /* Set frame pointer */
  addi fp, sp, 0  # fp = 0x4e20

    li  x5, -4320

  add  sp, sp, x5

  /* Save parameters to stack */ 
  sw   x10, -20(fp)   # ct 0x4e40
  sw   x11, -16(fp)   # sk 0x5280
  addi x5, x11, 1152 
  sw   x5, -24(fp)
  addi x5, x5, 1184
  sw   x5, -12(fp)    # 0x5ba0
  sw   x12, -8(fp)    # 0x4e20

  /*** indcpa_dec ***/ 
  li  x13, -4320
  add x13, fp, x13 
  jal x1, indcpa_dec

  /*** Copy hash_h(pk) to buf+32 ***/
  li     x4, 0
  lw     x10, -12(fp)
  li     x13, -4320
  add    x13, fp, x13 
  addi   x13, x13, 32
  bn.lid x4, 0(x10)
  bn.sid x4, 0(x13++)

  /*** hash_g(buf) ***/
  la   x10, context
  li   x11, 64
  jal  x1, sha3_init
  la   x10, context
  li   x11, -4320
  add  x11, fp, x11
  li   x12, 64
  jal  x1, sha3_update
  la   x10, context
  li   x11, -4256
  add  x11, fp, x11 
  jal  x1, sha3_final

  /*** indcpa_enc ***/
  li   x10, -4320
  add  x10, fp, x10
  li   x12, -4256
  add  x12, fp, x12 
  addi x12, x12, 32 
  li   x13, -2656
  add  x13, fp, x13 
  sw   x13, -32(fp)
  jal  x1, indcpa_enc

  /*** shake256(z||c,32) ***/
  la   x10, context
  li   x11, 32
  jal  x1, sha3_init

  la   x10, context
  lw   x11, -12(fp)
  addi x11, x11, 32 
  li   x12, 32
  jal x1, sha3_update

  la   x10, context
  lw   x11, -20(fp)
  li   x12, 1088
  jal  x1, sha3_update

  la   x10, context
  jal  x1, shake_xof

  la   x10, context
  li   x11, -4256
  add  x11, fp, x11
  addi x11, x11, 32
  addi x12, x0, 32
  jal  x1, shake_out

  /*** verify: ct == cmp ? ***/
  li      x5, 0
  li      x6, 1
  lw      x10, -20(fp)
  lw      x11, -32(fp)
  li      x7, 1
  bn.subi w2, w31, 1
  LOOPI 34, 8
    beq    x7, x0, _skip_verify
    bn.lid x5, 0(x10++)
    bn.lid x6, 0(x11++)
    bn.cmp w0, w1
    bn.sel w4, w31, w2, FG0.Z
    csrrw  x7, 0x7C0, x0 
    srl x7, x7, 3
_skip_verify:
    nop

  /*** cmov ***/
  li      x10, -4256
  add     x10, fp, x10 
  bn.lid  x5, 0(x10++) /* load true key */
  bn.lid  x6, 0(x10)   /* load false key */
  bn.xor  w3, w0, w1 
  bn.and  w3, w3, w4 
  bn.xor  w0, w0, w3 
  lw      x10, -8(fp) 
  bn.sid  x5, 0(x10) /* return key */

  ret
