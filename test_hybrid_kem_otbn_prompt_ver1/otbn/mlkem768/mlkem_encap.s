/* Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/*
 * Name:        indcpa_enc
 *
 * Description: Encryption function of the CPA-secure
 *              public-key encryption scheme underlying Kyber.
 *
 * Arguments:   - uint8_t *c: pointer to output ciphertext
 *                            (of length 1088 bytes)
 *              - const uint8_t *m: pointer to input message
 *                                  (of length 32 bytes)
 *              - const uint8_t *pk: pointer to input public key
 *                                   (of length 1184)
 *              - const uint8_t *coins: pointer to input random coins used as seed
 *                                      (of length 32) to deterministically
 *                                      generate all randomness 
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10 (x10): dmem pointer to input message 
 * @param[in]  x11 (x11): dmem pointer to input packed pk
 * @param[in]  x12 (x12): dmem pointer to input coins 
 * @param[out] x13 (x13): dmem pointer to output ciphertext
 *
 * clobbered registers: x10-x14, x5-x30, w8, w16
 */
.global indcpa_enc
indcpa_enc:

  /* Store parameters to stack */
  sw x12, -28(fp) # 0x5280 r

  /*** poly_frommsg ***/
  la  x11, modulus_over_2
  li  x12, -2656
  add x12, fp, x12 
  jal x1, poly_frommsg

  /*** unpack_pk ***/
  lw  x10, -24(fp) # 0x52a0   pk
  la  x13, const_0x0fff
  jal x1, unpack_pk

  /*** save seed to dmem ***/
  li     x4, 0
  bn.lid x4, 0(x10)
  bn.sid x4, -96(x8) # dmem[0x4dc0..0x4ddf] msg seed 32字节 已经被哈希了 后续再看下

  /*** CBD sp ***/
  lw  x10, -28(fp)
  add x14, x0, x10
  li  x11, -4192
  add x11, fp, x11
  li  x15, -608  
  li  x13, -64
  li  x12, 0
  LOOPI 3, 5
    add  x6, fp, x15
    sw   x12, -64(fp)
    jal  x1, poly_getnoise_eta_1
    add  x10, x0, x14
    addi x12, x12, 1  

  /*** NTT ***/
  li  x10, -4192 
  add x10, fp, x10
  add x12, x0, x10 
  .rept 3
    la  x11, twiddles_ntt
    jal x1, ntt
  .endr 

  /** v = sp * pkpv **/ 
  li   x29, -2144 
  add  x29, fp, x29
  li   x11, -4192 
  add  x11, fp, x11 
  li   x13, -608
  add  x13, fp, x13
  la   x28, twiddles_ntt
  jal  x1, basemul
  /** .rept 3-1 **/ 
  .rept 2
    addi x13, x13, -512
    la   x28, twiddles_ntt
    jal  x1, basemul_acc 
  .endr

  /*** reduce v ***/
  li  x10, -608
  add x10, fp, x10
  la  x12, const_1290167
  jal x1, poly_reduce

  /*** INTT v ***/
  li  x10, -608
  add x10, fp, x10 
  add x12, x0, x10 
  la  x11, twiddles_intt
  jal x1, intt

  /*** CBD epp ***/
  lw   x10, -28(fp)
  li   x11, -2144
  add  x11, fp, x11
  addi x12, x0, 2*3
  sw   x12, -64(fp)
  li   x13, -64
  li   x6, -1120
  add  x6, fp, x6
  jal  x1, poly_getnoise_eta_2

  /** v = v + k + epp **/
  li   x10, -2656
  add  x10, fp, x10
  li   x11, -608
  add  x11, fp, x11
  add  x12, x0, x11 
  jal  x1, poly_add
  addi x11, x11, -512
  addi x12, x12, -512
  jal  x1, poly_add

  /*** Matrix vector multiplication ***/
  li   x11, -2656
  add  x11, fp, x11
  li   x12, 0
  .rept 3
    /* Gen 1st mat poly */
    addi x10, fp, -96
    jal  x1, poly_gen_matrix
    addi x12, x12, 0x0100

    /* Mutliply this generated poly with sk */
    addi x11, x11, -512 /* point back to A[0][0] */
    li   x29, -4192
    add  x29, fp, x29 /* point to sk[0] */
    add  x13, x11, x0   /* output at A[0][0] */
    la   x28, twiddles_ntt
    jal  x1, basemul
    /* .rept 3-1 */
    .rept 2
      /* Gen next mat poly */
      addi x10, fp, -96
      jal  x1, poly_gen_matrix
      addi x12, x12, 0x0100

      /* Mutliply this generated poly with sk */
      addi x11, x11, -512 /* points back to A[0][1] */
      addi x13, x11, -512 /* points back to A[0][0] for accumulation */
      la   x28, twiddles_ntt
      jal  x1, basemul_acc
      addi x11, x11, -512 /* points back to A[0][1] */
    .endr 
    addi x12, x12, -767 
  .endr

  /* reduce */
  li  x10, -2656
  add x10, fp, x10
  la  x12, const_1290167
  .rept 3
    jal x1, poly_reduce
  .endr

  /*** INTT ***/
  li  x10, -2656
  add x10, fp, x10 
  add x12, x0, x10 
  .rept 3
    la  x11, twiddles_intt
    jal x1, intt
  .endr 

  /*** CBD ep ***/
  lw  x10, -28(fp)
  li  x11, -4192
  add x11, fp, x11
  add x14, x0, x10
  li  x15, -1120
  li  x13, -64
  li  x12, 3
  LOOPI 3, 5
    add  x6, fp, x15
    sw   x12, -64(fp)
    jal  x1, poly_getnoise_eta_2
    add  x10, x0, x14
    addi x12, x12, 1

  /*** ADD ***/
  /** b = b + ep **/
  li  x10, -2656
  add x10, fp, x10
  li  x11, -4192
  add x11, fp, x11 
  add x12, x0, x10 
  .rept 3
    jal x1, poly_add 
  .endr 

  /*** pack_ciphertext ***/
  li   x10, -2656
  add  x10, fp, x10
  li   x11, -608
  add  x11, fp, x11
  lw   x12, -32(fp) # 从栈加载 ct 指针
  la   x13, const_1290167
  la   x15, modulus_over_2
  jal  x1, pack_ciphertext
  ret 

