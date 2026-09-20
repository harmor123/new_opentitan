/**
 * @file test_hkdf_only.c
 * @brief Standalone HKDF-HMAC-SHA3-256 OTBN correctness test (ver1_1).
 *
 * OTBN app 为 ver1 hkdf 结构 + 官方 xof.s 驱动的移植版.
 * Fixed Hybrid-KEM profile (与 phase2 一致, RFC 5869 + RFC 2104):
 *   salt = 32 bytes (0x00..0x1f)
 *   IKM  = be16(32)||ss_e||be16(32)||ss_m||ctx||sid
 *        = 2+32+2+32+32+32 = 132 bytes
 *   info = 16 bytes (0x01..0x10)
 *   OKM  = 32 bytes
 *
 *   PRK  = HMAC-SHA3-256(salt, IKM)
 *   T(1) = HMAC-SHA3-256(PRK, info || 0x01)
 *   OKM  = T(1)   (since L = 32B)
 *
 * 期望向量经 Python hashlib 独立按标准 (FIPS 202 / RFC 2104 B=136 /
 * RFC 5869) 计算验证, 与 ISS hkdf_test (dexp) 同一 profile.
 */

#include "sw/device/lib/dif/dif_otbn.h"
#include "sw/device/lib/runtime/log.h"
#include "sw/device/lib/testing/entropy_testutils.h"
#include "sw/device/lib/testing/otbn_testutils.h"
#include "sw/device/lib/testing/profile.h"
#include "sw/device/lib/testing/test_framework/check.h"
#include "sw/device/lib/testing/test_framework/ottf_main.h"

#include <stdint.h>
#include <string.h>


/* ================================================================
 * OTTF configuration
 * ================================================================ */

OTTF_DEFINE_TEST_CONFIG();


/* ================================================================
 * OTBN application and DMEM symbols
 * ================================================================ */

OTBN_DECLARE_APP_SYMBOLS(hkdf_sha3_256);

OTBN_DECLARE_SYMBOL_ADDR(hkdf_sha3_256, input_salt);
OTBN_DECLARE_SYMBOL_ADDR(hkdf_sha3_256, ikm_prebuilt);
OTBN_DECLARE_SYMBOL_ADDR(hkdf_sha3_256, input_info);
OTBN_DECLARE_SYMBOL_ADDR(hkdf_sha3_256, input_info_len);
OTBN_DECLARE_SYMBOL_ADDR(hkdf_sha3_256, input_lengths);

OTBN_DECLARE_SYMBOL_ADDR(hkdf_sha3_256, hmac_key_hashed);
OTBN_DECLARE_SYMBOL_ADDR(hkdf_sha3_256, output_okm);

static const otbn_app_t kApp =
    OTBN_APP_T_INIT(hkdf_sha3_256);


/* ================================================================
 * Fixed test vectors
 * ================================================================ */

/*
 * Classical shared secret:
 *
 * ss_e = 32B
 */
static const uint8_t kSsE[32] = {
    0x5f, 0x33, 0xd7, 0x46, 0xa3, 0x26, 0x64, 0x0a,
    0x73, 0x9a, 0x94, 0x90, 0xec, 0x15, 0xc1, 0x03,
    0x72, 0x86, 0x9f, 0x3d, 0xe6, 0x75, 0xb2, 0xe8,
    0x57, 0x42, 0x27, 0x1d, 0x18, 0xc9, 0xeb, 0x82,
};


/*
 * ML-KEM shared secret:
 *
 * ss_m = 32B
 */
static const uint8_t kSsM[32] = {
    0x37, 0x50, 0xac, 0x4a, 0x8e, 0x65, 0x63, 0x27,
    0xc3, 0xd1, 0x81, 0xfa, 0xb0, 0x02, 0x55, 0x4b,
    0xf6, 0xd2, 0xbe, 0x04, 0x75, 0xdd, 0x28, 0xd5,
    0xf3, 0x1b, 0xef, 0x9f, 0x83, 0x5f, 0x86, 0xac,
};


/*
 * Fixed HKDF salt:
 *
 * salt = 32B
 */
static const uint8_t kSalt[32] = {
    0x00, 0x01, 0x02, 0x03,
    0x04, 0x05, 0x06, 0x07,
    0x08, 0x09, 0x0a, 0x0b,
    0x0c, 0x0d, 0x0e, 0x0f,

    0x10, 0x11, 0x12, 0x13,
    0x14, 0x15, 0x16, 0x17,
    0x18, 0x19, 0x1a, 0x1b,
    0x1c, 0x1d, 0x1e, 0x1f,
};


/*
 * Fixed 32-byte protocol context:
 *
 * ctx = 32B
 */
static const uint8_t kCtx[32] = {
    0x48, 0x79, 0x62, 0x72,
    0x69, 0x64, 0x4b, 0x45,
    0x4d, 0x2d, 0x76, 0x31,
    0x2d, 0x63, 0x6f, 0x6e,

    0x74, 0x65, 0x78, 0x74,
    0x2d, 0x30, 0x31, 0x32,
    0x33, 0x34, 0x35, 0x36,
    0x37, 0x38, 0x39, 0x41,
};


