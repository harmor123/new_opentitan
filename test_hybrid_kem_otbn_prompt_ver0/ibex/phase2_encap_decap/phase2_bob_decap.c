/**
 * @file phase2_bob_decap.c
 * @brief Phase 2 Bob: Hybrid KEM Decapsulation.
 *
 * Flow:
 *   1. ML-KEM decap(ct_m, sk_m) → ss_m  (内部含 re-encryption check)
 *   2. P-256 ECDH(d_bob, Q_alice) → ss_e
 *   3. HKDF-Extract(salt, IKM) → PRK
 *   4. HKDF-Expand(PRK, info="", L) → OKM (== Alice OKM)
 *
 * IKM = len_cls(2B)||ss_e(32B)||len_pqc(2B)||ss_m(32B)||ctx||sid
 */

#include "sw/device/lib/dif/dif_otbn.h"
#include "sw/device/lib/runtime/log.h"
#include "sw/device/lib/testing/entropy_testutils.h"
#include "sw/device/lib/testing/otbn_testutils.h"
#include "sw/device/lib/testing/test_framework/check.h"
#include "sw/device/lib/testing/test_framework/ottf_main.h"
#include <string.h>

OTTF_DEFINE_TEST_CONFIG();

/* ================================================================
 * KMAC-KDF (NIST SP 800-108r1) -- software SHAKE256 via sha3_shake.s
 * ================================================================ */
OTBN_DECLARE_APP_SYMBOLS(kmac_kdf);
OTBN_DECLARE_SYMBOL_ADDR(kmac_kdf, kdk_input);
OTBN_DECLARE_SYMBOL_ADDR(kmac_kdf, kdk_len);
OTBN_DECLARE_SYMBOL_ADDR(kmac_kdf, fixed_info);
OTBN_DECLARE_SYMBOL_ADDR(kmac_kdf, fixed_len);
OTBN_DECLARE_SYMBOL_ADDR(kmac_kdf, okm_len);
OTBN_DECLARE_SYMBOL_ADDR(kmac_kdf, output_okm);
static const otbn_app_t kAppKdf = OTBN_APP_T_INIT(kmac_kdf);

/* ---- KMAC-KDF parameters ---- */
static const uint8_t kSalt[32] = {
    0x00,0x01,0x02,0x03,0x04,0x05,0x06,0x07,
    0x08,0x09,0x0a,0x0b,0x0c,0x0d,0x0e,0x0f,
    0x10,0x11,0x12,0x13,0x14,0x15,0x16,0x17,
    0x18,0x19,0x1a,0x1b,0x1c,0x1d,0x1e,0x1f,
};
static const uint8_t kCtx[32] = {
    0x48,0x79,0x62,0x72,0x69,0x64,0x4b,0x45,
    0x4d,0x2d,0x76,0x31,0x2d,0x63,0x6f,0x6e,
    0x74,0x65,0x78,0x74,0x2d,0x30,0x31,0x32,
    0x33,0x34,0x35,0x36,0x37,0x38,0x39,0x41,
};
/* kSid removed -- not used in KMAC-KDF */
static const uint8_t kLabel[12] = {
    0x48,0x79,0x62,0x72,0x69,0x64,0x4b,0x45,
    0x4d,0x2d,0x76,0x31,  // "HybridKEM-v1"
};

/* ---- Expected OKM (KMAC-KDF, == Alice OKM) ---- */
static const uint8_t kExpectedOkm[32] = {
    0x35,0x96,0xa8,0x4d,0xf3,0xb2,0x43,0x15,0x64,0x22,0x32,0xd3,0x10,0x8b,0x69,0xcd,
    0x56,0x2d,0x6f,0x64,0xac,0xb7,0x24,0x79,0xdb,0xe0,0xf5,0xa6,0x41,0x46,0x8e,0x67,
};

/* ================================================================
 * Test main
 * ================================================================ */
