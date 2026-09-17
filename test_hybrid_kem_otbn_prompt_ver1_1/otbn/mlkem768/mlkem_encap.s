/* Copyright lowRISC contributors (OpenTitan project). */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */
/*
 * ver1_1 (ML-KEM-768, 官方向量指令实现) —— Encapsulation
 *
 * 内核逐字移植自: sw/otbn/crypto/mlkem1024/encaps/mlkem1024_encaps.s
 *                 sw/otbn/crypto/mlkem1024/encaps/mlkem1024_encrypt.s
 *   k: 4 -> 3          (矩阵 3x3; e1 nonce 从 3 起; e2 nonce = 6)
 *   ct_u: 1408 -> 960 B (du = 11 -> 10, 320 B/多项式)
 *   ct_v: 160 -> 128 B  (dv = 5 -> 4)
 *   ct: 1568 -> 1088 B
 * 文件布局沿用 ver0_2/otbn/mlkem768
 *
 * 栈指针: x31（向上增长；官方 ML-KEM/ML-DSA 代码的约定，OTBN 无 ABI 规定，详见 README）
 */

.globl crypto_kem_enc
.globl indcpa_enc
.globl indcpa_enc_uncompressed
.globl _encrypt_core

.text

/**
 * ver0_2 接口: crypto_kem_enc —— ML-KEM-768 封装 (FIPS 203 Alg. 20/17)
 *
 * @param[in]  x10: dptr_m, 32 字节消息
 * @param[out] x11: dptr_ct, 密文 1088 字节
 * @param[out] x12: dptr_ss, 共享密钥 32 字节
 * @param[in]  x13: dptr_ek, 标准公钥 1184 字节
 *
 * 需要的内存符号: stack, mlkem768_const_params, unpack_pk(pk_t/pk_rho),
 *   _expand_buf, _seed_buf, res_ok, const_3328_vec, poly_slot*, vector_u/v
 */
crypto_kem_enc:
  la   x31, stack
  bn.xor w31, w31, w31

  /* 保存入参: 槽位 -16(x31)=m, -12=ct, -8=ss, -4=ek */
  sw   x10, 0(x31)
  addi x31, x31, 4
  sw   x11, 0(x31)
  addi x31, x31, 4
  sw   x12, 0(x31)
  addi x31, x31, 4
  sw   x13, 0(x31)
  addi x31, x31, 4

  /* MOD CSR = {q = 3329, mu = -q^-1 mod 2^32} */
  la   x2, mlkem768_const_params
  bn.lid x0, 0(x2)
  bn.wsrw MOD, w0

  /* 拆包 ek -> pk_t, pk_rho */
  lw   x10, -4(x31)
  la   x12, pk_t
  la   x13, pk_rho
  jal  x1, unpack_pk

  /* 公钥系数范围检查 (FIPS 203 Section 7.2): 所有 t_i < q = 3329 */
  la   x14, pk_t
  bn.xor w27, w27, w27            /* w27 累积溢出符号位 */
  la     x2, const_3328_vec
  li     x20, 28
  bn.lid x20, 0(x2)               /* w28 = [3328, 3328, ...] */

  la     x15, poly_slot2
  loopi 3, 10
    addi x2, x14, 0
    addi x3, x15, 0               /* x3 = poly_slot2 */
    jal  x1, poly_frombytes
    addi x2, x15, 0               /* x2 = poly_slot2 */
    loopi 32, 4
      bn.lid x0, 0(x2++)
      bn.subv.8S w0, w28, w0      /* w0[k] = 3328 - t_i */
      bn.shv.8S  w0, w0 >> 31     /* MSB = 1 表示 t_i >= 3329 */
      bn.or      w27, w27, w0     /* 累积溢出位 */
    addi x14, x14, 384
    /* End of loop */

  bn.cmp w27, w31, FG0            /* w27 == 0 ? */
  csrrs  x2, FG0, x0
  andi   x2, x2, 8                /* 提取 Z(zero)位 */
  bne    x2, x0, _pk_bounds_ok

  /* 溢出: 写 0xc5618e4b 到 res_ok 并返回 */
  la   x2, res_ok
  li   x3, 0xc5618e4b
  sw   x3, 0(x2)
  addi x31, x31, -16
  ret

