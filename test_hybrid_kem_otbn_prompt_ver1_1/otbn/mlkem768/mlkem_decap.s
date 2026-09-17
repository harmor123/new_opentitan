/* Copyright lowRISC contributors (OpenTitan project). */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */
/*
 * ver1_1 (ML-KEM-768, 官方向量指令实现) —— Decapsulation
 *
 * 内核逐字移植自: sw/otbn/crypto/mlkem1024/decaps/mlkem1024_decaps.s
 *                 sw/otbn/crypto/mlkem1024/decaps/mlkem1024_decrypt.s
 *   k: 4 -> 3            (密文多项式个数 3)
 *   ct_u: 1408 -> 960 B  (du = 10, 320 B/多项式)
 *   ct_v: 160 -> 128 B   (dv = 4)
 *   ct: 1568 -> 1088 B
 * 文件布局沿用 ver0_2/otbn/mlkem768
 *
 * sk 分量在标准 dk(2400 B) 中的偏移:
 *   s   @    0 (1152)   pk_t @ 1152 (1152)   rho @ 2304 (32)
 *   H(pk) @ 2336 (32)   z    @ 2368 (32)
 *
 * 栈指针: x31（向上增长；官方 ML-KEM/ML-DSA 代码的约定，OTBN 无 ABI 规定，详见 README）
 */

.globl crypto_kem_dec
.globl _decrypt_core

.text

/**
 * ver0_2 接口: crypto_kem_dec —— ML-KEM-768 解封装 (FIPS 203 Alg. 21/18)
 *
 * @param[in]  x10: dptr_ct, 密文 1088 字节
 * @param[in]  x11: dptr_dk, 标准私钥 2400 字节
 * @param[out] x12: dptr_ss, 共享密钥 32 字节
 *
 * 需要的内存符号: stack, mlkem768_const_params, _seed_buf, re_enc_u, re_enc_v,
 *   poly_slot0/1, keygen_scale_const_2988, const_2988_wdr
 */
