/**
 * @file test_hkdf_only.c
 * @brief Standalone HKDF-HMAC-SHA3-256 OTBN correctness test.
 *
 * Fixed Hybrid-KEM profile:
 *
 *   salt = 32 bytes
 *
 *   IKM  = ss_e || ss_m
 *        = 32B  || 32B
 *        = 64 bytes
 *
 *   info = ctx || sid
 *        = 32B || 32B
 *        = 64 bytes
 *
 *   OKM  = 32 bytes
 *
 * RFC 5869:
 *
 *   PRK  = HMAC-SHA3-256(salt, IKM)
 *
 *   T(1) = HMAC-SHA3-256(PRK, info || 0x01)
 *
 *   OKM  = T(1)
 */

#include "sw/device/lib/dif/dif_otbn.h"
#include "sw/device/lib/runtime/log.h"
#include "sw/device/lib/testing/entropy_testutils.h"
#include "sw/device/lib/testing/otbn_testutils.h"
#include "sw/device/lib/testing/test_framework/check.h"
#include "sw/device/lib/testing/test_framework/ottf_main.h"

#include <string.h>

OTTF_DEFINE_TEST_CONFIG();

/* OTBN application. */
OTBN_DECLARE_APP_SYMBOLS(hkdf_sha3_256);

OTBN_DECLARE_SYMBOL_ADDR(hkdf_sha3_256, input_salt);
OTBN_DECLARE_SYMBOL_ADDR(hkdf_sha3_256, ikm_prebuilt);
OTBN_DECLARE_SYMBOL_ADDR(hkdf_sha3_256, input_info);

OTBN_DECLARE_SYMBOL_ADDR(hkdf_sha3_256, hmac_key_hashed);
OTBN_DECLARE_SYMBOL_ADDR(hkdf_sha3_256, output_okm);

static const otbn_app_t kApp = OTBN_APP_T_INIT(hkdf_sha3_256);

/* ------------------------------------------------------------------
 * Fixed P-256 shared secret ss_e.
 * ------------------------------------------------------------------ */
static const uint8_t kSsE[32] = {
    0x5f, 0x33, 0xd7, 0x46, 0xa3, 0x26, 0x64, 0x0a,
    0x73, 0x9a, 0x94, 0x90, 0xec, 0x15, 0xc1, 0x03,
    0x72, 0x86, 0x9f, 0x3d, 0xe6, 0x75, 0xb2, 0xe8,
    0x57, 0x42, 0x27, 0x1d, 0x18, 0xc9, 0xeb, 0x82,
};

/* ------------------------------------------------------------------
 * Fixed ML-KEM shared secret ss_m.
 * ------------------------------------------------------------------ */
static const uint8_t kSsM[32] = {
    0x37, 0x50, 0xac, 0x4a, 0x8e, 0x65, 0x63, 0x27,
    0xc3, 0xd1, 0x81, 0xfa, 0xb0, 0x02, 0x55, 0x4b,
    0xf6, 0xd2, 0xbe, 0x04, 0x75, 0xdd, 0x28, 0xd5,
    0xf3, 0x1b, 0xef, 0x9f, 0x83, 0x5f, 0x86, 0xac,
};

/* ------------------------------------------------------------------
 * Fixed 32-byte HKDF salt.
 * ------------------------------------------------------------------ */
static const uint8_t kSalt[32] = {
    0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
    0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f,
    0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17,
    0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f,
};

/* ------------------------------------------------------------------
 * Fixed 32-byte protocol context.
 * ------------------------------------------------------------------ */
static const uint8_t kCtx[32] = {
    0x48, 0x79, 0x62, 0x72, 0x69, 0x64, 0x4b, 0x45,
    0x4d, 0x2d, 0x76, 0x31, 0x2d, 0x63, 0x6f, 0x6e,
    0x74, 0x65, 0x78, 0x74, 0x2d, 0x30, 0x31, 0x32,
    0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x41,
};

/* ------------------------------------------------------------------
 * Fixed 32-byte session identifier.
 * ------------------------------------------------------------------ */
static const uint8_t kSid[32] = {
    0x53, 0x65, 0x73, 0x73, 0x69, 0x6f, 0x6e, 0x2d,
    0x30, 0x34, 0x32, 0x2d, 0x72, 0x75, 0x6e, 0x2d,
    0x58, 0x59, 0x5a, 0x39, 0x38, 0x37, 0x36, 0x35,
    0x34, 0x33, 0x32, 0x31, 0x30, 0x66, 0x65, 0x64,
};

