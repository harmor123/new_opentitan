/**
 * @file phase2_alice_encap.c
 * @brief Phase 2 Alice: Hybrid KEM Encapsulation.
 *
 * Flow:
 *   1. P-256 ephemeral key → ECDH(sk_e_alice, pk_e_bob) → ss_e
 *   2. ML-KEM encap(pk_m) → ct_m, ss_m
 *   3. HKDF-Extract(salt, IKM) → PRK
 *   4. HKDF-Expand(PRK, info="", L) → OKM (KEM unified output)
 *
 * IKM = len_cls(2B)||ss_e(32B)||len_pqc(2B)||ss_m(32B)||ctx||sid
 * (No role in IKM; role binding via info in HKDF-Expand)
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

/* ---- Expected OKM ---- */
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

  /* ---- Step 1: P-256 ECDH → ss_e ---- */
  CHECK_STATUS_OK(otbn_testutils_load_app(&otbn, kAppP256));

  CHECK_STATUS_OK(otbn_testutils_write_data(&otbn, 64, kSkE_Alice_D0,
      OTBN_ADDR_T_INIT(p256_ecdh_shared_key, d0)));
  CHECK_STATUS_OK(otbn_testutils_write_data(&otbn, 64, kSkE_Alice_D1,
      OTBN_ADDR_T_INIT(p256_ecdh_shared_key, d1)));
  CHECK_STATUS_OK(otbn_testutils_write_data(&otbn, 32, kPkE_Bob_X,
      OTBN_ADDR_T_INIT(p256_ecdh_shared_key, x)));
  CHECK_STATUS_OK(otbn_testutils_write_data(&otbn, 32, kPkE_Bob_Y,
      OTBN_ADDR_T_INIT(p256_ecdh_shared_key, y)));

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
  LOG_INFO("Alice ECDH OK");

  /* Secure wipe before next OTBN app */
  CHECK_DIF_OK(dif_otbn_write_cmd(&otbn, kDifOtbnCmdSecWipeDmem));
  CHECK_STATUS_OK(otbn_testutils_wait_for_done(&otbn, kDifOtbnErrBitsNoError));

  /* ---- Step 2: ML-KEM encap → ct_m, ss_m ---- */
  CHECK_STATUS_OK(otbn_testutils_load_app(&otbn, kAppEncap));

  CHECK_STATUS_OK(otbn_testutils_write_data(&otbn, sizeof(kAliceCoins),
      kAliceCoins, OTBN_ADDR_T_INIT(mlkem768_encap, coins)));
  CHECK_STATUS_OK(otbn_testutils_write_data(&otbn, sizeof(kPkM_Bob),
      kPkM_Bob, OTBN_ADDR_T_INIT(mlkem768_encap, ek)));

  CHECK_STATUS_OK(otbn_testutils_execute(&otbn));
  CHECK_STATUS_OK(otbn_testutils_wait_for_done(&otbn, kDifOtbnErrBitsNoError));

  uint8_t ct_m[1088], ss_m[32];
  CHECK_STATUS_OK(otbn_testutils_read_data(&otbn, sizeof(ct_m),
      OTBN_ADDR_T_INIT(mlkem768_encap, ct), ct_m));
  CHECK_STATUS_OK(otbn_testutils_read_data(&otbn, sizeof(ss_m),
      OTBN_ADDR_T_INIT(mlkem768_encap, ss), ss_m));

  CHECK_ARRAYS_EQ(ct_m, kExpectedCtM, sizeof(kExpectedCtM));
  CHECK_ARRAYS_EQ(ss_m, kExpectedSsM, sizeof(kExpectedSsM));
  LOG_INFO("Alice ML-KEM Encap OK");

  /* Secure wipe before next OTBN app */
  CHECK_DIF_OK(dif_otbn_write_cmd(&otbn, kDifOtbnCmdSecWipeDmem));
  CHECK_STATUS_OK(otbn_testutils_wait_for_done(&otbn, kDifOtbnErrBitsNoError));

  /* ---- Step 3: KMAC-KDF(salt||ss_e||ss_m, L=32) -> OKM (KEM unified) ---- */
  CHECK_STATUS_OK(otbn_testutils_load_app(&otbn, kAppKdf));

  /* Build KDK: salt(32B) || ss_e(32B) || ss_m(32B) = 96B */
  uint8_t kdk[96];
  memcpy(kdk, kSalt, 32);
  memcpy(kdk + 32, ss_e, 32);
  memcpy(kdk + 64, ss_m, 32);

  /* Build FixedInfo: Counter(4B) || Label(12B) || 0x00(1B) || Context(32B) || L_bits(4B) */
  uint8_t fixed[256] = {0};
  fixed[0] = 0x00; fixed[1] = 0x00; fixed[2] = 0x00; fixed[3] = 0x01;  /* Counter = 1 BE */
  memcpy(fixed + 4, kLabel, sizeof(kLabel));                            /* Label = "HybridKEM-v1" */
  fixed[16] = 0x00;                                                      /* separator */
  memcpy(fixed + 17, kCtx, sizeof(kCtx));                                /* Context (32B) */
  fixed[49] = 0x00; fixed[50] = 0x00; fixed[51] = 0x01; fixed[52] = 0x00;  /* L_bits = 256 */

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

  CHECK_STATUS_OK(otbn_testutils_execute(&otbn));
  CHECK_STATUS_OK(otbn_testutils_wait_for_done(&otbn, kDifOtbnErrBitsNoError));

  uint8_t okm[32];
  CHECK_STATUS_OK(otbn_testutils_read_data(&otbn, sizeof(okm),
      OTBN_ADDR_T_INIT(kmac_kdf, output_okm), okm));

  CHECK_ARRAYS_EQ(okm, kExpectedOkm, sizeof(kExpectedOkm));
  LOG_INFO("Alice KMAC-KDF OK");

  return true;
}