crypto_kem_dec:
  la   x31, stack
  bn.xor w31, w31, w31

  /* 保存入参: 槽位 -12(x31)=ct, -8=dk, -4=ss */
  sw   x10, 0(x31)
  addi x31, x31, 4
  sw   x11, 0(x31)
  addi x31, x31, 4
  sw   x12, 0(x31)
  addi x31, x31, 4

  /* MOD CSR = {q = 3329, mu} */
  la   x2, mlkem768_const_params
  bn.lid x0, 0(x2)
  bn.wsrw MOD, w0

  /* 1. K-PKE.Decrypt: m' = Decrypt(s, (ct_u || ct_v)) -> _seed_buf[0..31] */
  lw   x2, -12(x31)               /* ct = ct_u */
  addi x3, x2, 960                /* ct_v */
  lw   x4, -8(x31)                /* s = dk + 0 */
  la   x5, _seed_buf
  jal  x1, _decrypt_core

  /* 2. (K' || r') = SHA3-512(m' || H(ek)) -> _seed_buf + 32 */
  jal  x1, xof_sha3_512_init
  la   x21, _seed_buf
  li   x20, 32
  li   x22, 0
  jal  x1, xof_absorb
  lw   x21, -8(x31)
  addi x21, x21, 1024
  addi x21, x21, 1312             /* H(pk) */
  li   x20, 32
  li   x22, 0
  jal  x1, xof_absorb
  jal  x1, xof_process

  /* Squeeze 64 字节到 _seed_buf + 32 (K_bar' @ +32, r' @ +64) */
  la   x20, _seed_buf
  addi x20, x20, 32
  jal  x1, xof_squeeze32
  bn.xor w0, w29, w30
  bn.sid x0, 0(x20++)
  jal  x1, xof_squeeze32
  bn.xor w0, w29, w30
  bn.sid x0, 0(x20++)
  jal  x1, xof_finish

  /* 3. 再加密: 未压缩 c' = (u' || v') = K-PKE.Encrypt(ek, m', r') */
  lw   x2, -8(x31)
  addi x2, x2, 1152               /* pk_t */
  lw   x3, -8(x31)
  addi x3, x3, 1024
  addi x3, x3, 1280               /* pk_rho */
  la   x4, _seed_buf              /* m' */
  la   x5, _seed_buf
  addi x5, x5, 64                 /* r' */
  la   x6, re_enc_u
  la   x7, re_enc_v
  jal  x1, indcpa_enc_uncompressed

  /* 4. 常量时间比较 c 与 c' */
  bn.xor w12, w12, w12            /* w12 = 不匹配累加器 */

  /* 比较 u' 与输入 ct_u (3 个多项式) */
  la   x14, re_enc_u
  lw   x15, -12(x31)              /* ct_u */
  loopi 3, 24
    /* 拷贝 re_enc_u[i] (1024 字节) 到 poly_slot1 */
    addi x2, x14, 0
    la   x3, poly_slot1
    loopi 32, 2
      bn.lid x0, 0(x2++)
      bn.sid x0, 0(x3++)

    /* 压缩 poly_slot1 -> poly_slot0 (320 字节) */
    la   x2, poly_slot1
    la   x3, poly_slot0
    jal  x1, compress_10

    /* 比较 poly_slot0 (10 WDRs) 与 ct_u + i * 320 */
    la   x2, poly_slot0
    addi x3, x15, 0
    li   x25, 1
    bn.xor w11, w11, w11
    loopi 10, 4
      bn.lid x0, 0(x2++)
      bn.lid x25, 0(x3++)
      bn.xor w2, w0, w1
      bn.or  w11, w11, w2
      /* End of loop */

    /* 累积不匹配到 w12 */
    bn.or w12, w12, w11

    addi x14, x14, 1024
    addi x15, x15, 320
    /* End of loop */

  /* 比较 v' 与输入 ct_v (1 个多项式) */
  la   x2, re_enc_v
  la   x3, poly_slot1
  loopi 32, 2
    bn.lid x0, 0(x2++)
    bn.sid x0, 0(x3++)

  /* 压缩 poly_slot1 -> poly_slot0 (128 字节) */
  la   x2, poly_slot1
  la   x3, poly_slot0
  jal  x1, compress_4

  /* 比较 poly_slot0 (4 WDRs) 与 ct_v */
  la   x2, poly_slot0
  lw   x3, -12(x31)
  addi x3, x3, 960                /* ct_v */
  li   x25, 1
  bn.xor w11, w11, w11
  loopi 4, 4
    bn.lid x0, 0(x2++)
    bn.lid x25, 0(x3++)
    bn.xor w2, w0, w1
    bn.or  w11, w11, w2
    /* End of loop */

  bn.or w12, w12, w11

  /* 5. 拒绝密钥 K_fail = SHAKE256(z || c) —— z 走掩码吸收通路 (z0, z1) */
  jal  x1, xof_shake256_init
  lw   x21, -8(x31)
  addi x21, x21, 1024
  addi x21, x21, 1344             /* z_share0 */
  lw   x22, -8(x31)
  addi x22, x22, 1024
  addi x22, x22, 1344             /* z_share1 (= 0: 测试模式) */
  li   x20, 32
  jal  x1, xof_absorb
  lw   x21, -12(x31)
  li   x20, 960
  li   x22, 0
  jal  x1, xof_absorb
  lw   x21, -12(x31)
  addi x21, x21, 960
  li   x20, 128
  li   x22, 0
  jal  x1, xof_absorb
  jal  x1, xof_process

  jal  x1, xof_squeeze32
  bn.xor w11, w29, w30            /* w11 = K_fail */
  jal  x1, xof_finish

  /* 常量时间选择: 把 w12 的 8 个 32-bit 字 OR 到一起 -> x20 */
  la   x2, poly_slot0
  li   x25, 12
  bn.sid x25, 0(x2)

  lw    x20, 0(x2)
  addi  x3, x2, 4
  loopi 7, 3
    lw   x21, 0(x3)
    or   x20, x20, x21
    addi x3,  x3, 4
    /* End of loop */

  /* 读 K_bar' (来自 _seed_buf[32..63]) 到 w10 */
  la   x2, _seed_buf
  addi x2, x2, 32
  li   x25, 10
  bn.lid x25, 0(x2)               /* w10 = K_bar' */

  /* 选择: x20 == 0 (匹配) 时选 w10 (K_bar')，否则选 w11 (K_fail) */
  bn.mov w0, w10
  beq   x20, x0, _decaps_select_done
  bn.mov w0, w11
_decaps_select_done:

  /* 存共享密钥 K */
  lw   x3, -4(x31)
  bn.sid x0, 0(x3)

  addi x31, x31, -12
  ret

