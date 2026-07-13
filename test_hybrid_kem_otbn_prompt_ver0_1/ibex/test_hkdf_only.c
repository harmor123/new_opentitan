/**
 * @file test_hkdf_only.c
 * @brief Standalone HKDF-SHA3-256 chip sim test.
 */
#include "sw/device/lib/dif/dif_otbn.h"
#include "sw/device/lib/runtime/log.h"
#include "sw/device/lib/testing/entropy_testutils.h"
#include "sw/device/lib/testing/otbn_testutils.h"
#include "sw/device/lib/testing/test_framework/check.h"
#include "sw/device/lib/testing/test_framework/ottf_main.h"
#include <string.h>

OTTF_DEFINE_TEST_CONFIG();

OTBN_DECLARE_APP_SYMBOLS(hkdf_sha3_256);
OTBN_DECLARE_SYMBOL_ADDR(hkdf_sha3_256, input_salt);
OTBN_DECLARE_SYMBOL_ADDR(hkdf_sha3_256, ikm_prebuilt);
OTBN_DECLARE_SYMBOL_ADDR(hkdf_sha3_256, input_info);
OTBN_DECLARE_SYMBOL_ADDR(hkdf_sha3_256, input_info_len);
OTBN_DECLARE_SYMBOL_ADDR(hkdf_sha3_256, input_lengths);
OTBN_DECLARE_SYMBOL_ADDR(hkdf_sha3_256, output_okm);
static const otbn_app_t kApp = OTBN_APP_T_INIT(hkdf_sha3_256);

static const uint8_t kKatPkE[32] = {
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

  LOG_INFO("Load hkdf_sha3_256...");
  CHECK_STATUS_OK(otbn_testutils_load_app(&otbn, kApp));

  uint8_t salt[32] = {
      0x00,0x01,0x02,0x03,0x04,0x05,0x06,0x07,
      0x08,0x09,0x0a,0x0b,0x0c,0x0d,0x0e,0x0f,
      0x10,0x11,0x12,0x13,0x14,0x15,0x16,0x17,
      0x18,0x19,0x1a,0x1b,0x1c,0x1d,0x1e,0x1f,
  };
  CHECK_STATUS_OK(otbn_testutils_write_data(&otbn, 32, salt,
      OTBN_ADDR_T_INIT(hkdf_sha3_256, input_salt)));

  /* Non-zero ctx (32B), sid (32B), info (16B) */
  static const uint8_t kCtx[32] = {
      0x48, 0x79, 0x62, 0x72, 0x69, 0x64, 0x4b, 0x45,
      0x4d, 0x2d, 0x76, 0x31, 0x2d, 0x63, 0x6f, 0x6e,
      0x74, 0x65, 0x78, 0x74, 0x2d, 0x30, 0x31, 0x32,
      0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x41,
  };
  static const uint8_t kSid[32] = {
      0x53, 0x65, 0x73, 0x73, 0x69, 0x6f, 0x6e, 0x2d,
      0x30, 0x34, 0x32, 0x2d, 0x72, 0x75, 0x6e, 0x2d,
      0x58, 0x59, 0x5a, 0x39, 0x38, 0x37, 0x36, 0x35,
      0x34, 0x33, 0x32, 0x31, 0x30, 0x66, 0x65, 0x64,
  };
  static const uint8_t kInfo[16] = {
      0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
      0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x10,
  };
  static const uint8_t kExpectedOkm[32] = {
      0x37, 0x4d, 0x4e, 0xa1, 0x3e, 0x7d, 0xed, 0x72,
      0xfe, 0x6c, 0x65, 0xbc, 0x0e, 0x10, 0xaa, 0x76,
      0x03, 0x91, 0x1f, 0x05, 0x50, 0x58, 0x30, 0x79,
      0x8d, 0x81, 0x77, 0xbf, 0xc5, 0x59, 0xa1, 0x49,
  };

  /* Build IKM: len_cls(2B)||ss_e(32B)||len_pqc(2B)||ss_m(32B)||ctx||sid */
  uint8_t ikm[256] = {0};
  size_t off = 0;
  ikm[off++] = 0x00; ikm[off++] = 0x20;
  memcpy(ikm + off, kKatPkE, 32); off += 32;
  ikm[off++] = 0x00; ikm[off++] = 0x20;
  memcpy(ikm + off, kKatSsM, 32); off += 32;
  memcpy(ikm + off, kCtx, sizeof(kCtx)); off += sizeof(kCtx);
  memcpy(ikm + off, kSid, sizeof(kSid)); off += sizeof(kSid);
  size_t ikm_len = off;

  CHECK_STATUS_OK(otbn_testutils_write_data(&otbn, sizeof(kInfo),
      kInfo, OTBN_ADDR_T_INIT(hkdf_sha3_256, input_info)));

  /* Write info_len separately from IKM input_lengths */
  uint32_t info_len = sizeof(kInfo);
  CHECK_STATUS_OK(otbn_testutils_write_data(&otbn, 4, &info_len,
      OTBN_ADDR_T_INIT(hkdf_sha3_256, input_info_len)));

  /* input_lengths: IKM-related only (ctx, sid, okm). info NOT here. */
  uint32_t lens[3] = {
      sizeof(kCtx), sizeof(kSid), sizeof(kExpectedOkm),
  };
  CHECK_STATUS_OK(otbn_testutils_write_data(&otbn, ikm_len, ikm,
      OTBN_ADDR_T_INIT(hkdf_sha3_256, ikm_prebuilt)));
  CHECK_STATUS_OK(otbn_testutils_write_data(&otbn, sizeof(lens), lens,
      OTBN_ADDR_T_INIT(hkdf_sha3_256, input_lengths)));

  LOG_INFO("Execute...");
  CHECK_STATUS_OK(otbn_testutils_execute(&otbn));
  CHECK_STATUS_OK(otbn_testutils_wait_for_done(&otbn, kDifOtbnErrBitsNoError));

  static uint8_t okm[32];
  CHECK_STATUS_OK(otbn_testutils_read_data(&otbn, sizeof(okm),
      OTBN_ADDR_T_INIT(hkdf_sha3_256, output_okm), okm));

  CHECK_ARRAYS_EQ(okm, kExpectedOkm, sizeof(kExpectedOkm));

  return true;
}
