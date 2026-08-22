/* ================================================================
 * hmac.s
 *
 * Fixed-key HMAC-SHA3-256 for current HKDF profile.
 *
 * Required key length:
 *   32 bytes
 *
 * Calling convention:
 *
 *   x10 = key pointer
 *   x11 = key length (expected 32)
 *   x12 = message pointer
 *   x13 = message length
 *   x14 = output pointer
 *
 * SHA3-256 block/rate:
 *   136 bytes
 * ================================================================ */

.section .text

.globl hmac_sha3_256
hmac_sha3_256:

  /* --------------------------------------------------------------
   * Save values that must survive SHA3 calls.
   *
   * x2 is our software stack pointer.
   *
   * NOTE:
   * x1 is NOT saved here.
   * OTBN manages x1 as its hardware call stack.
   * -------------------------------------------------------------- */

  addi    x2, x2, -16

  sw      x12, 0(x2)       /* message pointer */
  sw      x13, 4(x2)       /* message length */
  sw      x14, 8(x2)       /* output pointer */


  /* Ensure all-zero WDR for SHA3. */

  bn.xor  w31, w31, w31


  /* ==============================================================
   * Create:
   *
   * ipad = 136 bytes of 0x36
   * opad = 136 bytes of 0x5c
   * ============================================================== */

  la      x5, hmac_ipad
  la      x6, hmac_opad

  li      x7, 34           /* 136 / 4 = 34 words */

  li      x8, 0x36363636
  li      x9, 0x5c5c5c5c

1:
  sw      x8, 0(x5)
  sw      x9, 0(x6)

  addi    x5, x5, 4
  addi    x6, x6, 4

  addi    x7, x7, -1
  bne     x7, x0, 1b


  /* ==============================================================
   * XOR 32-byte key into first 32 bytes of ipad/opad.
   *
   * 32B = 8 words.
   * ============================================================== */

  la      x5, hmac_ipad
  la      x6, hmac_opad

  li      x7, 8

2:
  lw      x8, 0(x10)
  lw      x9, 0(x5)
  lw      x15, 0(x6)

  xor     x9, x9, x8
  xor     x15, x15, x8

  sw      x9, 0(x5)
  sw      x15, 0(x6)

  addi    x10, x10, 4
  addi    x5, x5, 4
  addi    x6, x6, 4

  addi    x7, x7, -1
  bne     x7, x0, 2b


  /* ==============================================================
   * INNER:
   *
   * inner =
   * SHA3-256(
   *     ipad[0:136] ||
   *     message
   * )
   * ============================================================== */

  la      x10, context
  li      x11, 32
  jal     x1, sha3_init


  la      x10, context
  la      x11, hmac_ipad
  li      x12, 136
  jal     x1, sha3_update


  la      x10, context
  lw      x11, 0(x2)       /* message pointer */
  lw      x12, 4(x2)       /* message length */
  jal     x1, sha3_update


  la      x10, context
  la      x11, hmac_inner
  jal     x1, sha3_final


  /* ==============================================================
   * OUTER:
   *
   * result =
   * SHA3-256(
   *     opad[0:136] ||
   *     inner
   * )
   * ============================================================== */

  la      x10, context
  li      x11, 32
  jal     x1, sha3_init


  la      x10, context
  la      x11, hmac_opad
  li      x12, 136
  jal     x1, sha3_update


  la      x10, context
  la      x11, hmac_inner
  li      x12, 32
  jal     x1, sha3_update


  la      x10, context
  lw      x11, 8(x2)       /* output pointer */
  jal     x1, sha3_final


  /* Restore software stack. */

  addi    x2, x2, 16

  ret