/**
 * K-PKE.Decrypt 核心 (FIPS 203 Algorithm 15)
 *
 * @param[in]  x2: DMEM 地址 ct_u (960 B)
 * @param[in]  x3: DMEM 地址 ct_v (128 B)
 * @param[in]  x4: DMEM 地址 私钥 s (1152 B)
 * @param[out] x5: 消息 m' 输出地址 (32 B)
 *
 * 需要的内存符号: keygen_scale_const_2988, const_2988_wdr, vector_u, vector_s,
 *   poly_slot0/1/2, _basemul_twiddles
 */
_decrypt_core:
  /* Push caller input parameters x2..x5 and working registers onto stack (36 bytes) */
  .irp reg, x2, x3, x4, x5, x7, x10, x14, x15, x16
    sw \reg, 0(x31)
    addi x31, x31, 4
  .endr

  addi x18, x2, 0     /* x18 = ct_u */
  addi x19, x3, 0     /* x19 = ct_v */
  addi x20, x4, 0     /* x20 = sk_s */
  addi x21, x5, 0     /* x21 = out_m */

  /* 初始化 keygen_scale_const_2988 */
  la     x2, const_2988_wdr
  addi   x10, x0, 0
  bn.lid x10, 0(x2)
  la     x2, keygen_scale_const_2988
  loopi  32, 1
    bn.sid x10, 0(x2++)

  /* 1. 解压 u[0..2]，转 NTT，存 vector_u */
  addi x14, x18, 0  /* ct_u */
  la   x15, vector_u
  addi x16, x0, 0

  loopi 3, 20
    addi x2, x14, 0
    la   x3, poly_slot0
    jal  x1, decompress_10

    la   x2, poly_slot0
    la   x3, poly_slot0
    jal  x1, ntt

    /* u_hat[i] 缩放到 Montgomery 域 (R^1)，用常数 2988，存 vector_u[i] */
    la   x2, poly_slot0
    la   x3, keygen_scale_const_2988
    la   x4, _basemul_twiddles
    addi x5, x15, 0
    jal  x1, basemul

    addi x14, x14, 320  /* 10 bits * 256 / 8 = 320 字节/多项式 */
    addi x15, x15, 1024
    addi x16, x16, 1
    /* End of loop */

  /* 2. 解码私钥 s[0..2] 到 vector_s */
  addi x14, x20, 0 /* sk_s */
  la   x15, vector_s
  addi x16, x0, 0

  loopi 3, 6
    addi x2, x14, 0
    addi x3, x15, 0
    jal  x1, poly_frombytes

    addi x14, x14, 384  /* 12 bits * 256 / 8 = 384 字节/多项式 */
    addi x15, x15, 1024
    addi x16, x16, 1
    /* End of loop */

  /* 3. 内积 s^T * u = sum_{i=0..2} (vector_s[i] * vector_u[i]) -> poly_slot2 */
  la   x2, poly_slot2
  bn.xor w0, w0, w0
  loopi 32, 1
    bn.sid x0, 0(x2++)
    /* End of loop */

  addi x16, x0, 0     /* i = 0 */

  loopi 3, 15
    la   x2, vector_s
    slli x7, x16, 10
    add  x2, x2, x7
    la   x3, vector_u
    add  x3, x3, x7
    la   x4, _basemul_twiddles
    la   x5, poly_slot2
    la   x6, poly_slot2
    jal  x1, basemul_acc

    addi x16, x16, 1
    /* End of loop */

  /* 4. INTT(s^T * u) */
  la   x2, poly_slot2
  la   x3, poly_slot2
  jal  x1, intt

  /* 解压 v 并计算 w = v - INTT(s^T * u) */
  addi x2, x19, 0   /* ct_v */
  la   x3, poly_slot0
  jal  x1, decompress_4

  la   x2, poly_slot0
  la   x3, poly_slot2
  la   x4, poly_slot1
  jal  x1, poly_sub

  /* 5. 压缩 w 到 256 bit，编码成 32 字节 m' (compress_1 + encode_1) */
  la   x2, poly_slot1
  addi x3, x21, 0  /* m' 输出地址 */
  jal  x1, poly_tomsg

  /* 恢复栈并返回 */
  .irp reg, x16, x15, x14, x10, x7, x5, x4, x3, x2
    addi x31, x31, -4
    lw \reg, 0(x31)
  .endr
  ret