/*
 * Name:        crypto_kem_enc
 *
 * Description: Generates cipher text and shared
 *              secret for given public key
 *
 * Arguments:   - uint8_t *ct: pointer to output cipher text
 *                (an already allocated array of 1088 bytes)
 *              - uint8_t *ss: pointer to output shared secret
 *                (an already allocated array of 32 bytes)
 *              - const uint8_t *pk: pointer to input public key
 *                (an already allocated array of 1184 bytes)
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10 (x10): dmem pointer to input randombytes (32 = 32)
 * @param[out] x11 (x11): dmem pointer to output ct
 * @param[out] x12 (x12): dmem pointer to output key_b 
 * @param[in]  x13 (x13): dmem pointer to input pk 
 *
 * clobbered registers: x10-x14, x5-x30, w8, w16
 */

.globl crypto_kem_enc
crypto_kem_enc: 


  /* Set frame pointer */
  addi fp, sp, 0 

    li  x5, -4192

  add  sp, sp, x5

  /* Save parameters to stack */
  sw x11, -32(fp) # 保存 ct 指针 # 0x4e20
  sw x12, -20(fp) # 保存 ss 指针（共享密钥） # 0x5260
  sw x13, -24(fp) # 保存 pk 指针 # 0x52a0

  /*** Copy randombytes to buf ***/
  li     x4, 0
  bn.lid x4, 0(x10)
  li     x5, -1120
  add    x5, fp, x5 
  bn.sid x4, 0(x5++)
  add    x12, x0, x5 

 
  /*** hash_h(pk): SHA3-256 ***/
  jal   x1, sha3_256_init

  lw    x21, -24(fp)            /* Load pk pointer */
  addi  x20, x0, 1184
  addi  x22, x0, 0
  jal   x1, xof_absorb

  jal   x1, xof_process

  jal   x1, xof_squeeze32
  bn.xor w29, w29, w30
  addi  x7, x0, 29
  addi  x10, fp, -1120
  addi  x6, x10, 32             /* output = fp-1088 (immediately after randombytes) */
  bn.sid x7, 0(x6)

  jal   x1, xof_finish


  /*** hash_g(randombytes||hash_h(pk)): SHA3-512 ***/
  jal   x1, sha3_512_init

  addi  x21, fp, -1120          /* message = randombytes(32B) || hash_h(pk)(32B) */
  addi  x20, x0, 64
  addi  x22, x0, 0
  jal   x1, xof_absorb

  jal   x1, xof_process

  /* Squeeze first 32B → K (to ss pointer) */
  jal   x1, xof_squeeze32
  bn.xor w29, w29, w30
  addi  x7, x0, 29
  lw    x6, -20(fp)             /* x6 = ss pointer */
  bn.sid x7, 0(x6)

  /* Squeeze next 32B → r (to ss + 32) */
  jal   x1, xof_squeeze32
  bn.xor w29, w29, w30
  addi  x6, x6, 32
  bn.sid x7, 0(x6)

  jal   x1, xof_finish

 /* At this point the ss memory area is: first 32 bytes = K, next 32 bytes = r */
  
  /*** indcpa_enc ***/
  li  x10, -1120
  add x10, fp, x10      # x10 = m（前32字节 randombytes）
  lw  x12, -20(fp)      # x12 = ss（基址）
  add x12, x12, 32      # x12 = r（ss偏移32字节后的地址，作为 coins 传入）
  jal x1, indcpa_enc

  /* Free space on stack */
  addi sp, fp, 0

  ret
