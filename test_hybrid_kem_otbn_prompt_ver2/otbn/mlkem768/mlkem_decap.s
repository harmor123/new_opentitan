
.globl indcpa_dec
indcpa_dec:

  /* Store parameters to stack */
  sw x13, -32(fp)
  
  /*** unpack_ciphertext ***/
  li  x12, -3616
  add x12, fp, x12 
  la  x13, const_8
  la  x14, modulus
  la  x15, const_0x0fff
  jal x1, unpack_ciphertext

  /*** unpack_sk ***/
  jal x1, unpack_sk

  bn.wsrr   w16, 0x0 /* w16 = R | Q */
  bn.shv.8S w0, w16 << 1 /* w0 = 2*R | 2*Q */
  bn.wsrw   0x0, w0 /* MOD = 2*R | 2*Q */
  /*** NTT ***/
  li  x10, -3616
  add x10, fp, x10 
  la  x11, twiddles_ntt
  add x12, x0, x10 
  .rept 3 
    jal x1, ntt
  .endr 

  /* After NTT, w16 is still R | Q and MOD is still 2*R | 2*Q */
  /*** Vector vector multiplication ***/
  addi x29, x10, -1536
  addi x11, x12, 512
  add  x13, x0, x29
  la   x28, twiddles_basemul
  jal  x1, basemul
  .rept 3-1
    addi x13, x13, -512
    la   x28, twiddles_basemul
    jal  x1, basemul_acc 
  .endr 

  /* After basemul, w16 is still R | Q and MOD is still 2*R | 2*Q */
  /*** INTT ***/
  add     x10, x10, -1536 
  la      x11, twiddles_intt
  add     x12, x0, x10 
  jal     x1, intt
  bn.wsrw 0x0, w16 /* Restore MOD = R | Q */

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
  addi fp, sp, 0 

    li  x5, -4320

  add  sp, sp, x5

  /* Save parameters to stack */ 
  sw   x10, -20(fp)
  sw   x11, -16(fp) 
  addi x5, x11, 1152 
  sw   x5, -24(fp)
  addi x5, x5, 1184
  sw   x5, -12(fp)
  sw   x12, -8(fp)

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
  /* 使用硬件 SHA3-512 (Mode 1) */
  addi  x10, x0, 1       /* Mode 1 = SHA3-512 */
  jal   x1, kmac_init

  li    x10, -4320
  add   x10, fp, x10     /* x10 = buf 指针 */
  addi  x11, x0, 64      /* x11 = 消息长度 64 字节 */
  jal   x1, keccak_send_message

  li    x10, -4256
  add   x10, fp, x10     /* x10 = 输出指针 (buf+64)，写入前 32 字节 (K') */
  jal   x1, kmac_squeeze_after_process

  addi  x10, x10, 32     /* x10 = 输出指针 (buf+96)，写入后 32 字节 (r') */
  jal   x1, kmac_squeeze_32B

  jal   x1, kmac_done    /* 注意：必须是 kmac_done，不能是 kmac_release */

  /*** indcpa_enc ***/
  addi x12, x10, 0       # x12 = buf+96 (r') — 此时 x10 还是 buf+96
  addi x10, x10, -96     # x10 = buf    (m') — 因为 x10=buf+96，需 -96
  li   x13, -2656
  add  x13, fp, x13 
  sw   x13, -32(fp)
  jal  x1, indcpa_enc

  /*** shake256(z||c,32) ***/
  /* 使用硬件 SHAKE256 (Mode 3) */
  addi  x10, x0, 3       /* Mode 3 = SHAKE256 */
  jal   x1, kmac_init

  lw    x10, -12(fp)     /* x10 = sk+1152 指针 */
  addi  x10, x10, 32     /* x10 = z 指针 (sk+1184) */
  addi  x11, x0, 32      /* x11 = z 长度 */
  jal   x1, keccak_send_message

  lw    x10, -20(fp)     /* x10 = ct 指针 */
  li    x11, 1088        /* x11 = ct 长度 */
  jal   x1, keccak_send_message

  li    x10, -4256
  add   x10, fp, x10
  addi  x10, x10, 32     /* x10 = 输出指针 (buf+96) */
  jal   x1, kmac_squeeze_after_process

  jal   x1, kmac_done    /* 注意：必须是 kmac_done，释放硬件回 IDLE */

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