/*
 * Fixed 32-byte session identifier:
 *
 * sid = 32B
 */
static const uint8_t kSid[32] = {
    0x53, 0x65, 0x73, 0x73,
    0x69, 0x6f, 0x6e, 0x2d,
    0x30, 0x34, 0x32, 0x2d,
    0x72, 0x75, 0x6e, 0x2d,

    0x58, 0x59, 0x5a, 0x39,
    0x38, 0x37, 0x36, 0x35,
    0x34, 0x33, 0x32, 0x31,
    0x30, 0x66, 0x65, 0x64,
};


/* ================================================================
 * Expected PRK (Python hashlib 标准参考验证, 2026-09-04)
 *
 * PRK = HMAC-SHA3-256(
 *     salt,
 *     be16(32)||ss_e||be16(32)||ss_m||ctx||sid
 * )
 * ================================================================ */

static const uint8_t kExpectedPrk[32] = {
    0xda, 0x3c, 0xc7, 0xa7,
    0x81, 0x38, 0xfe, 0xd9,
    0x55, 0xb6, 0x2d, 0xa7,
    0x4b, 0x07, 0x48, 0x03,

    0xd5, 0x0f, 0xf2, 0x7d,
    0x93, 0xdc, 0x9b, 0x28,
    0x4c, 0xfa, 0xfd, 0xf6,
    0xa4, 0x9b, 0x14, 0xae,
};


/* ================================================================
 * Expected OKM (Python hashlib 标准参考验证, 2026-09-04)
 *
 * T(1) = HMAC-SHA3-256(
 *     PRK,
 *     info || 0x01
 * )
 *
 * L = 32B, therefore:
 *
 * OKM = T(1)
 * ================================================================ */

static const uint8_t kExpectedOkm[32] = {
    0x37, 0x4d, 0x4e, 0xa1,
    0x3e, 0x7d, 0xed, 0x72,
    0xfe, 0x6c, 0x65, 0xbc,
    0x0e, 0x10, 0xaa, 0x76,

    0x03, 0x91, 0x1f, 0x05,
    0x50, 0x58, 0x30, 0x79,
    0x8d, 0x81, 0x77, 0xbf,
    0xc5, 0x59, 0xa1, 0x49,
};


/* ================================================================
 * Main test
 * ================================================================ */

