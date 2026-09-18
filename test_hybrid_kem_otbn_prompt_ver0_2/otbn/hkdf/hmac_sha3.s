/* Copyright lowRISC contributors (OpenTitan project). */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/*
 * HMAC-SHA3-256 (RFC 2104), built on the official KMAC driver xof.s
 * (verbatim from sw/otbn/crypto/xof.s on upstream master).
 *
 * The KMAC interface accepts exactly one message stream per session (a
 * partial final beat ends the message), so each of the two hash calls
 * below assembles its whole message (pad || data) in `hmac_msg` and
 * issues a single xof_absorb.
 *
 * Arguments:
 *   x10: key pointer (32B aligned)
 *   x11: key length in bytes
 *   x12: message pointer (32B aligned)
 *   x13: message length in bytes
 *   x14: output pointer (32B, 32B aligned)
 *
 * Clobbers: x4-x9, x15-x17, x20-x25, x27-x30, w0, w4, w26-w31.
 *
 * Required DMEM symbols (provided by the caller):
 *   hmac_ipad       160B  ipad work area
 *   hmac_opad       160B  opad work area
 *   hmac_msg        288B  assembled-message buffer (136B pad + msg)
 *   hmac_inner      32B   inner digest
 *   hmac_key_hashed 32B   hashed long key (>136B)
 *   const_0x36      160B  0x36 constant table
 *   const_0x5c      160B  0x5c constant table
 */

.section .text

.globl hmac_sha3_256
hmac_sha3_256:
  /* Save the caller's message/output state; xof clobbers x20-x25/x27-x30. */
  addi  sp, sp, -24
  sw    ra, 20(sp)
  sw    x12, 16(sp)          /* msg_ptr */
  sw    x13, 12(sp)          /* msg_len */
  sw    x14, 8(sp)           /* out_ptr */

  bn.xor w31, w31, w31       /* xof_absorb writes KMAC_DATA_S1 with w31 */

  /* Hash keys longer than the SHA3-256 block size (136B).
   * OTBN only has beq/bne, so use the sign-bit trick for the comparison. */
  li    x5, 136
  sub   x30, x11, x5           /* key_len - 136 */
  srli  x30, x30, 31           /* 1 if key_len < 136, else 0 */
  bne   x30, x0, hmac_key_ok
  beq   x11, x5, hmac_key_ok

  /* hmac_key_hashed = SHA3-256(key). */
  jal   x1, xof_sha3_256_init

  add   x21, x0, x10
  add   x20, x0, x11
  addi  x22, x0, 0
  jal   x1, xof_absorb

  jal   x1, xof_process

  jal   x1, xof_squeeze32
  bn.xor w0, w29, w30
  addi  x5, x0, 0
  la    x10, hmac_key_hashed
  bn.sid x5, 0(x10)

  jal   x1, xof_finish

  la    x10, hmac_key_hashed
  addi  x11, x0, 32

hmac_key_ok:
  /* Build ipad/opad: fill both pads with their constants, then XOR the key.
   * 160B per pad = 5 x 32B words. */
  la    x5, hmac_ipad
  la    x6, hmac_opad
  la    x12, const_0x36
  la    x13, const_0x5c
  li    x4, 0
  li    x7, 5
1:
  bn.lid x4, 0(x12++)
  bn.sid x4, 0(x5++)
  bn.lid x4, 0(x13++)
  bn.sid x4, 0(x6++)
  addi  x7, x7, -1
  bne   x7, x0, 1b

  /* XOR the key into both pads, word by word. */
  la    x5, hmac_ipad
  la    x6, hmac_opad
  srli  x7, x11, 2           /* complete words */
  beq   x7, x0, pad_tail

pad_wloop:
  lw    x8, 0(x10)
  lw    x9, 0(x5)
  lw    x15, 0(x6)
  xor   x9, x9, x8
  xor   x15, x15, x8
  sw    x9, 0(x5)
  sw    x15, 0(x6)
  addi  x10, x10, 4
  addi  x5, x5, 4
  addi  x6, x6, 4
  addi  x7, x7, -1
  bne   x7, x0, pad_wloop

pad_tail:
  /* XOR the key's trailing 1-3 bytes (read-modify-write with a byte mask). */
  andi  x7, x11, 3
  beq   x7, x0, pad_done

  li    x16, 1
  slli  x17, x7, 3
  sll   x16, x16, x17
  addi  x16, x16, -1

  lw    x8, 0(x10)
  and   x8, x8, x16

  lw    x9, 0(x5)
  xor   x9, x9, x8
  sw    x9, 0(x5)

  lw    x9, 0(x6)
  xor   x9, x9, x8
  sw    x9, 0(x6)

pad_done:
  /* inner = SHA3-256(ipad[0:136] || msg). Assemble the whole message in
   * hmac_msg and absorb it in one go. */
  la    x20, hmac_msg
  la    x21, hmac_ipad
  li    x7, 34                /* 136 / 4 words */
1:
  lw    x8, 0(x21)
  sw    x8, 0(x20)
  addi  x21, x21, 4
  addi  x20, x20, 4
  addi  x7, x7, -1
  bne   x7, x0, 1b

  lw    x21, 16(sp)          /* msg_ptr */
  lw    x13, 12(sp)          /* msg_len */
  srli  x7, x13, 2           /* complete words */
  beq   x7, x0, 2f
3:
  lw    x8, 0(x21)
  sw    x8, 0(x20)
  addi  x21, x21, 4
  addi  x20, x20, 4
  addi  x7, x7, -1
  bne   x7, x0, 3b
2:
  /* msg's trailing 1-3 bytes: mask and store (hmac_msg is zero-initialized,
   * so no read is needed). */
  andi  x7, x13, 3
  beq   x7, x0, 4f
  li    x16, 1
  slli  x17, x7, 3
  sll   x16, x16, x17
  addi  x16, x16, -1
  lw    x8, 0(x21)
  and   x8, x8, x16
  sw    x8, 0(x20)
4:
  jal   x1, xof_sha3_256_init

  la    x21, hmac_msg
  addi  x20, x13, 136
  addi  x22, x0, 0
  jal   x1, xof_absorb

  jal   x1, xof_process

  jal   x1, xof_squeeze32
  bn.xor w0, w29, w30
  addi  x5, x0, 0
  la    x10, hmac_inner
  bn.sid x5, 0(x10)

  jal   x1, xof_finish

  /* result = SHA3-256(opad[0:136] || inner). Same one-absorb pattern. */
  la    x20, hmac_msg
  la    x21, hmac_opad
  li    x7, 34                /* 136 / 4 words */
1:
  lw    x8, 0(x21)
  sw    x8, 0(x20)
  addi  x21, x21, 4
  addi  x20, x20, 4
  addi  x7, x7, -1
  bne   x7, x0, 1b

  la    x21, hmac_inner
  li    x7, 8                 /* 32 / 4 words */
2:
  lw    x8, 0(x21)
  sw    x8, 0(x20)
  addi  x21, x21, 4
  addi  x20, x20, 4
  addi  x7, x7, -1
  bne   x7, x0, 2b

  jal   x1, xof_sha3_256_init

  la    x21, hmac_msg
  addi  x20, x0, 168         /* 136 + 32 */
  addi  x22, x0, 0
  jal   x1, xof_absorb

  jal   x1, xof_process

  jal   x1, xof_squeeze32
  bn.xor w0, w29, w30
  addi  x5, x0, 0
  lw    x10, 8(sp)           /* out_ptr */
  bn.sid x5, 0(x10)

  jal   x1, xof_finish

  lw    ra, 20(sp)
  addi  sp, sp, 24
  ret
