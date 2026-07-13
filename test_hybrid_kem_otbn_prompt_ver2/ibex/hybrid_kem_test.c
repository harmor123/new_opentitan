/**
 * @file hybrid_kem_test.c
 * @brief Hybrid KEM Ibex test — follows otbn_mlkem_test.c pattern
 *        from "Improving ML-KEM & ML-DSA on OpenTitan" (eprint 2025/2028).
 *
 * Architecture:
 *   1. Run C reference implementation → expected values
 *   2. Run OTBN P-256 keygen → compare with reference
 *   3. Run OTBN ML-KEM keypair → compare with reference
 *   4. Run OTBN ML-KEM encap → compare with reference
 *   5. Run OTBN ML-KEM decap → compare with reference
 *   6. Run OTBN HKDF → compare with reference
 *
 * All OTBN operations inlined in test_main (no helper functions) for
 * Verilator compatibility if needed. Primary target: FPGA.
 */

#include "sw/device/lib/dif/dif_otbn.h"
#include "sw/device/lib/runtime/ibex.h"
#include "sw/device/lib/runtime/log.h"
#include "sw/device/lib/testing/entropy_testutils.h"
#include "sw/device/lib/testing/otbn_testutils.h"
#include "sw/device/lib/testing/test_framework/check.h"
#include "sw/device/lib/testing/test_framework/ottf_main.h"

#include "hw/top_earlgrey/sw/autogen/top_earlgrey.h"
#include "sw/device/lib/base/memory.h"

/* C reference implementation (KAT vectors) */
#include "test_hybrid_kem_paper/ref/hybrid_kem_ref.h"

/* ================================================================
 * OTBN app symbols
 * ================================================================ */

/* p256_ecdh */
OTBN_DECLARE_APP_SYMBOLS(p256_ecdh);
OTBN_DECLARE_SYMBOL_ADDR(p256_ecdh, d0);
OTBN_DECLARE_SYMBOL_ADDR(p256_ecdh, d1);
OTBN_DECLARE_SYMBOL_ADDR(p256_ecdh, x);
OTBN_DECLARE_SYMBOL_ADDR(p256_ecdh, y);
OTBN_DECLARE_SYMBOL_ADDR(p256_ecdh, _checksum);
static const otbn_app_t kAppP256 = OTBN_APP_T_INIT(p256_ecdh);

/* mlkem768_keypair */
OTBN_DECLARE_APP_SYMBOLS(mlkem768_keypair);
OTBN_DECLARE_SYMBOL_ADDR(mlkem768_keypair, coins);
OTBN_DECLARE_SYMBOL_ADDR(mlkem768_keypair, ek);
OTBN_DECLARE_SYMBOL_ADDR(mlkem768_keypair, dk);
static const otbn_app_t kAppMLKEMKeypair = OTBN_APP_T_INIT(mlkem768_keypair);

/* mlkem768_encap */
OTBN_DECLARE_APP_SYMBOLS(mlkem768_encap);
OTBN_DECLARE_SYMBOL_ADDR(mlkem768_encap, coins);
OTBN_DECLARE_SYMBOL_ADDR(mlkem768_encap, ct);
OTBN_DECLARE_SYMBOL_ADDR(mlkem768_encap, ss);
OTBN_DECLARE_SYMBOL_ADDR(mlkem768_encap, ek);
static const otbn_app_t kAppMLKEMEncap = OTBN_APP_T_INIT(mlkem768_encap);

/* mlkem768_decap */
OTBN_DECLARE_APP_SYMBOLS(mlkem768_decap);
OTBN_DECLARE_SYMBOL_ADDR(mlkem768_decap, ct);
OTBN_DECLARE_SYMBOL_ADDR(mlkem768_decap, dk);
OTBN_DECLARE_SYMBOL_ADDR(mlkem768_decap, ss);
static const otbn_app_t kAppMLKEMDecap = OTBN_APP_T_INIT(mlkem768_decap);