bool test_main(void) {

  dif_otbn_t otbn;


  /* --------------------------------------------------------------
   * 1. Initialize OTBN
   * -------------------------------------------------------------- */

  CHECK_DIF_OK(
      dif_otbn_init_from_dt(
          kDtOtbn,
          &otbn
      )
  );


  /* Initialize entropy subsystem.
   *
   * This HKDF implementation itself is deterministic and does not
   * consume randomness, but this follows the existing OTTF/OTBN
   * test setup.
   */
  CHECK_STATUS_OK(
      entropy_testutils_auto_mode_init()
  );


  /* --------------------------------------------------------------
   * 2. Load OTBN application
   * -------------------------------------------------------------- */

  LOG_INFO("Loading HKDF-HMAC-SHA3-256 OTBN app...");

  CHECK_STATUS_OK(
      otbn_testutils_load_app(
          &otbn,
          kApp
      )
  );


  /* --------------------------------------------------------------
   * 3. Build IKM
   *
   * IKM = be16(32) || ss_e || be16(32) || ss_m || ctx || sid
   *
   *       = 2+32+2+32+32+32 = 132B
   * -------------------------------------------------------------- */

  uint8_t ikm[132];

  ikm[0] = 0x00; ikm[1] = 0x20;   /* len_cls = 32 */
  memcpy(&ikm[2], kSsE, sizeof(kSsE));
  ikm[34] = 0x00; ikm[35] = 0x20; /* len_pqc = 32 */
  memcpy(&ikm[36], kSsM, sizeof(kSsM));
  memcpy(&ikm[68], kCtx, sizeof(kCtx));
  memcpy(&ikm[100], kSid, sizeof(kSid));


  /* --------------------------------------------------------------
   * 4. Build HKDF info
   *
   * info = 16B (0x01..0x10, 与 phase2 一致)
   * -------------------------------------------------------------- */

  static const uint8_t kInfo[16] = {
      0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
      0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x10,
  };

  uint8_t info[16];

  memcpy(
      &info[0],
      kInfo,
      sizeof(kInfo)
  );


  /* --------------------------------------------------------------
   * 5. Write salt to OTBN DMEM
   * -------------------------------------------------------------- */

  CHECK_STATUS_OK(
      otbn_testutils_write_data(
          &otbn,
          sizeof(kSalt),
          kSalt,
          OTBN_ADDR_T_INIT(
              hkdf_sha3_256,
              input_salt
          )
      )
  );


  /* --------------------------------------------------------------
   * 6. Write IKM to OTBN DMEM
   * -------------------------------------------------------------- */

  CHECK_STATUS_OK(
      otbn_testutils_write_data(
          &otbn,
          sizeof(ikm),
          ikm,
          OTBN_ADDR_T_INIT(
              hkdf_sha3_256,
              ikm_prebuilt
          )
      )
  );


  /* --------------------------------------------------------------
   * 7. Write info to OTBN DMEM
   * -------------------------------------------------------------- */

  CHECK_STATUS_OK(
      otbn_testutils_write_data(
          &otbn,
          sizeof(info),
          info,
          OTBN_ADDR_T_INIT(
              hkdf_sha3_256,
              input_info
          )
      )
  );


  /* --------------------------------------------------------------
   * 7b. Write info_len and IKM length fields
   *
   * input_lengths: +0=ctx_len, +4=sid_len, +8=okm_len
   * -------------------------------------------------------------- */

  uint32_t info_len = sizeof(info);
  CHECK_STATUS_OK(
      otbn_testutils_write_data(
          &otbn,
          4,
          &info_len,
          OTBN_ADDR_T_INIT(
              hkdf_sha3_256,
              input_info_len
          )
      )
  );

  uint32_t lens[3] = {
      sizeof(kCtx), sizeof(kSid), sizeof(kExpectedOkm),
  };
  CHECK_STATUS_OK(
      otbn_testutils_write_data(
          &otbn,
          sizeof(lens),
          lens,
          OTBN_ADDR_T_INIT(
              hkdf_sha3_256,
              input_lengths
          )
      )
  );


  /* --------------------------------------------------------------
   * 8. Execute OTBN application
   *
   * OTBN _start:
   *
   *   hkdf_extract()
   *        ↓
   *      PRK
   *
   *   hkdf_expand()
   *        ↓
   *      OKM
   *
   *   ecall
   *
   * -------------------------------------------------------------- */

  LOG_INFO("Executing HKDF-HMAC-SHA3-256...");

  uint64_t t_start = profile_start();

  CHECK_STATUS_OK(
      otbn_testutils_execute(
          &otbn
      )
  );


  /* --------------------------------------------------------------
   * 9. Wait for OTBN completion
   * -------------------------------------------------------------- */

  CHECK_STATUS_OK(
      otbn_testutils_wait_for_done(
          &otbn,
          kDifOtbnErrBitsNoError
      )
  );
  /* ================================================================
    * Profiling: total OTBN instruction count
    * ================================================================ */

    uint32_t hkdf_cycles = profile_end(t_start);

    uint32_t hkdf_insn_cnt = 0;

    CHECK_DIF_OK(
        dif_otbn_get_insn_cnt(
            &otbn,
            &hkdf_insn_cnt
        )
    );
    LOG_INFO(
        "HKDF cycles = %u, total OTBN instructions = %u",
        hkdf_cycles,
        hkdf_insn_cnt
    );

  /* --------------------------------------------------------------
   * 10. Read PRK
   *
   * hmac_key_hashed is used by our fixed HKDF implementation
   * as the PRK buffer.
   * -------------------------------------------------------------- */

  uint8_t prk[32];

  CHECK_STATUS_OK(
      otbn_testutils_read_data(
          &otbn,
          sizeof(prk),
          OTBN_ADDR_T_INIT(
              hkdf_sha3_256,
              hmac_key_hashed
          ),
          prk
      )
  );


  /* --------------------------------------------------------------
   * 11. Read final OKM
   * -------------------------------------------------------------- */

  uint8_t okm[32];

  CHECK_STATUS_OK(
      otbn_testutils_read_data(
          &otbn,
          sizeof(okm),
          OTBN_ADDR_T_INIT(
              hkdf_sha3_256,
              output_okm
          ),
          okm
      )
  );


  /* --------------------------------------------------------------
   * 12. Verify Extract result
   *
   * If this fails:
   *
   *   investigate HKDF-Extract / HMAC / SHA3 first.
   * -------------------------------------------------------------- */

  CHECK_ARRAYS_EQ(
      prk,
      kExpectedPrk,
      sizeof(kExpectedPrk)
  );

  LOG_INFO("HKDF-Extract PRK OK.");


  /* --------------------------------------------------------------
   * 13. Verify Expand result
   *
   * If PRK passes but this fails:
   *
   *   investigate:
   *
   *   info construction
   *   info || 0x01
   *   HKDF-Expand
   * -------------------------------------------------------------- */

  CHECK_ARRAYS_EQ(
      okm,
      kExpectedOkm,
      sizeof(kExpectedOkm)
  );

  LOG_INFO("HKDF-Expand OKM OK.");


  /* --------------------------------------------------------------
   * 14. Final success
   * -------------------------------------------------------------- */

  LOG_INFO(
      "HKDF-HMAC-SHA3-256 standalone correctness PASS."
  );

  return true;
}