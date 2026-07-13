
.globl indcpa_enc
indcpa_enc:

  /* Store parameters to stack */
  sw x12, -28(fp)

  /*** poly_frommsg ***/
  la  x11, modulus_over_2
  li  x12, -2656
  add x12, fp, x12 
  jal x1, poly_frommsg

  /*** unpack_pk ***/
  lw  x10, -24(fp)
  la  x13, const_0x0fff
  jal x1, unpack_pk

  /*** save seed to dmem ***/
  li     x4, 0
  bn.lid x4, 0(x10)
  bn.sid x4, -96(x8)

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

  bn.wsrr   w16, 0x0 /* w16 = R | Q */
  bn.shv.8S w0, w16 << 1 /* w0 = 2*R | 2*Q */
  bn.wsrw   0x0, w0 /* MOD = 2*R | 2*Q */
  /*** NTT sp ***/
  li  x10, -4192 
  add x10, fp, x10
  la  x11, twiddles_ntt
  add x12, x0, x10 
  .rept 3
    jal x1, ntt
  .endr

  /* After NTT, w6 is still R | Q and MOD is still 2*R | 2*Q */
  /** v = sp * pkpv **/ 
  li   x29, -2144 
  add  x29, fp, x29
  li   x11, -4192 
  add  x11, fp, x11 
  li   x13, -608
  add  x13, fp, x13
  la   x28, twiddles_basemul
  jal  x1, basemul
  .rept 3-1
    addi x13, x13, -512
    la   x28, twiddles_basemul
    jal  x1, basemul_acc 
  .endr

  /* After basemul, w16 is still R | Q and MOD is still 2*R | 2*Q */
  /*** INTT v ***/
  li      x10, -608
  add     x10, fp, x10 
  add     x12, x0, x10 
  la      x11, twiddles_intt
  jal     x1, intt
  bn.wsrw 0x0, w16 /* Restore MOD = R | Q */

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

  /* w6 is still R | Q */
  bn.shv.8S w0, w16 << 1 /* w0 = 2*R | 2*Q */
  bn.wsrw   0x0, w0 /* MOD = 2*R | 2*Q */
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
    la   x28, twiddles_basemul
    jal  x1, basemul
    .rept 2
      /* Gen next mat poly */
      addi x10, fp, -96
      jal  x1, poly_gen_matrix
      addi x12, x12, 0x0100

      /* Mutliply this generated poly with sk */
      addi x11, x11, -512 /* points back to A[0][1] */
      addi x13, x11, -512 /* points back to A[0][0] for accumulation */
      la   x28, twiddles_basemul
      jal  x1, basemul_acc
      addi x11, x11, -512 /* points back to A[0][1] */
    .endr 
    addi x12, x12, -767 
  .endr

  /* After basemul, w16 is still R | Q and MOD is still 2*R | 2*Q */
  /*** INTT ***/
  li  x10, -2656
  add x10, fp, x10 
  la  x11, twiddles_intt
  add x12, x0, x10 
  .rept 3
    jal x1, intt
  .endr 
  bn.wsrw 0x0, w16 /* Restore MOD = R | Q */

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
  lw   x12, -32(fp)
  la   x13, const_1290167
  la   x15, modulus_over_2
  jal  x1, pack_ciphertext
  ret 



.globl crypto_kem_enc
crypto_kem_enc: 

  /* Set frame pointer */
  addi fp, sp, 0 

    li  x5, -4192

  add  sp, sp, x5

  /* Save parameters to stack */
  sw x11, -32(fp) #dmem[0x4e00..0x4e03] = 0x4e20 output ct
  sw x12, -20(fp) #dmem[0x4e0c..0x4e0f] = 0x5260 output key_b ss
  sw x13, -24(fp) #dmem[0x4e08..0x4e0b] = 0x52a0 input pk ek

  /*** Copy randombytes to buf ***/
  li     x4, 0
  bn.lid x4, 0(x10)
  li     x5, -1120
  add    x5, fp, x5 
  bn.sid x4, 0(x5++)
  add    x13, x0, x5 

  /*** hash_h(pk) ***/
  /* 使用硬件 SHA3-256 (Mode 0) */
  addi  x10, x0, 0       /* Mode 0 = SHA3-256 */
  jal   x1, kmac_init

  lw    x10, -24(fp)     /* x10 = pk 指针 */
  addi  x11, x0, 1184    /* x11 = pk 长度 */
  jal   x1, keccak_send_message

  addi  x10, fp, -1120
  addi  x10, x10, 32     /* x10 = 输出指针 (fp-1088)，紧跟在 randombytes 后面 */
  jal   x1, kmac_squeeze_after_process

  jal   x1, kmac_done


  /*** hash_g(randombytes||hash_h(pk)) ***/
  /* 注意：fp-1120 处现在恰好是 32字节randombytes + 32字节hash_h(pk) = 64字节 */
  /* 使用硬件 SHA3-512 (Mode 1) */
  addi  x10, x0, 1       /* Mode 1 = SHA3-512 */
  jal   x1, kmac_init

  addi  x10, fp, -1120   /* x10 = 消息指针 (randombytes || hash_h(pk)) */
  addi  x11, x0, 64      /* x11 = 消息长度 64 字节 */
  jal   x1, keccak_send_message

  lw    x10, -20(fp)     /* x10 = ss 指针，前 32 字节写入 K */
  jal   x1, kmac_squeeze_after_process

  addi  x10, x10, 32     /* x10 = ss 指针 + 32，后 32 字节写入 r */
  jal   x1, kmac_squeeze_32B

  jal   x1, kmac_done


  /*** indcpa_enc(m, pk, r, ct) ***/
  li    x10, -1120
  add   x10, fp, x10 /* m = buf */
  lw    x11, -24(fp)  /* pk */
  lw    x13, -32(fp)  /* ct */
  lw    x12, -20(fp)  /* key_b */
  addi  x12, x12, 32  /* r = key_b + 32 */
  jal   x1, indcpa_enc

  addi sp, fp, 0
  ret