/* hkdf_sha3_256 */
OTBN_DECLARE_APP_SYMBOLS(hkdf_sha3_256);
OTBN_DECLARE_SYMBOL_ADDR(hkdf_sha3_256, input_salt);
OTBN_DECLARE_SYMBOL_ADDR(hkdf_sha3_256, ikm_prebuilt);
OTBN_DECLARE_SYMBOL_ADDR(hkdf_sha3_256, input_lengths);
OTBN_DECLARE_SYMBOL_ADDR(hkdf_sha3_256, output_okm);
OTBN_DECLARE_SYMBOL_ADDR(hkdf_sha3_256, _checksum);
static const otbn_app_t kAppHkdf = OTBN_APP_T_INIT(hkdf_sha3_256);

OTTF_DEFINE_TEST_CONFIG();

/* ================================================================
 * Hardcoded KAT test vectors (from OTBN ISS simulation)
 * ================================================================ */

/* ML-KEM keypair coins (64 bytes, from kp_test_data.s) */
static const uint8_t kKpCoins[2 * HYBRID_KEM_MLKEM_SYMBYTES] = {
    0x7f,0x9c,0x2b,0xa4,0xe8,0x8f,0x82,0x7d,0x61,0x60,0x45,
    0x50,0x76,0x05,0x85,0x3e,0xd7,0x3b,0x80,0x93,0xf6,0xef,
    0xbc,0x88,0xeb,0x1a,0x6e,0xac,0xfa,0x66,0xef,0x26,0x3c,
    0xb1,0xee,0xa9,0x88,0x00,0x4b,0x93,0x10,0x3c,0xfb,0x0a,
    0xee,0xfd,0x2a,0x68,0x6e,0x01,0xfa,0x4a,0x58,0xe8,0xa3,
    0x63,0x9c,0xa8,0xa1,0xe3,0xf9,0xae,0x57,0xe2,
};

/* ML-KEM encap coins (32 bytes, from enc_test_data.s) */
static const uint8_t kEncapCoins[HYBRID_KEM_MLKEM_SYMBYTES] = {
    0x35,0xb8,0xcc,0x87,0x3c,0x23,0xdc,0x62,0xb8,0xd2,0x60,
    0x16,0x9a,0xfa,0x2f,0x75,0xab,0x91,0x6a,0x58,0xd9,0x74,
    0x91,0x88,0x35,0xd2,0x5e,0x6a,0x43,0x50,0x85,0xb2,
};

/* ================================================================
 * Secure wipe (from otbn_smoketest.c)
 * ================================================================ */
static void test_sec_wipe(dif_otbn_t *otbn) {
  dif_otbn_status_t st;
  CHECK_DIF_OK(dif_otbn_write_cmd(otbn, kDifOtbnCmdSecWipeDmem));
  CHECK_DIF_OK(dif_otbn_get_status(otbn, &st));
  CHECK(st == kDifOtbnStatusBusySecWipeDmem);
  CHECK_STATUS_OK(otbn_testutils_wait_for_done(otbn, kDifOtbnErrBitsNoError));
  CHECK_DIF_OK(dif_otbn_write_cmd(otbn, kDifOtbnCmdSecWipeImem));
  CHECK_DIF_OK(dif_otbn_get_status(otbn, &st));
  CHECK(st == kDifOtbnStatusBusySecWipeImem);
  CHECK_STATUS_OK(otbn_testutils_wait_for_done(otbn, kDifOtbnErrBitsNoError));
}

/* ================================================================
 * test_main — full Hybrid KEM flow, paper pattern
 * ================================================================ */
