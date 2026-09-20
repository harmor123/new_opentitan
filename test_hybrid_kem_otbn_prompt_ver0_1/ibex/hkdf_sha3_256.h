/**
 * @file hkdf_sha3_256.h
 * @brief HKDF-SHA3-256 (RFC 5869) over HMAC-SHA3-256 (RFC 2104).
 *
 * Built on top of the official OpenTitan cryptolib one-shot
 * `otcrypto_sha3_256` (KMAC HWIP in SHA3-256 mode). This exists because the
 * official `otcrypto_hkdf` only supports HMAC-SHA2 modes, while RFC 10024
 * mandates HKDF-SHA3-256 for the hybrid KEM combiner.
 */

#ifndef OPENTITAN_TEST_HYBRID_KEM_OTBN_PROMPT_VER0_1_IBEX_HKDF_SHA3_256_H_
#define OPENTITAN_TEST_HYBRID_KEM_OTBN_PROMPT_VER0_1_IBEX_HKDF_SHA3_256_H_

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define HKDF_SHA3_256_HASH_LEN 32
#define HKDF_SHA3_256_BLOCK_LEN 136

/**
 * HKDF-Extract + HKDF-Expand with HMAC-SHA3-256.
 *
 * @param salt      Salt input (32 bytes in the hybrid KEM profile).
 * @param salt_len  Salt length in bytes.
 * @param ikm       Input keying material.
 * @param ikm_len   IKM length in bytes.
 * @param info      Context/application-specific info.
 * @param info_len  Info length in bytes.
 * @param[out] okm  Output keying material.
 * @param okm_len   OKM length in bytes (<= 32: single Expand block).
 * @return 0 on success, nonzero on failure.
 */
int hkdf_sha3_256(const uint8_t *salt, size_t salt_len, const uint8_t *ikm,
                  size_t ikm_len, const uint8_t *info, size_t info_len,
                  uint8_t *okm, size_t okm_len);

#ifdef __cplusplus
}
#endif

#endif  // OPENTITAN_TEST_HYBRID_KEM_OTBN_PROMPT_VER0_1_IBEX_HKDF_SHA3_256_H_