_pk_bounds_ok:
  la   x2, res_ok
  li   x3, 0x3a9e71b4
  sw   x3, 0(x2)

  /* 1. H(ek) = SHA3-256(pk_t || pk_rho) -> _expand_buf */
  jal  x1, xof_sha3_256_init
  la   x21, pk_t
  li   x20, 1152
  li   x22, 0
  jal  x1, xof_absorb
  la   x21, pk_rho
  li   x20, 32
  li   x22, 0
  jal  x1, xof_absorb
  jal  x1, xof_process

  la   x20, _expand_buf
  jal  x1, xof_squeeze32
  bn.xor w0, w29, w30
  bn.sid x0, 0(x20)
  jal  x1, xof_finish

  /* 2. (K_bar || r) = SHA3-512(m || H(ek)) -> _seed_buf */
  jal  x1, xof_sha3_512_init
  lw   x21, -16(x31)              /* m */
  li   x20, 32
  li   x22, 0
  jal  x1, xof_absorb
  la   x21, _expand_buf
  li   x20, 32
  li   x22, 0
  jal  x1, xof_absorb
  jal  x1, xof_process

  la   x20, _seed_buf
  jal  x1, xof_squeeze32
  bn.xor w0, w29, w30
  bn.sid x0, 0(x20++)
  jal  x1, xof_squeeze32
  bn.xor w0, w29, w30
  bn.sid x0, 0(x20++)
  jal  x1, xof_finish

  /* K_bar -> ss */
  la   x2, _seed_buf
  lw   x3, -8(x31)                /* ss */
  bn.lid x0, 0(x2)
  bn.sid x0, 0(x3)

  /* 3. K-PKE.Encrypt: ct = (ct_u || ct_v)，压缩模式 */
  la   x2, pk_t
  la   x3, pk_rho
  lw   x4, -16(x31)               /* m */
  la   x5, _seed_buf
  addi x5, x5, 32                 /* r */
  lw   x6, -12(x31)               /* ct = ct_u 起点 */
  addi x7, x6, 960                /* ct_v 起点 */
  addi x8, x0, 0                  /* 压缩模式 */
  jal  x1, _encrypt_core

  addi x31, x31, -16
  ret

/**
 * ver0_2 接口: indcpa_enc —— K-PKE.Encrypt (FIPS 203 Alg. 14)
 *
 * @param[in]  x10: dptr_m, 32 字节消息
 * @param[in]  x11: dptr_ek, 标准公钥 1184 字节
 * @param[in]  x12: dptr_r, 32 字节随机数
 * @param[out] x13: dptr_ct, 密文 1088 字节
 */
indcpa_enc:

  /* 保存入参: 槽位 -16(x31)=m, -12=ek, -8=r, -4=ct */
  sw   x10, 0(x31)
  addi x31, x31, 4
  sw   x11, 0(x31)
  addi x31, x31, 4
  sw   x12, 0(x31)
  addi x31, x31, 4
  sw   x13, 0(x31)
  addi x31, x31, 4

  la   x2, mlkem768_const_params
  bn.lid x0, 0(x2)
  bn.wsrw MOD, w0

  lw   x10, -12(x31)              /* ek */
  la   x12, pk_t
  la   x13, pk_rho
  jal  x1, unpack_pk

  la   x2, pk_t
  la   x3, pk_rho
  lw   x4, -16(x31)               /* m */
  lw   x5, -8(x31)                /* r */
  lw   x6, -4(x31)                /* ct = ct_u */
  addi x7, x6, 960                /* ct_v */
  addi x8, x0, 0
  jal  x1, _encrypt_core

  addi x31, x31, -16
  ret

/**
 * K-PKE.Encrypt 核心 (未压缩模式)，供 decaps 的再加密使用。
 *
 * @param[in]  x2: pk_t 地址 (1152 B)
 * @param[in]  x3: pk_rho 地址 (32 B)
 * @param[in]  x4: 消息 m 地址 (32 B)
 * @param[in]  x5: 随机数 r 地址 (32 B)
 * @param[out] x6: u 输出地址 (3 × 1024 B)
 * @param[out] x7: v 输出地址 (1024 B)
 */
indcpa_enc_uncompressed:
  addi x8, x0, 1
  jal  x0, _encrypt_core

