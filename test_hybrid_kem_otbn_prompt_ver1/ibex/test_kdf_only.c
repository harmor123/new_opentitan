/**
 * @file test_kdf_only.c
 * @brief Standalone KMAC-KDF chip sim test.
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

static const uint8_t kKatSsE[32] = {
    0x5f, 0x33, 0xd7, 0x46, 0xa3, 0x26, 0x64, 0x0a, 0x73, 0x9a, 0x94, 0x90, 0xec, 0x15, 0xc1, 0x03,
    0x72, 0x86, 0x9f, 0x3d, 0xe6, 0x75, 0xb2, 0xe8, 0x57, 0x42, 0x27, 0x1d, 0x18, 0xc9, 0xeb, 0x82,
};

static const uint8_t kKatSsM[32] = {
    0x37, 0x50, 0xac, 0x4a, 0x8e, 0x65, 0x63, 0x27, 0xc3, 0xd1, 0x81, 0xfa, 0xb0, 0x02, 0x55, 0x4b,
    0xf6, 0xd2, 0xbe, 0x04, 0x75, 0xdd, 0x28, 0xd5, 0xf3, 0x1b, 0xef, 0x9f, 0x83, 0x5f, 0x86, 0xac,
};

bool test_main(void) {
  dif_otbn_t otbn;
  CHECK_DIF_OK(dif_otbn_init_from_dt(kDtOtbn, &otbn));
  CHECK_STATUS_OK(entropy_testutils_auto_mode_init());

  LOG_INFO("Load kmac_kdf...");
  CHECK_STATUS_OK(otbn_testutils_load_app(&otbn, kApp));

  /* KDK = salt(32B) || ss_e(32B) || ss_m(32B) */
  uint8_t salt[32] = {
      0x00,0x01,0x02,0x03,0x04,0x05,0x06,0x07,
      0x08,0x09,0x0a,0x0b,0x0c,0x0d,0x0e,0x0f,
      0x10,0x11,0x12,0x13,0x14,0x15,0x16,0x17,
      0x18,0x19,0x1a,0x1b,0x1c,0x1d,0x1e,0x1f,
  };
  uint8_t kdk[96];
  memcpy(kdk, salt, 32);
  memcpy(kdk + 32, kKatSsE, 32);
  memcpy(kdk + 64, kKatSsM, 32);

  /* FixedInfo = Counter(1) || Label("HybridKEM-v1") || 0x00 || Context(0) || L=256 */
  uint8_t fixed[64] = {0};
  fixed[0] = 0x00; fixed[1] = 0x00; fixed[2] = 0x00; fixed[3] = 0x01;
  memcpy(fixed + 4, "HybridKEM-v1", 12);
  fixed[16] = 0x00;
  fixed[49] = 0x00; fixed[50] = 0x00; fixed[51] = 0x01; fixed[52] = 0x00;

  uint32_t kdk_len = 96;
  uint32_t fixed_len = 53;
  uint32_t fixed_pad = (fixed_len + 31) & ~31u;
  uint32_t okm_len = 32;

  CHECK_STATUS_OK(otbn_testutils_write_data(&otbn, kdk_len, kdk,
      OTBN_ADDR_T_INIT(kmac_kdf, kdk_input)));
  CHECK_STATUS_OK(otbn_testutils_write_data(&otbn, 4, &kdk_len,
      OTBN_ADDR_T_INIT(kmac_kdf, kdk_len)));
  CHECK_STATUS_OK(otbn_testutils_write_data(&otbn, fixed_pad, fixed,
      OTBN_ADDR_T_INIT(kmac_kdf, fixed_info)));
  CHECK_STATUS_OK(otbn_testutils_write_data(&otbn, 4, &fixed_len,
      OTBN_ADDR_T_INIT(kmac_kdf, fixed_len)));
  CHECK_STATUS_OK(otbn_testutils_write_data(&otbn, 4, &okm_len,
      OTBN_ADDR_T_INIT(kmac_kdf, okm_len)));

  LOG_INFO("Execute...");
  CHECK_STATUS_OK(otbn_testutils_execute(&otbn));
  CHECK_STATUS_OK(otbn_testutils_wait_for_done(&otbn, kDifOtbnErrBitsNoError));

  static uint8_t okm[32];
  CHECK_STATUS_OK(otbn_testutils_read_data(&otbn, sizeof(okm),
      OTBN_ADDR_T_INIT(kmac_kdf, output_okm), okm));

  static const uint8_t kExpectedOkm[32] = {
      0xe6, 0x43, 0x31, 0xbd, 0x94, 0x97, 0xa2, 0x02, 0x08, 0x7e, 0x79, 0x5d, 0x36, 0x88, 0x49, 0x24,
      0x19, 0xb4, 0x36, 0xd7, 0x23, 0x8c, 0xa9, 0xb1, 0xe3, 0xbf, 0x17, 0xe4, 0x68, 0x71, 0x7d, 0x8e,
  };
  CHECK_ARRAYS_EQ(okm, kExpectedOkm, sizeof(kExpectedOkm));

  return true;
}
