/**
 * @file hybrid_kem_ref.h
 * @brief C reference implementation for Hybrid KEM.
 *
 * Provides the same API as the OTBN assembly version, so the test can
 * compute expected values and compare with CHECK_ARRAYS_EQ.
 *
 * Follows otbn_mlkem_test.c pattern from eprint 2025/2028.
 */

#ifndef TEST_HYBRID_KEM_PAPER_REF_HYBRID_KEM_REF_H_
#define TEST_HYBRID_KEM_PAPER_REF_HYBRID_KEM_REF_H_

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ================================================================
 * Constants
 * ================================================================ */

#define HYBRID_KEM_PK_M_BYTES 1184
#define HYBRID_KEM_SK_M_BYTES 2400
#define HYBRID_KEM_CT_M_BYTES 1088
#define HYBRID_KEM_SS_M_BYTES 32
#define HYBRID_KEM_PK_E_BYTES 64
#define HYBRID_KEM_SK_E_BYTES 32
#define HYBRID_KEM_MLKEM_SYMBYTES 32

/* ================================================================
 * API
 * ================================================================ */

/**
 * Hybrid KEM KeyGen reference.
 *
 * pk_e:  P-256 public key (d0 * G, 64 bytes uncompressed)
 * pk_m:  ML-KEM-768 public key (1184 bytes)
 * sk_m:  ML-KEM-768 secret key (2400 bytes)
 * d0:    P-256 scalar share 0 (32 bytes)
 * gx,gy: P-256 generator (32 bytes each)
 * coins: ML-KEM random coins (2*SYMBYTES bytes)
 */
void hybrid_kem_reference_keygen(uint8_t *pk_e, uint8_t *pk_m, uint8_t *sk_m,
                                 const uint8_t *d0, const uint8_t *gx,
                                 const uint8_t *gy, const uint8_t *coins);

/**
 * Hybrid KEM Encap reference.
 *
 * ct_m:  ML-KEM ciphertext (1088 bytes)
 * ss_m:  ML-KEM shared secret (32 bytes)
 * okm:   HKDF output — initiator (32 bytes)
 *        NOTE: okm_initiator ≠ okm_responder (role binding security)
 * pk_m:  ML-KEM public key (1184 bytes)
 * coins: ML-KEM random coins (SYMBYTES bytes)
 */
void hybrid_kem_reference_encap(uint8_t *ct_m, uint8_t *ss_m, uint8_t *okm,
                                const uint8_t *pk_m, const uint8_t *coins);

/**
 * Hybrid KEM Decap reference — returns responder OKM.
 */
void hybrid_kem_reference_decap(uint8_t *okm);

#ifdef __cplusplus
}
#endif

#endif  // TEST_HYBRID_KEM_PAPER_REF_HYBRID_KEM_REF_H_