bool test_main(void) {
  CHECK_STATUS_OK(entropy_testutils_auto_mode_init());

  /* Initialize OTBN — FPGA physical address */
  LOG_INFO("Initialize OTBN");
  dif_otbn_t otbn;
  CHECK_DIF_OK(
      dif_otbn_init(mmio_region_from_addr(TOP_EARLGREY_OTBN_BASE_ADDR), &otbn));

  /* ==============================================================
   * Step 0: Generate reference values
   * ============================================================== */
  LOG_INFO("Generate reference values");

  /* P-256 test vector */
  static const uint8_t kP256D0[64] = {
      0x71,0x10,0x6d,0xfe,0x16,0xa0,0xd0,0x21,0x81,0xc7,0xb2,
      0xb0,0x5d,0xef,0x90,0x95,0x79,0xa3,0xdf,0x3f,0xe8,0xeb,
      0x76,0x1b,0x63,0x02,0x21,0x74,0x41,0xfc,0x20,0x14,
  };
  static const uint8_t kP256Gx[32] = {
      0x34,0xc3,0xa8,0xbf,0xb3,0xb7,0x73,0x97,0x89,0x06,0x6b,
      0xf3,0xb2,0xc0,0xc0,0x6e,0xf3,0x8b,0x6c,0xdb,0x58,0xce,
      0x28,0x16,0x46,0xc5,0xcd,0xfa,0x6a,0x1a,0x55,0xb5,
  };
  static const uint8_t kP256Gy[32] = {
      0x2e,0x8c,0x00,0x9e,0x58,0x70,0x70,0xa8,0x24,0x69,0x9c,
      0xab,0xd0,0x11,0x7a,0x7f,0xfa,0x17,0x3a,0xb5,0xea,0x09,
      0xdd,0x43,0x43,0xc1,0x31,0x1f,0x97,0xc6,0xa1,0x42,
  };

  /* Reference outputs (KAT vectors) */
  uint8_t pk_e_expected[HYBRID_KEM_PK_E_BYTES];
  uint8_t pk_m_expected[HYBRID_KEM_PK_M_BYTES];
  uint8_t sk_m_expected[HYBRID_KEM_SK_M_BYTES];
  uint8_t ct_m_expected[HYBRID_KEM_CT_M_BYTES];
  uint8_t ss_m_expected[HYBRID_KEM_SS_M_BYTES];
  uint8_t okm_expected[32];

  hybrid_kem_reference_keygen(pk_e_expected, pk_m_expected, sk_m_expected,
                              kP256D0, kP256Gx, kP256Gy, kKpCoins);
  hybrid_kem_reference_encap(ct_m_expected, ss_m_expected, okm_expected,
                             pk_m_expected, kEncapCoins);
  LOG_INFO("Reference values loaded");

  /* ==============================================================
   * Step 1: P-256 ECDH KeyGen
   * ============================================================== */
  LOG_INFO("Load P-256 ECDH");
  CHECK_DIF_OK(dif_otbn_clear_load_checksum(&otbn));
  CHECK_STATUS_OK(otbn_testutils_load_app(&otbn, kAppP256));

  uint32_t hw_cs;
  CHECK_DIF_OK(dif_otbn_get_load_checksum(&otbn, &hw_cs));
  CHECK(hw_cs == OTBN_ADDR_T_INIT(p256_ecdh, _checksum),
        "P-256 checksum mismatch hw=0x%08x", hw_cs);

  LOG_INFO("Write P-256 inputs");
  static const uint8_t kP256D1[64] = {0};
  CHECK_STATUS_OK(otbn_testutils_write_data(&otbn, 64, kP256D0,
      OTBN_ADDR_T_INIT(p256_ecdh, d0)));
  CHECK_STATUS_OK(otbn_testutils_write_data(&otbn, 64, kP256D1,
      OTBN_ADDR_T_INIT(p256_ecdh, d1)));
  CHECK_STATUS_OK(otbn_testutils_write_data(&otbn, 32, kP256Gx,
      OTBN_ADDR_T_INIT(p256_ecdh, x)));
  CHECK_STATUS_OK(otbn_testutils_write_data(&otbn, 32, kP256Gy,
      OTBN_ADDR_T_INIT(p256_ecdh, y)));

  LOG_INFO("Run P-256 keygen");
  CHECK_DIF_OK(dif_otbn_set_ctrl_software_errs_fatal(&otbn, true));
  CHECK_STATUS_OK(otbn_testutils_execute(&otbn));
  CHECK(dif_otbn_set_ctrl_software_errs_fatal(&otbn, false) == kDifUnavailable);
  CHECK_STATUS_OK(otbn_testutils_wait_for_done(&otbn, kDifOtbnErrBitsNoError));

  LOG_INFO("Check P-256 keygen");
  uint32_t s0[8], s1[8];
  CHECK_STATUS_OK(otbn_testutils_read_data(&otbn, 32,
      OTBN_ADDR_T_INIT(p256_ecdh, x), s0));
  CHECK_STATUS_OK(otbn_testutils_read_data(&otbn, 32,
      OTBN_ADDR_T_INIT(p256_ecdh, y), s1));
  uint8_t pk_e[HYBRID_KEM_PK_E_BYTES];
  for (int i = 0; i < 8; i++) ((uint32_t *)pk_e)[i] = s0[i] ^ s1[i];
  for (int i = 8; i < 16; i++) ((uint32_t *)pk_e)[i] = 0;
  CHECK_ARRAYS_EQ(pk_e, pk_e_expected, HYBRID_KEM_PK_E_BYTES);

  /* ==============================================================
   * Step 2: ML-KEM-768 Keypair
   * ============================================================== */
  LOG_INFO("Load ML-KEM keypair");
  CHECK_DIF_OK(dif_otbn_clear_load_checksum(&otbn));
  CHECK_STATUS_OK(otbn_testutils_load_app(&otbn, kAppMLKEMKeypair));

  LOG_INFO("Write ML-KEM coins");
  CHECK_STATUS_OK(otbn_testutils_write_data(&otbn, sizeof(kKpCoins),
      kKpCoins, OTBN_ADDR_T_INIT(mlkem768_keypair, coins)));

  LOG_INFO("Run ML-KEM keypair");
  CHECK_DIF_OK(dif_otbn_set_ctrl_software_errs_fatal(&otbn, true));
  CHECK_STATUS_OK(otbn_testutils_execute(&otbn));
  CHECK(dif_otbn_set_ctrl_software_errs_fatal(&otbn, false) == kDifUnavailable);
  CHECK_STATUS_OK(otbn_testutils_wait_for_done(&otbn, kDifOtbnErrBitsNoError));

  LOG_INFO("Retrieve ML-KEM keys");
  uint8_t pk_m[HYBRID_KEM_PK_M_BYTES];
  uint8_t sk_m[HYBRID_KEM_SK_M_BYTES];
  CHECK_STATUS_OK(otbn_testutils_read_data(&otbn, sizeof(pk_m),
      OTBN_ADDR_T_INIT(mlkem768_keypair, ek), pk_m));
  CHECK_STATUS_OK(otbn_testutils_read_data(&otbn, sizeof(sk_m),
      OTBN_ADDR_T_INIT(mlkem768_keypair, dk), sk_m));

  LOG_INFO("Check ML-KEM keys");
  CHECK_ARRAYS_EQ(pk_m, pk_m_expected, HYBRID_KEM_PK_M_BYTES);
  CHECK_ARRAYS_EQ(sk_m, sk_m_expected, HYBRID_KEM_SK_M_BYTES);

  /* ==============================================================
   * Step 3: ML-KEM-768 Encap
   * ============================================================== */
  LOG_INFO("Load ML-KEM encap");
  CHECK_DIF_OK(dif_otbn_clear_load_checksum(&otbn));
  CHECK_STATUS_OK(otbn_testutils_load_app(&otbn, kAppMLKEMEncap));

  LOG_INFO("Write encap inputs");
  CHECK_STATUS_OK(otbn_testutils_write_data(&otbn, sizeof(kEncapCoins),
      kEncapCoins, OTBN_ADDR_T_INIT(mlkem768_encap, coins)));
  CHECK_STATUS_OK(otbn_testutils_write_data(&otbn, sizeof(pk_m_expected),
      pk_m_expected, OTBN_ADDR_T_INIT(mlkem768_encap, ek)));

  LOG_INFO("Run ML-KEM encap");
  CHECK_DIF_OK(dif_otbn_set_ctrl_software_errs_fatal(&otbn, true));
  CHECK_STATUS_OK(otbn_testutils_execute(&otbn));
  CHECK(dif_otbn_set_ctrl_software_errs_fatal(&otbn, false) == kDifUnavailable);
  CHECK_STATUS_OK(otbn_testutils_wait_for_done(&otbn, kDifOtbnErrBitsNoError));

  LOG_INFO("Retrieve encap results");
  uint8_t ct_m[HYBRID_KEM_CT_M_BYTES];
  uint8_t ss_m[HYBRID_KEM_SS_M_BYTES];
  CHECK_STATUS_OK(otbn_testutils_read_data(&otbn, sizeof(ct_m),
      OTBN_ADDR_T_INIT(mlkem768_encap, ct), ct_m));
  CHECK_STATUS_OK(otbn_testutils_read_data(&otbn, sizeof(ss_m),
      OTBN_ADDR_T_INIT(mlkem768_encap, ss), ss_m));

  LOG_INFO("Check encap");
  CHECK_ARRAYS_EQ(ct_m, ct_m_expected, HYBRID_KEM_CT_M_BYTES);
  CHECK_ARRAYS_EQ(ss_m, ss_m_expected, HYBRID_KEM_SS_M_BYTES);

  /* ==============================================================
   * Step 4: ML-KEM-768 Decap
   * ============================================================== */
  LOG_INFO("Load ML-KEM decap");
  CHECK_DIF_OK(dif_otbn_clear_load_checksum(&otbn));
  CHECK_STATUS_OK(otbn_testutils_load_app(&otbn, kAppMLKEMDecap));

  LOG_INFO("Write decap inputs");
  CHECK_STATUS_OK(otbn_testutils_write_data(&otbn, sizeof(ct_m_expected),
      ct_m_expected, OTBN_ADDR_T_INIT(mlkem768_decap, ct)));
  CHECK_STATUS_OK(otbn_testutils_write_data(&otbn, sizeof(sk_m_expected),
      sk_m_expected, OTBN_ADDR_T_INIT(mlkem768_decap, dk)));

  LOG_INFO("Run ML-KEM decap");
  CHECK_DIF_OK(dif_otbn_set_ctrl_software_errs_fatal(&otbn, true));
  CHECK_STATUS_OK(otbn_testutils_execute(&otbn));
  CHECK(dif_otbn_set_ctrl_software_errs_fatal(&otbn, false) == kDifUnavailable);
  CHECK_STATUS_OK(otbn_testutils_wait_for_done(&otbn, kDifOtbnErrBitsNoError));

  LOG_INFO("Retrieve decap results");
  uint8_t ss_m_dec[HYBRID_KEM_SS_M_BYTES];
  CHECK_STATUS_OK(otbn_testutils_read_data(&otbn, sizeof(ss_m_dec),
      OTBN_ADDR_T_INIT(mlkem768_decap, ss), ss_m_dec));

  LOG_INFO("Check decap");
  CHECK_ARRAYS_EQ(ss_m_dec, ss_m_expected, HYBRID_KEM_SS_M_BYTES);

  /* ==============================================================
   * Step 5: HKDF-SHA3-256 — Initiator (Alice)
   * ============================================================== */
  LOG_INFO("Load HKDF (initiator)");
  CHECK_DIF_OK(dif_otbn_clear_load_checksum(&otbn));
  CHECK_STATUS_OK(otbn_testutils_load_app(&otbn, kAppHkdf));

  LOG_INFO("Write HKDF inputs (initiator)");
  uint8_t salt[32] = {0};
  CHECK_STATUS_OK(otbn_testutils_write_data(&otbn, 32, salt,
      OTBN_ADDR_T_INIT(hkdf_sha3_256, input_salt)));
  uint8_t ikm[256] = {0};
  size_t off = 0;
  ikm[off++] = 0x00; ikm[off++] = 0x20;
  memcpy(ikm + off, pk_e, 32); off += 32;
  ikm[off++] = 0x00; ikm[off++] = 0x20;
  memcpy(ikm + off, ss_m, 32); off += 32;
  memcpy(ikm + off, "initiator", 9); off += 9;
  size_t ikm_len = (off + 3) & ~(size_t)3;
  uint32_t lens[4] = {0, 0, 9, 32};
  CHECK_STATUS_OK(otbn_testutils_write_data(&otbn, ikm_len, ikm,
      OTBN_ADDR_T_INIT(hkdf_sha3_256, ikm_prebuilt)));
  CHECK_STATUS_OK(otbn_testutils_write_data(&otbn, sizeof(lens), lens,
      OTBN_ADDR_T_INIT(hkdf_sha3_256, input_lengths)));

  LOG_INFO("Run HKDF initiator");
  CHECK_DIF_OK(dif_otbn_set_ctrl_software_errs_fatal(&otbn, true));
  CHECK_STATUS_OK(otbn_testutils_execute(&otbn));
  CHECK(dif_otbn_set_ctrl_software_errs_fatal(&otbn, false) == kDifUnavailable);
  CHECK_STATUS_OK(otbn_testutils_wait_for_done(&otbn, kDifOtbnErrBitsNoError));

  LOG_INFO("Check HKDF initiator");
  uint8_t okm_enc[32];
  CHECK_STATUS_OK(otbn_testutils_read_data(&otbn, 32,
      OTBN_ADDR_T_INIT(hkdf_sha3_256, output_okm), okm_enc));
  CHECK_ARRAYS_EQ(okm_enc, okm_expected, 32);

  /* ==============================================================
   * Step 6: HKDF-SHA3-256 — Responder (Bob)
   * ============================================================== */
  LOG_INFO("Load HKDF (responder)");
  CHECK_DIF_OK(dif_otbn_clear_load_checksum(&otbn));
  CHECK_STATUS_OK(otbn_testutils_load_app(&otbn, kAppHkdf));

  LOG_INFO("Write HKDF inputs (responder)");
  off = 0;
  memset(ikm, 0, sizeof(ikm));
  ikm[off++] = 0x00; ikm[off++] = 0x20;
  memcpy(ikm + off, pk_e, 32); off += 32;
  ikm[off++] = 0x00; ikm[off++] = 0x20;
  memcpy(ikm + off, ss_m, 32); off += 32;
  memcpy(ikm + off, "responder", 10); off += 10;
  ikm_len = (off + 3) & ~(size_t)3;
  lens[2] = 10;
  CHECK_STATUS_OK(otbn_testutils_write_data(&otbn, ikm_len, ikm,
      OTBN_ADDR_T_INIT(hkdf_sha3_256, ikm_prebuilt)));
  CHECK_STATUS_OK(otbn_testutils_write_data(&otbn, sizeof(lens), lens,
      OTBN_ADDR_T_INIT(hkdf_sha3_256, input_lengths)));

  LOG_INFO("Run HKDF responder");
  CHECK_DIF_OK(dif_otbn_set_ctrl_software_errs_fatal(&otbn, true));
  CHECK_STATUS_OK(otbn_testutils_execute(&otbn));
  CHECK(dif_otbn_set_ctrl_software_errs_fatal(&otbn, false) == kDifUnavailable);
  CHECK_STATUS_OK(otbn_testutils_wait_for_done(&otbn, kDifOtbnErrBitsNoError));

  LOG_INFO("Check HKDF responder");
  uint8_t okm_dec[32];
  uint8_t okm_dec_expected[32];
  hybrid_kem_reference_decap(okm_dec_expected);
  CHECK_STATUS_OK(otbn_testutils_read_data(&otbn, 32,
      OTBN_ADDR_T_INIT(hkdf_sha3_256, output_okm), okm_dec));
  CHECK_ARRAYS_EQ(okm_dec, okm_dec_expected, 32);

  /* Verify role binding: initiator OKM ≠ responder OKM */
  CHECK(memcmp(okm_enc, okm_dec, 32) != 0,
        "FAIL: role binding broken — OKM_enc == OKM_dec!");

  /* ==============================================================
   * Done
   * ============================================================== */
  test_sec_wipe(&otbn);
  LOG_INFO("All checks passed — Hybrid KEM OK");

  return true;
}