/* ------------------------------------------------------------------
 * Reference:
 *
 * PRK = HMAC-SHA3-256(salt, ss_e || ss_m)
 *
 * Generated independently with Python hashlib/hmac.
 * ------------------------------------------------------------------ */
static const uint8_t kExpectedPrk[32] = {
    0x23, 0xb3, 0x0e, 0x32, 0x9a, 0xbb, 0x08, 0x87,
    0x0d, 0x95, 0xfe, 0xfe, 0x1e, 0x8e, 0xb2, 0x07,
    0x8a, 0xf6, 0x35, 0xa3, 0x07, 0x91, 0x71, 0x56,
    0xf6, 0xa5, 0xa4, 0xec, 0x6b, 0x08, 0xd9, 0x37,
};

/* ------------------------------------------------------------------
 * Reference:
 *
 * OKM = HMAC-SHA3-256(PRK, ctx || sid || 0x01)
 *
 * Since L = 32B, HKDF-Expand only needs T(1).
 * ------------------------------------------------------------------ */
static const uint8_t kExpectedOkm[32] = {
    0x88, 0x8b, 0x1d, 0xee, 0x8d, 0x1c, 0xd1, 0x90,
    0xa8, 0x2f, 0xf3, 0x4a, 0xa8, 0xdd, 0x5d, 0xda,
    0x3a, 0x99, 0xe3, 0xc6, 0x46, 0x45, 0xa0, 0x73,
    0x2c, 0x08, 0x5b, 0x16, 0x14, 0x1e, 0x38, 0xb5,
};

bool test_main(void) {
  dif_otbn_t otbn;

  CHECK_DIF_OK(dif_otbn_init_from_dt(kDtOtbn, &otbn));
  CHECK_STATUS_OK(entropy_testutils_auto_mode_init());

  LOG_INFO("Load HKDF-HMAC-SHA3-256 OTBN app...");
  CHECK_STATUS_OK(otbn_testutils_load_app(&otbn, kApp));

  /* --------------------------------------------------------------
   * Build fixed 64B IKM:
   *
   * IKM = ss_e || ss_m
   * -------------------------------------------------------------- */
  uint8_t ikm[64];

  memcpy(&ikm[0], kSsE, 32);
  memcpy(&ikm[32], kSsM, 32);

  /* --------------------------------------------------------------
   * Build fixed 64B info:
   *
   * info = ctx || sid
   * -------------------------------------------------------------- */
  uint8_t info[64];

  memcpy(&info[0], kCtx, 32);
  memcpy(&info[32], kSid, 32);

  /* --------------------------------------------------------------
   * Write fixed inputs to OTBN DMEM.
   * -------------------------------------------------------------- */
  CHECK_STATUS_OK(otbn_testutils_write_data(
      &otbn, sizeof(kSalt), kSalt,
      OTBN_ADDR_T_INIT(hkdf_sha3_256, input_salt)));

  CHECK_STATUS_OK(otbn_testutils_write_data(
      &otbn, sizeof(ikm), ikm,
      OTBN_ADDR_T_INIT(hkdf_sha3_256, ikm_prebuilt)));

  CHECK_STATUS_OK(otbn_testutils_write_data(
      &otbn, sizeof(info), info,
      OTBN_ADDR_T_INIT(hkdf_sha3_256, input_info)));

  /* --------------------------------------------------------------
   * Execute OTBN:
   *
   * hkdf_extract()
   * hkdf_expand()
   * -------------------------------------------------------------- */
  LOG_INFO("Execute HKDF...");

  CHECK_STATUS_OK(otbn_testutils_execute(&otbn));

  CHECK_STATUS_OK(
      otbn_testutils_wait_for_done(&otbn, kDifOtbnErrBitsNoError));

  /* --------------------------------------------------------------
   * Read PRK and final OKM.
   * -------------------------------------------------------------- */
  uint8_t prk[32];
  uint8_t okm[32];

  CHECK_STATUS_OK(otbn_testutils_read_data(
      &otbn, sizeof(prk),
      OTBN_ADDR_T_INIT(hkdf_sha3_256, hmac_key_hashed),
      prk));

  CHECK_STATUS_OK(otbn_testutils_read_data(
      &otbn, sizeof(okm),
      OTBN_ADDR_T_INIT(hkdf_sha3_256, output_okm),
      okm));

  /* --------------------------------------------------------------
   * Primitive correctness checks.
   * -------------------------------------------------------------- */
  CHECK_ARRAYS_EQ(prk, kExpectedPrk, sizeof(kExpectedPrk));

  CHECK_ARRAYS_EQ(okm, kExpectedOkm, sizeof(kExpectedOkm));

  LOG_INFO("HKDF-HMAC-SHA3-256 correctness PASS.");

  return true;
}