/**
 * K-PKE.Encrypt 核心 (FIPS 203 Algorithm 14)
 *
 * @param[in]  x2: DMEM 地址 pk_t (1152 B)
 * @param[in]  x3: DMEM 地址 pk_rho (32 B)
 * @param[in]  x4: DMEM 地址 消息 m (32 B)
 * @param[in]  x5: DMEM 地址 随机数 r (32 B)
 * @param[in]  x6: u 输出地址
 * @param[in]  x7: v 输出地址
 * @param[in]  x8: 模式标志 (0 = 压缩输出, 1 = 未压缩输出)
 *
 * 需要的内存符号: keygen_scale_const_2988, const_2988_wdr, poly_slot0/1/2,
 *   poly_slot_y_hat, _basemul_twiddles
 */
_encrypt_core:
  /* Push caller input parameters x2..x7 and working registers onto stack (44 bytes) */
  .irp reg, x2, x3, x4, x5, x6, x7, x13, x14, x16, x17, x18
    sw \reg, 0(x31)
    addi x31, x31, 4
  .endr

  addi x18, x8, 0     /* x18 = 模式标志 (0 = 压缩, 1 = 未压缩) */
  addi x19, x2, 0     /* x19 = pk_t 地址 */
  addi x23, x3, 0     /* x23 = pk_rho 地址 */
  addi x15, x4, 0     /* x15 = 消息 m 地址 */
  addi x26, x5, 0     /* x26 = 随机数 r 地址 */
  addi x27, x6, 0     /* x27 = u_out 地址 */
  addi x21, x7, 0     /* x21 = v_out 地址 */

  /* 初始化 keygen_scale_const_2988 (每 lane 2988) */
  la     x2, const_2988_wdr
  addi   x10, x0, 0
  bn.lid x10, 0(x2)
  la     x2, keygen_scale_const_2988
  loopi  32, 1
    bn.sid x10, 0(x2++)
    /* End of loop */

  /* 预采样 y[j] (j = 0..2)，NTT，缩放(Montgomery) 存 poly_slot_y_hat */
  la   x14, poly_slot_y_hat
  addi x17, x0, 0       /* j = 0 */

  loopi 3, 19
    addi x2, x26, 0     /* 随机数 r 地址 */
    la   x4, poly_slot0
    addi x3, x17, 0     /* N = j */
    jal  x1, poly_getnoise_eta_1

    la   x2, poly_slot0
    addi x3, x2, 0
    jal  x1, ntt

    /* y_hat[j] 缩放到 Montgomery 域 (R^1)，用常数 2988，存 poly_slot_y_hat + j * 1024 */
    la   x2, poly_slot0
    la   x3, keygen_scale_const_2988
    la   x4, _basemul_twiddles
    addi x5, x14, 0
    jal  x1, basemul

    addi x14, x14, 1024
    addi x17, x17, 1
    /* End of loop */

  /* 1. 计算 u[0..2]: u_i = INTT(sum_j A[j][i] * y_hat[j]) + e1[i] */
  addi x13, x27, 0     /* u_out 工作指针 */
  addi x16, x0, 0      /* i = 0 */

  loopi 3, 59
    /* 清零 poly_slot1 (累加 sum_j A[j][i] * y_hat[j]) */
    la x2, poly_slot1
    bn.xor w0, w0, w0
    loopi 32, 1
      bn.sid x0, 0(x2++)
      /* End of loop */

    addi x17, x0, 0       /* j = 0 */

    loopi 3, 21
      /* A[j][i] -> poly_slot2 */
      addi x2, x23, 0     /* pk_rho */
      addi x3, x16, 0     /* 列 = i */
      addi x4, x17, 0     /* 行 = j */
      la   x5, poly_slot2
      jal  x1, poly_gen_matrix

      /* poly_slot1 += A[j][i] * y_hat[j] */
      la   x2, poly_slot2
      la   x3, poly_slot_y_hat
      slli x7, x17, 10    /* j * 1024 */
      add  x3, x3, x7
      la   x4, _basemul_twiddles
      la   x5, poly_slot1
      la   x6, poly_slot1
      jal  x1, basemul_acc

      addi x17, x17, 1
      /* End of loop */

    /* INTT(poly_slot1) 原地 */
    la   x2, poly_slot1
    addi x3, x2, 0
    jal  x1, intt

    /* 采样 e1[i] (nonce N = 3 + i) 到 poly_slot0 */
    addi x2, x26, 0     /* 随机数 r 地址 */
    la   x4, poly_slot0
    addi x3, x16, 3       /* N = 3 + i */
    jal  x1, poly_getnoise_eta_1

    /* poly_slot1 += e1[i] */
    la   x2, poly_slot1
    la   x3, poly_slot0
    la   x4, poly_slot1
    jal  x1, poly_add

    /* 模式检查: 1 = 未压缩 */
    li   x24, 1
    bne  x18, x24, _encrypt_compress_u
    /* 未压缩: 拷贝 1024 字节 poly_slot1 -> u_out[i] */
    la   x2, poly_slot1
    addi x3, x13, 0
    loopi 32, 2
      bn.lid x0, 0(x2++)
      bn.sid x0, 0(x3++)
    addi x13, x13, 1024
    jal  x0, _encrypt_u_next

