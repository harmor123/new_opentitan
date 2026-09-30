/* Copyright lowRISC contributors (OpenTitan project). */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/*
 * HKDF-SHA3-256 (RFC 5869) over HMAC-SHA3-256 (hmac_sha3.s, which drives the
 * KMAC interface through the official xof.s driver).
 *
 * The IKM is pre-assembled in `ikm_prebuilt` by the caller:
 *   be16(32) || ss_e || be16(32) || ss_m || ctx || sid
 *
 * Entry points:
 *   hkdf_extract  PRK = HMAC-SHA3-256(salt, IKM) -> hmac_key_hashed
 *   hkdf_expand   OKM = HKDF-Expand(PRK, info, L) -> output_okm
 *
 * Required DMEM symbols (provided by the caller):
 *   input_salt      32B   salt
 *   ikm_prebuilt    var   pre-assembled IKM
 *   input_info      var   expand info bytes
 *   input_info_len  4B    info length
 *   input_lengths   12B   {ctx_len, sid_len, okm_len}
 *   output_okm      256B  OKM output
 *   t_buf           32B   T(i-1) scratch
 *   hmac_key_hashed 32B   PRK (extract output, expand key)
 *   hmac_inner      32B   T(i) scratch
 *   ikm_buf         1024B expand message scratch
 */

.section .text

/**
 * HKDF-Extract (RFC 5869, step 2.2).
 *
 * Clobbers: x5, x6, x8, x10-x14, ra (x20-x25/x27-x30 via hmac_sha3_256).
 */
.globl hkdf_extract
hkdf_extract:
  addi  sp, sp, -8
  sw    ra, 4(sp)

  /* ikm_len = 68 (two be16 lengths + two 32B secrets) + ctx_len + sid_len. */
  la    x8, input_lengths
  lw    x5, 0(x8)
  lw    x6, 4(x8)
  addi  x13, x5, 68
  add   x13, x13, x6

  /* PRK = HMAC-SHA3-256(salt, IKM) -> hmac_key_hashed. */
  la    x10, input_salt
  addi  x11, x0, 32
  la    x12, ikm_prebuilt
  la    x14, hmac_key_hashed
  jal   x1, hmac_sha3_256

  lw    ra, 4(sp)
  addi  sp, sp, 8
  ret

/**
 * HKDF-Expand (RFC 5869, step 2.3).
 * T(i) = HMAC-SHA3-256(PRK, T(i-1) || info || i), OKM = T(1) || T(2) || ...
 *
 * Clobbers: x8, x10-x30.
 */
.globl hkdf_expand
hkdf_expand:
  la    x8, input_lengths
  lw    x15, 8(x8)            /* L = okm_len */
  beq   x15, x0, expand_ret

  addi  x16, x15, 31
  srli  x16, x16, 5           /* N = ceil(L / 32) */
  la    x30, input_info_len
  lw    x29, 0(x30)           /* info_len */
  li    x17, 1                /* counter i */
  li    x18, 0                /* OKM offset */
  li    x19, 0                /* T(i-1) length */

expand_loop:
  /* Build the HMAC message in ikm_buf: T(i-1) (if i > 1) || info || i. */
  la    x20, ikm_buf

  beq   x19, x0, 1f
  la    x21, t_buf
  li    x22, 8                /* 32 / 4 words */
2:
  lw    x23, 0(x21)
  sw    x23, 0(x20)
  addi  x21, x21, 4
  addi  x20, x20, 4
  addi  x22, x22, -1
  bne   x22, x0, 2b

1:
  beq   x29, x0, 4f
  addi  x30, x29, 3
  srli  x30, x30, 2          /* info words */
  la    x21, input_info
3:
  lw    x22, 0(x21)
  sw    x22, 0(x20)
  addi  x21, x21, 4
  addi  x20, x20, 4
  addi  x30, x30, -1
  bne   x30, x0, 3b
4:
  andi  x21, x17, 0xFF
  sw    x21, 0(x20)           /* counter byte */

  add   x13, x19, x29
  addi  x13, x13, 1           /* msg_len = T_prev_len + info_len + 1 */

  /* Save the loop state; hmac_sha3_256 clobbers x20-x25/x27-x30, including
   * x29 (xof.s rate tracking) which holds info_len across the call. */
  addi  sp, sp, -40
  sw    ra, 36(sp)
  sw    x15, 32(sp)           /* L */
  sw    x16, 28(sp)           /* N remaining */
  sw    x17, 24(sp)           /* i */
  sw    x18, 20(sp)           /* OKM offset */
  sw    x19, 16(sp)           /* T(i-1) length */
  sw    x29, 12(sp)           /* info_len */

  /* T(i) = HMAC-SHA3-256(PRK, msg) -> hmac_inner. */
  la    x10, hmac_key_hashed
  addi  x11, x0, 32
  la    x12, ikm_buf
  la    x14, hmac_inner
  jal   x1, hmac_sha3_256

  lw    ra, 36(sp)
  lw    x15, 32(sp)
  lw    x16, 28(sp)
  lw    x17, 24(sp)
  lw    x18, 20(sp)
  lw    x19, 16(sp)
  lw    x29, 12(sp)
  addi  sp, sp, 40

  /* Copy T(i) to t_buf and to output_okm[offset]: min(32, L - offset) bytes. */
  la    x20, hmac_inner
  la    x21, t_buf
  la    x22, output_okm
  add   x22, x22, x18

  sub   x23, x15, x18         /* remaining = L - offset */
  addi  x24, x0, 32
  sub   x30, x23, x24
  srli  x30, x30, 31
  bne   x30, x0, expand_partial

  /* remaining >= 32: copy a full word block. */
  li    x25, 8
1:
  lw    x26, 0(x20)
  sw    x26, 0(x21)
  sw    x26, 0(x22)
  addi  x20, x20, 4
  addi  x21, x21, 4
  addi  x22, x22, 4
  addi  x18, x18, 4
  addi  x25, x25, -1
  bne   x25, x0, 1b
  jal   x0, expand_copy_done

expand_partial:
  /* remaining < 32: copy complete words, then the 1-3 tail bytes. */
  srli  x25, x23, 2
  beq   x25, x0, expand_partial_tail
1:
  lw    x26, 0(x20)
  sw    x26, 0(x21)
  sw    x26, 0(x22)
  addi  x20, x20, 4
  addi  x21, x21, 4
  addi  x22, x22, 4
  addi  x18, x18, 4
  addi  x23, x23, -4
  addi  x25, x25, -1
  bne   x25, x0, 1b

expand_partial_tail:
  /* Tail bytes need read-modify-write (OTBN has no byte loads/stores). */
  andi  x23, x23, 3
  beq   x23, x0, expand_copy_done

  lw    x26, 0(x20)
  li    x27, 1
  slli  x28, x23, 3
  sll   x27, x27, x28
  addi  x27, x27, -1          /* byte mask */
  and   x26, x26, x27

  lw    x28, 0(x21)           /* t_buf */
  xori  x29, x27, -1
  and   x28, x28, x29
  or    x28, x28, x26
  sw    x28, 0(x21)

  lw    x28, 0(x22)           /* output_okm */
  and   x28, x28, x29
  or    x28, x28, x26
  sw    x28, 0(x22)

  add   x18, x18, x23

expand_copy_done:
  li    x19, 32               /* T(i-1) length for the next round */
  addi  x17, x17, 1
  addi  x16, x16, -1
  bne   x16, x0, expand_loop

expand_ret:
  ret
