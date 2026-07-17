/* Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */
.section .text

/*
 * Name:        indcpa_keypair
 *
 * Description: Generates public and private key for the CPA-secure
 *              public-key encryption scheme underlying Kyber
 *
 * Arguments:   - uint8_t *pk: pointer to output public key
 *                             (of length 1184 bytes)
 *              - uint8_t *sk: pointer to output private key
 *                             (of length 1152 bytes)
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10 (x10): pointer to seed (32 = 32)
 * @param[out] x11 (x11): dmem pointer to public key pk_addr
 * @param[out] x12 (x12): dmem pointer to secret key sk_addr
 *
 * clobbered registers: x10-x14, x5-x30, w8, w16
 */
.global indcpa_keypair
indcpa_keypair:


  /* Store parameters to stack */
  sw  x10, -16(fp)
  sw  x11, -32(fp)
  sw  x12, -24(fp)

  /*** hash_g: SHA3-512 ***/
  la   x10, context
  li   x11, 64 /* output len */
  jal  x1, sha3_init
  la   x10, context
  lw   x11, -16(fp)
  li   x12, 32 /* input len */
  jal  x1, sha3_update
  addi  x11, x0, 3
  sw    x11, -128(fp)
  la    x10, context
  addi  x11, fp, -128
  addi  x12, x0, 1
  jal   x1, sha3_update
  la   x10, context
  addi x11, fp, -128
  jal  x1, sha3_final

  /*** CBD skpv ***/
  li   x15, -2176 
  li   x11, -3712
  add  x11, fp, x11
  li   x13, -64
  li   x12, 0
  LOOPI 3, 5
    add  x6, fp, x15
    addi x10, fp, -96
    sw   x12, -64(fp)
    jal  x1, poly_getnoise_eta_1
    addi x12, x12, 1 

  /*** NTT skpv ***/
  /* ntt(skpv) */
  li   x10, -3712
  add  x10, fp, x10
  add  x12, x0, x10
  .rept 3
    la  x11, twiddles_ntt
    jal x1, ntt
  .endr
  
  /*** Packing sk ***/
  li   x10, -3712
  add  x10, fp, x10
  lw   x13, -24(fp)
  jal  x1, pack_sk

  /*** Matrix generation ***/
  li   x11, -2176 
  add  x11, fp, x11
  li   x12, 0
  .rept 3
    /* Gen 1st mat poly */
    addi x10, fp, -128
    jal  x1, poly_gen_matrix
    addi x12, x12, 1

    /* Mutliply this generated poly with sk */
    addi x11, x11, -512 /* point back to A[0][0] */
    li   x29, -3712
    add  x29, fp, x29 /* point to sk[0] */
    add  x13, x11, x0   /* output at A[0][0] */
    la   x28, twiddles_ntt
    jal  x1, basemul

    /* After basemul:
       x11 points to A[0][1]: for storing next generated vector
       x10: reloaded for seed
       x12: untouched by basemul
       x29: accumulated to always point to next poly
       x13: output of basemul, must always points to A[0][0] */
    .rept 3-1
      /* Gen next mat poly */
      addi x10, fp, -128
      jal  x1, poly_gen_matrix
      addi x12, x12, 1

      /* Mutliply this generated poly with sk */
      addi x11, x11, -512 /* points back to A[0][1] */
      addi x13, x11, -512 /* points back to A[0][0] for accumulation */
      la   x28, twiddles_ntt
      jal  x1, basemul_acc
      addi x11, x11, -512 /* points back to A[0][1] */
    .endr 
    addi x12, x12, 253 
  .endr 
  
  /* toplant */
  li  x10, -2176 
  add x10, fp, x10
  la  x12, const_toplant
  .rept 3
    jal x1, poly_reduce
  .endr 

  /*** CBD e ***/
  li   x15, -640
  li   x11, -3712
  add  x11, fp, x11
  li   x13, -64
  li   x12, 3
  LOOPI 3, 5
    add  x6, fp, x15
    addi x10, fp, -96
    sw   x12, -64(fp)
    jal  x1, poly_getnoise_eta_1
    addi x12, x12, 1 

  /*** NTT e ***/
  /* ntt(skpv) */
  li   x10, -3712
  add  x10, fp, x10
  add  x12, x0, x10
  .rept 3
    la  x11, twiddles_ntt
    jal x1, ntt
  .endr

  /* Polyvec add */
  li   x10, -2176 
  add  x10, fp, x10
  li   x11, -3712 
  add  x11, fp, x11 
  add  x12, x0, x10 
  .rept 3
    jal x1, poly_add
  .endr
  
  /*** Packing pk ***/

  lw   x13, -32(fp)
  li   x10, -2176 
  add  x10, fp, x10 
  addi x11, fp, -128
  jal  x1, pack_pk

  ret 

/*
 * Name:        crypto_kem_keypair
 *
 * Description: Generates public and private key
 *              for CCA-secure Kyber key encapsulation mechanism
 *
 * Arguments:   - uint8_t *pk: pointer to output public key
 *                (an already allocated array of 1184 bytes)
 *              - uint8_t *sk: pointer to output private key
 *                (an already allocated array of 2400 bytes)
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10 (x10): pointer to seed (2*32 = 64)
 * @param[out] x11 (x11): dmem pointer to kem_pk
 * @param[out] x12 (x12): dmem pointer to kem_sk 
 *
 * clobbered registers: x10-x14, x5-x30, w8, w16
 */

.globl crypto_kem_keypair
crypto_kem_keypair: 
  /* Set frame pointer */
  addi fp, sp, 0 

    li  x5, -3712

  add  sp, sp, x5 

  /*** indcpa_keypair ***/
  jal  x1, indcpa_keypair
  li   x4, 0
  lw   x10, -32(fp)
  lw   x11, -24(fp)
  addi x11, x11, 1152
  LOOPI 37, 2
    bn.lid x4, 0(x10++)
    bn.sid x4, 0(x11++)

  /*** hash_h ***/
  la   x10, context
  li   x11, 32
  jal  x1, sha3_init
  la   x10, context
  lw   x11, -32(fp)
  li   x12, 1184
  jal  x1, sha3_update
  la   x10, context
  lw   x11, -24(fp)
  addi x11, x11, 1184
  addi x11, x11, 1152
  jal  x1, sha3_final

  /*** Random bytes ***/
  lw      x10, -16(fp)
  addi    x10, x10, 32 
  li      x5, 8
  bn.lid  x5, 0(x10)
#   bn.sid  x5, 0(x11++)      # 一行或者下面存x12 等价

  /* Reload sk base address and calculate z offset (1152 + 1184 + 32 = 2368) */
  lw      x12, -24(fp)       # 从栈帧加载 sk 基地址
  li      x6, 2368           # 用临时寄存器加载大立即数
  add     x12, x12, x6       # x12 = sk + 2368
  bn.sid  x5, 0(x12++)       # 存储 z

  /* Free space on stack */
  addi sp, fp, 0
  ret
