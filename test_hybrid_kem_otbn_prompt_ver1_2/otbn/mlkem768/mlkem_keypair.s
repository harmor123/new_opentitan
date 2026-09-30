/* Copyright lowRISC contributors (OpenTitan project). */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */
/*
 * ver1_1 (ML-KEM-768, 官方向量指令实现) —— KeyGen
 *
 * 内核逐字移植自: sw/otbn/crypto/mlkem1024/keygen/mlkem1024_keygen.s
 *   k: 4 -> 3             (矩阵 3x3, e 的 nonce 从 3 起)
 *   pk: 1568 -> 1184 B    (pk_t 1152 + rho 32)
 *   sk: 3168 -> 2400 B    (s 1152 + pk_t 1152 + rho 32 + H(pk) 32 + z 32)
 *   G 域分隔字节: 4 -> 3  (FIPS 203 Alg. 16: (rho, sigma) = G(d || k))
 * 文件布局沿用 ver0_2/otbn/mlkem768
 *
 * 掩码: d/z 以双 share 存储并走 KMAC 掩码吸收(xof_absorb 的 x22 = share1)。
 *       测试/确定性模式下 share1 = 0(即 coins 直接作为 share0)，因此测试向量与
 *       ver0_2 完全一致，同时掩码代码路径被完整执行。
 *
 * 栈指针: x31（向上增长）。官方 ML-KEM/ML-DSA 代码的约定；OTBN 无 ABI，
 *          官方文档未规定数据栈指针寄存器（详见 README）。ver0_2 用 x2。
 */

.globl crypto_kem_keypair
.globl indcpa_keypair

.text

/**
 * ver0_2 接口: crypto_kem_keypair —— ML-KEM-768 密钥生成 (FIPS 203 Alg. 19/16)
 *
 * @param[in]  x10: dptr_coins, 64 字节 (d[32] || z[32])
 * @param[out] x11: dptr_ek, 标准公钥 1184 字节 (ByteEncode_12(t_hat) || rho)
 * @param[out] x12: dptr_dk, 标准私钥 2400 字节 (s || pk || H(pk) || z)
 *
 * 需要的内存符号(由 app/测试文件提供): stack, mlkem768_const_params,
 *   const_2988_wdr, keygen_scale_const_2988, seed_d_share0/1, seed_z_share0/1,
 *   pk_rho, pk_t, sk_s_share0, sk_hpk, sk_z_share0/1
 */
crypto_kem_keypair:
  la   x31, stack
  bn.xor w31, w31, w31

  /* 保存入参: 槽位 -12(x31) = coins, -8(x31) = ek, -4(x31) = dk */
  sw   x10, 0(x31)
  addi x31, x31, 4
  sw   x11, 0(x31)
  addi x31, x31, 4
  sw   x12, 0(x31)
  addi x31, x31, 4

  /* 加载 ML-KEM 常数到 MOD CSR: q = 3329, mu = -q^-1 mod 2^32 */
  la   x2, mlkem768_const_params
  bn.lid x0, 0(x2)
  bn.wsrw MOD, w0

  /* 初始化 keygen_scale_const_2988 (32 个 WDR，每 lane 常数 2988 = 2^64 mod q) */
  la     x2, const_2988_wdr
  addi   x10, x0, 0
  bn.lid x10, 0(x2)
  la     x2, keygen_scale_const_2988
  loopi  32, 1
    bn.sid x10, 0(x2++)
    /* End of loop */

  /* 由 coins 建立种子 share: share0 = coins 分量, share1 = 0 */
  lw   x5, -12(x31)            /* x5 = coins */
  la   x6, seed_d_share0
  bn.lid x0, 0(x5)             /* w0 = d */
  bn.sid x0, 0(x6)

  la   x6, seed_d_share1
  bn.xor w0, w0, w0
  bn.sid x0, 0(x6)
  bn.sid x0, 32(x6)

  la   x6, seed_z_share0
  bn.lid x0, 32(x5)            /* w0 = z */
  bn.sid x0, 0(x6)

  la   x6, seed_z_share1
  bn.xor w0, w0, w0
  bn.sid x0, 0(x6)

  /* CPA 部分: (rho||sigma) = G(d||3), 采样 s/e, 矩阵乘, 得 pk_rho/pk_t/sk_s */
  jal  x1, indcpa_keypair

  /* H(pk) = SHA3-256(pk_t || pk_rho) [1184 字节] -> sk_hpk */
  jal  x1, xof_sha3_256_init
  li   x20, 1152
  la   x21, pk_t
  li   x22, 0
  jal  x1, xof_absorb
  li   x20, 32
  la   x21, pk_rho
  li   x22, 0
  jal  x1, xof_absorb
  jal  x1, xof_process

  la   x20, sk_hpk
  jal  x1, xof_squeeze32
  bn.xor w0, w29, w30
  bn.sid x0, 0(x20)
  jal  x1, xof_finish

  /* pack_pk: ek = pk_t || rho */
  la   x10, pk_t
  la   x11, pk_rho
  lw   x13, -8(x31)
  jal  x1, pack_pk

  /* 拷贝 z 种子分片到 sk 输出缓冲 (官方 keygen 的对应步骤):
   *   seed_z_share0 -> sk_z_share0, seed_z_share1 -> sk_z_share1 */
  la   x2, seed_z_share0
  la   x3, sk_z_share0
  bn.lid x0, 0(x2)
  bn.sid x0, 0(x3)

  la   x2, seed_z_share1
  la   x3, sk_z_share1
  bn.lid x0, 0(x2)
  bn.sid x0, 0(x3)

  /* pack_sk: dk = s || pk_t || rho || H(pk) || (z0 ^ z1) */
  lw   x13, -4(x31)
  la   x10, sk_s_share0
  la   x11, pk_t
  la   x12, pk_rho
  la   x14, sk_hpk
  la   x15, sk_z_share0
  la   x16, sk_z_share1
  jal  x1, pack_sk

  addi x31, x31, -12
  ret