_encrypt_compress_u:
    /* 压缩: compress_10(poly_slot1, u_out + i * 320) */
    la   x2, poly_slot1
    addi x3, x13, 0
    jal  x1, compress_10
    addi x13, x13, 320

_encrypt_u_next:
    addi x16, x16, 1
    /* End of loop */

  /* 2. 计算 v = INTT(sum_j t_hat[j] * y_hat[j]) + e2 + decode_1(m) */
  /* 清零 poly_slot1 */
  la x2, poly_slot1
  bn.xor w0, w0, w0
  loopi 32, 1
    bn.sid x0, 0(x2++)
    /* End of loop */

  addi x14, x19, 0     /* pk_t 工作指针 */
  addi x17, x0, 0       /* j = 0 */

  loopi 3, 20
    /* decode_12(t_bytes[j], poly_slot2) */
    addi x2, x14, 0
    la   x3, poly_slot2
    jal  x1, poly_frombytes

    /* poly_slot1 += t_hat[j] * y_hat[j] */
    la   x2, poly_slot2
    la   x3, poly_slot_y_hat
    slli x7, x17, 10    /* j * 1024 */
    add  x3, x3, x7
    la   x4, _basemul_twiddles
    la   x5, poly_slot1
    la   x6, poly_slot1
    jal  x1, basemul_acc

    addi x14, x14, 384    /* 12 bits * 256 / 8 = 384 字节 */
    addi x17, x17, 1
    /* End of loop */

  /* INTT(poly_slot1) 原地 */
  la   x2, poly_slot1
  addi x3, x2, 0
  jal  x1, intt

  /* 采样 e2 (nonce N = 6) 到 poly_slot0 */
  addi x2, x26, 0     /* 随机数 r 地址 */
  la   x4, poly_slot0
  addi x3, x0, 6        /* N = 6 = 2k */
  jal  x1, poly_getnoise_eta_1

  /* poly_slot1 += e2 */
  la   x2, poly_slot1
  la   x3, poly_slot0
  la   x4, poly_slot1
  jal  x1, poly_add

  /* decode_1(m) -> poly_slot0 (已解压为 m * 1665) */
  addi x2, x15, 0     /* 消息 m 地址 */
  la   x3, poly_slot0
  jal  x1, poly_frommsg

  /* poly_slot1 += mu */
  la   x2, poly_slot1
  la   x3, poly_slot0
  la   x4, poly_slot1
  jal  x1, poly_add

  /* 模式检查 */
  li   x24, 1
  bne  x18, x24, _encrypt_compress_v
  /* 未压缩: 拷贝 1024 字节 */
  la  x2, poly_slot1
  addi x3, x21, 0     /* v_out */
  loopi 32, 2
    bn.lid x0, 0(x2++)
    bn.sid x0, 0(x3++)
  jal x0, _encrypt_v_done

_encrypt_compress_v:
  /* 压缩: compress_4(poly_slot1, v_out) */
  la   x2, poly_slot1
  addi x3, x21, 0     /* v_out */
  jal  x1, compress_4

_encrypt_v_done:

  /* 恢复栈并返回 */
  .irp reg, x18, x17, x16, x14, x13, x7, x6, x5, x4, x3, x2
    addi x31, x31, -4
    lw \reg, 0(x31)
  .endr
  ret
