/**
 * @file test_kdf_only.c
 * @brief Standalone KMAC-KDF (SHAKE256, ver0 software) chip sim test.
 *
 * Algorithm (NIST SP 800-108r1):
 *   FixedInfo = Counter(4B) || Label || 0x00 || Context || L_bits(4B)
 *   OKM = SHAKE256(KDK || FixedInfo, L)
 *
 * KDK = ss_e(32B) || ss_m(32B) (64B).
 * Pure software Keccak-f implementation via sha3_shake.s.
 */
#include "sw/device/lib/dif/dif_otbn.h"
#include "sw/device/lib/runtime/log.h"
#include "sw/device/lib/testing/entropy_testutils.h"
#include "sw/device/lib/testing/otbn_testutils.h"
#include "sw/device/lib/testing/test_framework/check.h"
#include "sw/device/lib/testing/test_framework/ottf_main.h"
#include <string.h>

OTTF_DEFINE_TEST_CONFIG();

OTBN_DECLARE_APP_SYMBOLS(kmac_kdf);
OTBN_DECLARE_SYMBOL_ADDR(kmac_kdf, kdk_input);
OTBN_DECLARE_SYMBOL_ADDR(kmac_kdf, kdk_len);
OTBN_DECLARE_SYMBOL_ADDR(kmac_kdf, fixed_info);
OTBN_DECLARE_SYMBOL_ADDR(kmac_kdf, fixed_len);
OTBN_DECLARE_SYMBOL_ADDR(kmac_kdf, okm_len);
OTBN_DECLARE_SYMBOL_ADDR(kmac_kdf, output_okm);
static const otbn_app_t kApp = OTBN_APP_T_INIT(kmac_kdf);

/* ss_e (32B) */
static const uint8_t kSsE[32] = {
    0x5f, 0x33, 0xd7, 0x46, 0xa3, 0x26, 0x64, 0x0a, 0x73, 0x9a, 0x94, 0x90, 0xec, 0x15, 0xc1, 0x03,
    0x72, 0x86, 0x9f, 0x3d, 0xe6, 0x75, 0xb2, 0xe8, 0x57, 0x42, 0x27, 0x1d, 0x18, 0xc9, 0xeb, 0x82,
};

/* ss_m (32B) */
static const uint8_t kSsM[32] = {
    0x37, 0x50, 0xac, 0x4a, 0x8e, 0x65, 0x63, 0x27, 0xc3, 0xd1, 0x81, 0xfa, 0xb0, 0x02, 0x55, 0x4b,
    0xf6, 0xd2, 0xbe, 0x04, 0x75, 0xdd, 0x28, 0xd5, 0xf3, 0x1b, 0xef, 0x9f, 0x83, 0x5f, 0x86, 0xac,
};

/* Context (32B) */
static const uint8_t kCtx[32] = {
    0x48, 0x79, 0x62, 0x72, 0x69, 0x64, 0x4b, 0x45,
    0x4d, 0x2d, 0x76, 0x31, 0x2d, 0x63, 0x6f, 0x6e,
    0x74, 0x65, 0x78, 0x74, 0x2d, 0x30, 0x31, 0x32,
    0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x41,
};

/* Expected OKM (KMAC-KDF SHAKE256 output, 32B) */
static const uint8_t kExpectedOkm[32] = {
    0x3b, 0xce, 0x19, 0x21, 0x9b, 0x4a, 0x68, 0x0c, 0x76, 0x3c, 0xa4, 0xaa, 0x0f, 0xbe, 0xd9, 0xf1,
    0xe5, 0xe2, 0x11, 0x84, 0xf9, 0x55, 0xa6, 0x40, 0xb5, 0xfb, 0xf9, 0xc7, 0xc9, 0x5b, 0xb8, 0x17,
};

bool test_main(void) {
  dif_otbn_t otbn;
  CHECK_DIF_OK(dif_otbn_init_from_dt(kDtOtbn, &otbn));
  CHECK_STATUS_OK(entropy_testutils_auto_mode_init());

  LOG_INFO("Load kmac_kdf...");
  CHECK_STATUS_OK(otbn_testutils_load_app(&otbn, kApp));

  /* Build KDK: ss_e(32B) || ss_m(32B) = 64B */
  uint8_t kdk[64];
  memcpy(kdk, kSsE, 32);
  memcpy(kdk + 32, kSsM, 32);

  /* Build FixedInfo: Counter(4B) || Label("") || 0x00(1B) || Context(32B) || L_bits(4B) */
  uint8_t fixed[256] = {0};
  fixed[0] = 0x00; fixed[1] = 0x00; fixed[2] = 0x00; fixed[3] = 0x01;  /* Counter = 1 BE */
  fixed[4] = 0x00;  /* separator */
  memcpy(fixed + 5, kCtx, sizeof(kCtx));                                 /* Context (32B) */
  fixed[37] = 0x00; fixed[38] = 0x00; fixed[39] = 0x01; fixed[40] = 0x00;  /* L_bits = 256 */

  CHECK_STATUS_OK(otbn_testutils_write_data(&otbn, sizeof(kdk), kdk,
      OTBN_ADDR_T_INIT(kmac_kdf, kdk_input)));

  uint32_t kdk_len = 64;
  CHECK_STATUS_OK(otbn_testutils_write_data(&otbn, 4, &kdk_len,
      OTBN_ADDR_T_INIT(kmac_kdf, kdk_len)));

  CHECK_STATUS_OK(otbn_testutils_write_data(&otbn, sizeof(fixed), fixed,
      OTBN_ADDR_T_INIT(kmac_kdf, fixed_info)));

  uint32_t fixed_len = 41;
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
  LOG_INFO("KMAC-KDF OK");

  return true;
}
