/**
 * @file hkdf_sha3_256.c
 * @brief HKDF-SHA3-256 (RFC 5869) over HMAC-SHA3-256 (RFC 2104).
 *
 * The underlying hash is the official `otcrypto_sha3_256`, which executes on
 * the KMAC HWIP in SHA3-256 mode. SHA3-256 has block size B = 136 bytes and
 * digest length L = 32 bytes; all keys in the hybrid KEM profile are <= 32
 * bytes, so HMAC key preprocessing (hashing keys longer than B) is not needed.
 */

#include "test_hybrid_kem_otbn_prompt_ver0_1/ibex/hkdf_sha3_256.h"

#include "sw/device/lib/crypto/include/datatypes.h"
#include "sw/device/lib/crypto/include/sha3.h"
#include "sw/device/lib/crypto/include/status.h"

#include <string.h>

// Maximum message length supported by the single-buffer HMAC construction:
// HKDF-Extract IKM (<= 160 bytes in this profile) and HKDF-Expand
// (info || 0x01, <= 65 bytes).
#define HMAC_MAX_MSG_LEN 176

static int sha3_256(const uint8_t *msg, size_t msg_len, uint8_t out[32]) {
  uint32_t digest_words[HKDF_SHA3_256_HASH_LEN / sizeof(uint32_t)] = {0};
  const otcrypto_const_byte_buf_t message = {
      .data = (unsigned char *)msg,
      .len = msg_len,
  };
  otcrypto_hash_digest_t digest = {
      .mode = kOtcryptoHashModeSha3_256,
      .data = digest_words,
      .len = HKDF_SHA3_256_HASH_LEN / sizeof(uint32_t),
  };
  if (otcrypto_sha3_256(&message, &digest) != kOtcryptoStatusOk) {
    return -1;
  }
  memcpy(out, digest_words, HKDF_SHA3_256_HASH_LEN);
  return 0;
}

/**
 * HMAC-SHA3-256 (RFC 2104): HMAC(K, m) = H((K' ^ opad) || H((K' ^ ipad) || m)).
 *
 * @param key     Key; must be <= 136 bytes (no pre-hash path).
 * @param key_len Key length in bytes.
 * @param msg     Message; must be <= HMAC_MAX_MSG_LEN bytes.
 * @param msg_len Message length in bytes.
 * @param[out] out 32-byte MAC.
 */
static int hmac_sha3_256(const uint8_t *key, size_t key_len,
                         const uint8_t *msg, size_t msg_len,
                         uint8_t out[32]) {
  if (key_len > HKDF_SHA3_256_BLOCK_LEN ||
      msg_len > HMAC_MAX_MSG_LEN) {
    return -1;
  }

  uint8_t k_pad[HKDF_SHA3_256_BLOCK_LEN];
  uint8_t buf[HKDF_SHA3_256_BLOCK_LEN + HMAC_MAX_MSG_LEN];
  uint8_t inner[32];

  // K' = key zero-padded to block size.
  memset(k_pad, 0, sizeof(k_pad));
  memcpy(k_pad, key, key_len);

  // Inner: H((K' ^ ipad) || msg).
  for (size_t i = 0; i < HKDF_SHA3_256_BLOCK_LEN; ++i) {
    buf[i] = k_pad[i] ^ 0x36;
  }
  memcpy(buf + HKDF_SHA3_256_BLOCK_LEN, msg, msg_len);
  if (sha3_256(buf, HKDF_SHA3_256_BLOCK_LEN + msg_len, inner) != 0) {
    return -1;
  }

  // Outer: H((K' ^ opad) || inner).
  for (size_t i = 0; i < HKDF_SHA3_256_BLOCK_LEN; ++i) {
    buf[i] = k_pad[i] ^ 0x5c;
  }
  memcpy(buf + HKDF_SHA3_256_BLOCK_LEN, inner, sizeof(inner));
  if (sha3_256(buf, HKDF_SHA3_256_BLOCK_LEN + sizeof(inner), out) != 0) {
    return -1;
  }

  return 0;
}

int hkdf_sha3_256(const uint8_t *salt, size_t salt_len, const uint8_t *ikm,
                  size_t ikm_len, const uint8_t *info, size_t info_len,
                  uint8_t *okm, size_t okm_len) {
  if (okm_len > HKDF_SHA3_256_HASH_LEN || ikm_len > HMAC_MAX_MSG_LEN ||
      info_len > HMAC_MAX_MSG_LEN - 1) {
    return -1;
  }

  uint8_t prk[HKDF_SHA3_256_HASH_LEN];
  uint8_t expand_msg[HMAC_MAX_MSG_LEN];

  // HKDF-Extract: PRK = HMAC(salt, IKM).
  if (hmac_sha3_256(salt, salt_len, ikm, ikm_len, prk) != 0) {
    return -1;
  }

  // HKDF-Expand: T(1) = HMAC(PRK, info || 0x01).
  // A single block suffices since okm_len <= 32 bytes.
  memcpy(expand_msg, info, info_len);
  expand_msg[info_len] = 0x01;
  if (hmac_sha3_256(prk, sizeof(prk), expand_msg, info_len + 1, okm) != 0) {
    return -1;
  }

  return 0;
}
