/**
 * @file test_p256_official.c
 * @brief P-256 keygen test using official //sw/otbn/crypto:run_p256 binary.
 *
 * Uses MODE_BASE_POINT_MULT: computes Q = d*G from caller-provided d0_io/d1_io.
 * Verifies public key x,y against expected values with CHECK_ARRAYS_EQ.
 *
 * Follows official otbn_ecdsa_op_irq_test.c pattern:
 *   load -> write inputs -> execute -> wait_for_done -> read back -> CHECK
 */
#include "sw/device/lib/dif/dif_otbn.h"
#include "sw/device/lib/runtime/log.h"
#include "sw/device/lib/testing/entropy_testutils.h"
#include "sw/device/lib/testing/otbn_testutils.h"
#include "sw/device/lib/testing/test_framework/check.h"
#include "sw/device/lib/testing/test_framework/ottf_main.h"

OTTF_DEFINE_TEST_CONFIG();

OTBN_DECLARE_APP_SYMBOLS(run_p256);
OTBN_DECLARE_SYMBOL_ADDR(run_p256, d0_io);
OTBN_DECLARE_SYMBOL_ADDR(run_p256, d1_io);
OTBN_DECLARE_SYMBOL_ADDR(run_p256, x);
OTBN_DECLARE_SYMBOL_ADDR(run_p256, y);
OTBN_DECLARE_SYMBOL_ADDR(run_p256, mode);
OTBN_DECLARE_SYMBOL_ADDR(run_p256, MODE_BASE_POINT_MULT);
static const otbn_app_t kApp = OTBN_APP_T_INIT(run_p256);
static const uint32_t kModeBasePointMult =
    OTBN_ADDR_T_INIT(run_p256, MODE_BASE_POINT_MULT);

/* Private key share d0 (320-bit, upper 64 bits zero). */
static const uint8_t kInputD0[64] = {
    0x71, 0x10, 0x6d, 0xfe, 0x16, 0xa0, 0xd0, 0x21,
    0x81, 0xc7, 0xb2, 0xb0, 0x5d, 0xef, 0x90, 0x95,
    0x79, 0xa3, 0xdf, 0x3f, 0xe8, 0xeb, 0x76, 0x1b,
    0x63, 0x02, 0x21, 0x74, 0x41, 0xfc, 0x20, 0x14,
};
/* Private key share d1 (all-zero = no masking). */
static const uint8_t kInputD1[64] = {0};

/* Expected public key Q = d*G (LE byte order, matches OTBN DMEM output). */
static const uint8_t kExpectedPkX[32] = {
    0x4a, 0x67, 0xa9, 0x80, 0x56, 0xea, 0x47, 0x11,
    0xdd, 0x87, 0x7d, 0x0c, 0xdd, 0x4e, 0x50, 0x99,
    0xe2, 0x4d, 0x06, 0xbe, 0x3c, 0x84, 0x35, 0x6b,
    0x33, 0x7f, 0xd2, 0x7d, 0xad, 0x15, 0x52, 0x81,
};
static const uint8_t kExpectedPkY[32] = {
    0x84, 0xbc, 0x99, 0x49, 0x4b, 0x64, 0xa8, 0x09,
    0xe8, 0xe3, 0x59, 0xd0, 0xdf, 0xbe, 0xbe, 0xef,
    0xcc, 0x34, 0xe0, 0xe4, 0xfb, 0x02, 0x9f, 0x3d,
    0x9f, 0xff, 0xf4, 0x03, 0xab, 0x26, 0xd0, 0xa6,
};

bool test_main(void) {
  dif_otbn_t otbn;
  CHECK_DIF_OK(dif_otbn_init_from_dt(kDtOtbn, &otbn));
  CHECK_STATUS_OK(entropy_testutils_auto_mode_init());

  LOG_INFO("Load run_p256 (official)...");
  CHECK_STATUS_OK(otbn_testutils_load_app(&otbn, kApp));

  LOG_INFO("Write mode=BASE_POINT_MULT, d0_io, d1_io...");
  CHECK_STATUS_OK(otbn_testutils_write_data(&otbn, 4, &kModeBasePointMult,
      OTBN_ADDR_T_INIT(run_p256, mode)));
  CHECK_STATUS_OK(otbn_testutils_write_data(&otbn, 64, kInputD0,
      OTBN_ADDR_T_INIT(run_p256, d0_io)));
  CHECK_STATUS_OK(otbn_testutils_write_data(&otbn, 64, kInputD1,
      OTBN_ADDR_T_INIT(run_p256, d1_io)));

  LOG_INFO("Execute...");
  CHECK_STATUS_OK(otbn_testutils_execute(&otbn));
  CHECK_STATUS_OK(otbn_testutils_wait_for_done(&otbn, kDifOtbnErrBitsNoError));

  LOG_INFO("Read back public key...");
  uint8_t pk_x[32] = {0};
  uint8_t pk_y[32] = {0};
  CHECK_STATUS_OK(otbn_testutils_read_data(&otbn, 32,
      OTBN_ADDR_T_INIT(run_p256, x), pk_x));
  CHECK_STATUS_OK(otbn_testutils_read_data(&otbn, 32,
      OTBN_ADDR_T_INIT(run_p256, y), pk_y));

  CHECK_ARRAYS_EQ(pk_x, kExpectedPkX, sizeof(kExpectedPkX));
  CHECK_ARRAYS_EQ(pk_y, kExpectedPkY, sizeof(kExpectedPkY));

  return true;
}
