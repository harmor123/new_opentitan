/* ================================================================
 * hkdf_sha3_256.s
 *
 * Fixed profile:
 *
 * IKM  = ss_e || ss_m = 64B
 * info = ctx || sid    = 64B
 * OKM  = 32B
 * ================================================================ */

.section .text


/* ================================================================
 * HKDF-Extract
 *
 * PRK = HMAC-SHA3-256(salt, IKM)
 * ================================================================ */

.globl hkdf_extract
hkdf_extract:

  la      x10, input_salt
  li      x11, 32

  la      x12, ikm_prebuilt
  li      x13, 64

  la      x14, hmac_key_hashed

  jal     x1, hmac_sha3_256

  ret


/* ================================================================
 * HKDF-Expand
 *
 * L = 32B = one SHA3-256 digest.
 *
 * T(1) = HMAC(PRK, info || 0x01)
 * OKM  = T(1)
 * ================================================================ */

.globl hkdf_expand
hkdf_expand:

  /* Copy 64B info to temporary buffer. */

  la      x20, input_info
  la      x21, ikm_buf
  li      x22, 16

1:
  lw      x23, 0(x20)
  sw      x23, 0(x21)

  addi    x20, x20, 4
  addi    x21, x21, 4

  addi    x22, x22, -1
  bne     x22, x0, 1b


  /* Append counter byte 0x01.
   *
   * sw writes:
   *
   * 01 00 00 00
   *
   * but msg_len below is 65B, so HMAC consumes only the
   * first appended byte.
   */

  li      x23, 1
  sw      x23, 0(x21)


  /* T(1) = HMAC(PRK, info || 0x01)
   *
   * Because OKM is exactly 32B, write T(1) directly into output_okm.
   */

  la      x10, hmac_key_hashed
  li      x11, 32

  la      x12, ikm_buf
  li      x13, 65

  la      x14, output_okm

  jal     x1, hmac_sha3_256

  ret