bool test_main(void) {
  dif_otbn_t otbn;
  CHECK_DIF_OK(dif_otbn_init_from_dt(kDtOtbn, &otbn));
  CHECK_STATUS_OK(entropy_testutils_auto_mode_init());

  /* ---- Step 1: ML-KEM decap → ss_m ---- */
  LOG_INFO("Load mlkem768_decap...");
  CHECK_STATUS_OK(otbn_testutils_load_app(&otbn, kAppDecap));

  LOG_INFO("Write ct_m, sk_m...");
  CHECK_STATUS_OK(otbn_testutils_write_data(&otbn, sizeof(kInputCtM),
      kInputCtM, OTBN_ADDR_T_INIT(mlkem768_decap, ct)));
  CHECK_STATUS_OK(otbn_testutils_write_data(&otbn, sizeof(kInputSkM),
      kInputSkM, OTBN_ADDR_T_INIT(mlkem768_decap, dk)));

  LOG_INFO("Execute ML-KEM decap...");
  CHECK_STATUS_OK(otbn_testutils_execute(&otbn));
  CHECK_STATUS_OK(otbn_testutils_wait_for_done(&otbn, kDifOtbnErrBitsNoError));

  uint8_t ss_m[32];
  CHECK_STATUS_OK(otbn_testutils_read_data(&otbn, sizeof(ss_m),
      OTBN_ADDR_T_INIT(mlkem768_decap, ss), ss_m));

  CHECK_ARRAYS_EQ(ss_m, kExpectedSsM, sizeof(kExpectedSsM));
  LOG_INFO("Bob ML-KEM Decap OK");

  /* Secure wipe before next OTBN app */
  CHECK_DIF_OK(dif_otbn_write_cmd(&otbn, kDifOtbnCmdSecWipeDmem));
  CHECK_STATUS_OK(otbn_testutils_wait_for_done(&otbn, kDifOtbnErrBitsNoError));

  /* ---- Step 2: P-256 ECDH (d_bob, Q_alice) → ss_e ---- */
  LOG_INFO("Load p256_ecdh_shared_key...");
  CHECK_STATUS_OK(otbn_testutils_load_app(&otbn, kAppP256));

  LOG_INFO("Write d_bob, Q_alice...");
  CHECK_STATUS_OK(otbn_testutils_write_data(&otbn, 64, kInputD0,
      OTBN_ADDR_T_INIT(p256_ecdh_shared_key, d0)));
  CHECK_STATUS_OK(otbn_testutils_write_data(&otbn, 64, kInputD1,
      OTBN_ADDR_T_INIT(p256_ecdh_shared_key, d1)));
  CHECK_STATUS_OK(otbn_testutils_write_data(&otbn, 32, kQAliceX,
      OTBN_ADDR_T_INIT(p256_ecdh_shared_key, x)));
  CHECK_STATUS_OK(otbn_testutils_write_data(&otbn, 32, kQAliceY,
      OTBN_ADDR_T_INIT(p256_ecdh_shared_key, y)));

  LOG_INFO("Execute P-256 ECDH...");
  CHECK_STATUS_OK(otbn_testutils_execute(&otbn));
  CHECK_STATUS_OK(otbn_testutils_wait_for_done(&otbn, kDifOtbnErrBitsNoError));

  uint8_t x0[32], x1[32];
  CHECK_STATUS_OK(otbn_testutils_read_data(&otbn, 32,
      OTBN_ADDR_T_INIT(p256_ecdh_shared_key, x), x0));
  CHECK_STATUS_OK(otbn_testutils_read_data(&otbn, 32,
      OTBN_ADDR_T_INIT(p256_ecdh_shared_key, y), x1));

  uint8_t ss_e[32];
  for (int i = 0; i < 32; ++i) ss_e[i] = x0[i] ^ x1[i];
  CHECK_ARRAYS_EQ(ss_e, kExpectedSsE, sizeof(kExpectedSsE));
  LOG_INFO("Bob ECDH OK");

  /* Secure wipe before next OTBN app */
  CHECK_DIF_OK(dif_otbn_write_cmd(&otbn, kDifOtbnCmdSecWipeDmem));
  CHECK_STATUS_OK(otbn_testutils_wait_for_done(&otbn, kDifOtbnErrBitsNoError));

  /* ---- Step 3: KMAC-KDF(salt||ss_e||ss_m, L=32) -> OKM (== Alice OKM) ---- */
  LOG_INFO("Load kmac_kdf...");
  CHECK_STATUS_OK(otbn_testutils_load_app(&otbn, kAppKdf));

  /* Build KDK: salt(32B) || ss_e(32B) || ss_m(32B) = 96B */
  uint8_t kdk[96];
  memcpy(kdk, kSalt, 32);
  memcpy(kdk + 32, ss_e, 32);
  memcpy(kdk + 64, ss_m, 32);

  /* Build FixedInfo: Counter(4B) || Label(12B) || 0x00(1B) || Context(32B) || L_bits(4B) */
  uint8_t fixed[256] = {0};
  fixed[0] = 0x00; fixed[1] = 0x00; fixed[2] = 0x00; fixed[3] = 0x01;
  memcpy(fixed + 4, kLabel, sizeof(kLabel));
  fixed[16] = 0x00;
  memcpy(fixed + 17, kCtx, sizeof(kCtx));
  fixed[49] = 0x00; fixed[50] = 0x00; fixed[51] = 0x01; fixed[52] = 0x00;

  CHECK_STATUS_OK(otbn_testutils_write_data(&otbn, sizeof(kdk), kdk,
      OTBN_ADDR_T_INIT(kmac_kdf, kdk_input)));

  uint32_t kdk_len = 96;
  CHECK_STATUS_OK(otbn_testutils_write_data(&otbn, 4, &kdk_len,
      OTBN_ADDR_T_INIT(kmac_kdf, kdk_len)));

  CHECK_STATUS_OK(otbn_testutils_write_data(&otbn, sizeof(fixed), fixed,
      OTBN_ADDR_T_INIT(kmac_kdf, fixed_info)));

  uint32_t fixed_len = 53;
  CHECK_STATUS_OK(otbn_testutils_write_data(&otbn, 4, &fixed_len,
      OTBN_ADDR_T_INIT(kmac_kdf, fixed_len)));

  uint32_t okm_len = 32;
  CHECK_STATUS_OK(otbn_testutils_write_data(&otbn, 4, &okm_len,
      OTBN_ADDR_T_INIT(kmac_kdf, okm_len)));

  LOG_INFO("Execute KMAC-KDF...");
  CHECK_STATUS_OK(otbn_testutils_execute(&otbn));
  CHECK_STATUS_OK(otbn_testutils_wait_for_done(&otbn, kDifOtbnErrBitsNoError));

  uint8_t okm[32];
  CHECK_STATUS_OK(otbn_testutils_read_data(&otbn, sizeof(okm),
      OTBN_ADDR_T_INIT(kmac_kdf, output_okm), okm));

  CHECK_ARRAYS_EQ(okm, kExpectedOkm, sizeof(kExpectedOkm));
  LOG_INFO("Bob KMAC-KDF OK");

  return true;
}