/**
 * K-PKE.KeyGen (FIPS 203 Algorithm 16 的 CPA 部分)
 *
 * 前置条件: MOD CSR 已装载 (q, mu)；seed_d_share0/1 已就绪；
 *           keygen_scale_const_2988 已初始化。
 * 产出: pk_rho (rho)，pk_t (ByteEncode_12(t_hat))，
 *       sk_s_share0 (ByteEncode_12(s_hat))，poly_slot_s_hat (Montgomery 域 s_hat)。
 */
indcpa_keypair:
  /* (rho || sigma) = SHA3-512(d_share0 ^ d_share1 || 0x03) */
  la   x21, seed_d_share0
  li   x20, 3
  sw   x20, 32(x21)

  jal  x1, xof_sha3_512_init
  addi x20, x0, 33
  la   x21, seed_d_share0
  la   x22, seed_d_share1
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

  /* 拷贝 32 字节 rho 到 pk_rho */
  la   x2, _seed_buf
  la   x3, pk_rho
  addi x5, x0, 0
  bn.lid x5, 0(x2)
  bn.sid x5, 0(x3)

  /* 采样 s[0..2] -> NTT -> 编码进 sk_s_share0 -> 缩放(Montgomery)存 poly_slot_s_hat */
  la   x15, sk_s_share0
  la   x14, poly_slot_s_hat
  addi x16, x0, 0     /* j = 0 */
  addi x17, x0, 3     /* k = 3 */

_indcpa_sample_s_loop:
  la   x2, _seed_buf
  addi x2, x2, 32     /* sigma 地址 */
  la   x4, poly_slot0
  addi x3, x16, 0     /* N = j */
  jal  x1, poly_getnoise_eta_1

  /* s[j] -> NTT 域 s_hat[j] */
  la   x2, poly_slot0
  la   x3, poly_slot0
  jal  x1, ntt

  /* 编码标准 NTT 域 s_hat[j] 进 sk_s + j * 384 */
  la   x2, poly_slot0
  addi x3, x15, 0
  jal  x1, poly_tobytes

  /* s_hat[j] 缩放到 Montgomery 域 (s_hat * R mod q)，存 poly_slot_s_hat + j * 1024 */
  la   x2, poly_slot0
  la   x3, keygen_scale_const_2988
  la   x4, _basemul_twiddles
  addi x5, x14, 0
  jal  x1, basemul

  addi x14, x14, 1024
  addi x15, x15, 384
  addi x16, x16, 1
  bne  x16, x17, _indcpa_sample_s_loop

  /* 矩阵-向量乘 t = A * s + e (3x3 矩阵) */
  li   x18, 0     /* i = 0 (行) */

_indcpa_row_loop:
  /* 采样 e[i] 到 poly_slot0 并转到 NTT 域 */
  la   x2, _seed_buf
  addi x2, x2, 32     /* sigma 地址 */
  la   x4, poly_slot0
  addi x3, x18, 3     /* N = 3 + i */
  jal  x1, poly_getnoise_eta_1

  la   x2, poly_slot0
  la   x3, poly_slot0
  jal  x1, ntt

  /* 列循环: 累加 A[i][j] * s_hat[j] 到 poly_slot0 (即 e_hat[i]) */
  li   x19, 0     /* j = 0 (列) */

_indcpa_col_loop:
  la   x2, pk_rho
  addi x3, x19, 0   /* j */
  addi x4, x18, 0   /* i */
  la   x5, poly_slot2
  jal  x1, poly_gen_matrix

  /* poly_slot2 (A[i][j]) * poly_slot_s_hat[j] + poly_slot0 (累加器) -> poly_slot0 */
  la   x2, poly_slot2
  la   x3, poly_slot_s_hat
  slli x7, x19, 10    /* j * 1024 */
  add  x3, x3, x7
  la   x4, _basemul_twiddles
  la   x5, poly_slot0
  la   x6, poly_slot0
  jal  x1, basemul_acc

  addi x19, x19, 1
  li   x7, 3
  bne  x19, x7, _indcpa_col_loop

  /* poly_slot0 现为 NTT 域 t_hat[i]，编码进 pk_t + i * 384 */
  la   x2, poly_slot0
  la   x3, pk_t
  slli x7, x18, 8     /* i * 256 */
  add  x3, x3, x7
  slli x7, x18, 7     /* i * 128 */
  add  x3, x3, x7     /* x3 = pk_t + i * 384 */
  jal  x1, poly_tobytes

  addi x18, x18, 1
  li   x7, 3
  bne  x18, x7, _indcpa_row_loop

  ret

  unimp
  unimp
  unimp
