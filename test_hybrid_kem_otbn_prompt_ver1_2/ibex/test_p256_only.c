/**
 * @file test_p256_only.c
 * @brief Standalone test for the upstream OpenTitan P-256 ECDH implementation.
 */

#include "sw/device/lib/base/hardened_memory.h"
#include "sw/device/lib/crypto/drivers/otbn.h"
#include "sw/device/lib/crypto/impl/keyblob.h"
#include "sw/device/lib/crypto/include/config.h"
#include "sw/device/lib/crypto/include/ecc_p256.h"
#include "sw/device/lib/crypto/include/entropy_src.h"
#include "sw/device/lib/crypto/include/key_transport.h"
#include "sw/device/lib/runtime/log.h"
#include "sw/device/lib/testing/profile.h"
#include "sw/device/lib/testing/test_framework/check.h"
#include "sw/device/lib/testing/test_framework/ottf_main.h"
#include "sw/device/lib/crypto/include/integrity.h"

OTTF_DEFINE_TEST_CONFIG();

enum {
  /* P-256 public key = x coordinate + y coordinate = 512 bits. */
  kP256PublicKeyWords = 512 / 32,

  /* P-256 private scalar length. */
  kP256PrivateKeyBytes = 256 / 8,

  /* P-256 ECDH shared secret length. */
  kP256SharedKeyBytes = 256 / 8,
  kP256SharedKeyWords = kP256SharedKeyBytes / sizeof(uint32_t),
};

/*
 * Configuration for a software-backed P-256 ECDH private key.
 *
 * The actual keyblob contains two masked shares and is therefore larger
 * than the 32-byte unmasked private scalar.
 */
static const otcrypto_key_config_t kEcdhPrivateKeyConfig = {
    .version = kOtcryptoLibVersion1,
    .key_mode = kOtcryptoKeyModeEcdhP256,
    .key_length = kP256PrivateKeyBytes,
    .hw_backed = kHardenedBoolFalse,
    .exportable = kHardenedBoolFalse,
    .security_level = kOtcryptoKeySecurityLevelLow,
};

/*
 * Configuration used to hold the masked ECDH shared secret.
 *
 * AES-CTR is used here only as the symmetric-key container mode, matching
 * the upstream OpenTitan functional test. This test does not perform AES.
 */
static const otcrypto_key_config_t kEcdhSharedKeyConfig = {
    .version = kOtcryptoLibVersion1,
    .key_mode = kOtcryptoKeyModeAesCtr,
    .key_length = kP256SharedKeyBytes,
    .hw_backed = kHardenedBoolFalse,
    .exportable = kHardenedBoolTrue,
    .security_level = kOtcryptoKeySecurityLevelLow,
};

static status_t run_p256_ecdh_test(void) {
  /*
   * Allocate blinded private-key storage.
   *
   * keyblob_num_words() calculates the correct storage size for the two
   * masked P-256 private-key shares.
   */
  uint32_t private_keyblob_a[
      keyblob_num_words(kEcdhPrivateKeyConfig)];
  uint32_t private_keyblob_b[
      keyblob_num_words(kEcdhPrivateKeyConfig)];

  otcrypto_blinded_key_t private_key_a = {
      .config = kEcdhPrivateKeyConfig,
      .keyblob_length = sizeof(private_keyblob_a),
      .keyblob = private_keyblob_a,
      .checksum = 0,
  };

  otcrypto_blinded_key_t private_key_b = {
      .config = kEcdhPrivateKeyConfig,
      .keyblob_length = sizeof(private_keyblob_b),
      .keyblob = private_keyblob_b,
      .checksum = 0,
  };

  /* Each public key contains 32-byte x and y coordinates. */
  uint32_t public_key_data_a[kP256PublicKeyWords] = {0};
  uint32_t public_key_data_b[kP256PublicKeyWords] = {0};

  otcrypto_unblinded_key_t public_key_a = {
      .key_mode = kOtcryptoKeyModeEcdhP256,
      .key_length = sizeof(public_key_data_a),
      .key = public_key_data_a,
  };

  otcrypto_unblinded_key_t public_key_b = {
      .key_mode = kOtcryptoKeyModeEcdhP256,
      .key_length = sizeof(public_key_data_b),
      .key = public_key_data_b,
  };

  uint64_t t_start = profile_start();
  LOG_INFO("Generating P-256 keypair A...");
  TRY(otcrypto_ecdh_p256_keygen(&private_key_a, &public_key_a));
  uint32_t keygen_a_cycles = profile_end(t_start);
  LOG_INFO("Keygen A OTBN instruction count: 0x%08x, cycles: %u",
           otbn_instruction_count_get(), keygen_a_cycles);

  t_start = profile_start();
  LOG_INFO("Generating P-256 keypair B...");
  TRY(otcrypto_ecdh_p256_keygen(&private_key_b, &public_key_b));
  uint32_t keygen_b_cycles = profile_end(t_start);
  LOG_INFO("Keygen B OTBN instruction count: 0x%08x, cycles: %u",
           otbn_instruction_count_get(), keygen_b_cycles);

  /* Randomly generated public keys should not be identical. */
  CHECK_ARRAYS_NE(public_key_data_a, public_key_data_b,
                  ARRAYSIZE(public_key_data_a));

  /*
   * The shared secret is returned as two masked shares, so allocate
   * twice the unmasked shared-secret length.
   */
  uint32_t shared_keyblob_a[kP256SharedKeyWords * 2] = {0};
  uint32_t shared_keyblob_b[kP256SharedKeyWords * 2] = {0};

  otcrypto_blinded_key_t shared_key_a = {
      .config = kEcdhSharedKeyConfig,
      .keyblob_length = sizeof(shared_keyblob_a),
      .keyblob = shared_keyblob_a,
      .checksum = 0,
  };

  otcrypto_blinded_key_t shared_key_b = {
      .config = kEcdhSharedKeyConfig,
      .keyblob_length = sizeof(shared_keyblob_b),
      .keyblob = shared_keyblob_b,
      .checksum = 0,
  };

  t_start = profile_start();
  LOG_INFO("Computing shared secret from side A...");
  TRY(otcrypto_ecdh_p256(
      &private_key_a, &public_key_b, &shared_key_a));
  uint32_t ecdh_a_cycles = profile_end(t_start);
  LOG_INFO("ECDH A OTBN instruction count: 0x%08x, cycles: %u",
           otbn_instruction_count_get(), ecdh_a_cycles);

  t_start = profile_start();
  LOG_INFO("Computing shared secret from side B...");
  TRY(otcrypto_ecdh_p256(
      &private_key_b, &public_key_a, &shared_key_b));
  uint32_t ecdh_b_cycles = profile_end(t_start);
  LOG_INFO("ECDH B OTBN instruction count: 0x%08x, cycles: %u",
           otbn_instruction_count_get(), ecdh_b_cycles);

  /*
   * Export both shares of each shared secret.
   */
  uint32_t key_a_share0[kP256SharedKeyWords];
  uint32_t key_a_share1[kP256SharedKeyWords];
  uint32_t key_b_share0[kP256SharedKeyWords];
  uint32_t key_b_share1[kP256SharedKeyWords];

  otcrypto_word32_buf_t key_a_share0_buf = OTCRYPTO_MAKE_BUF(
      otcrypto_word32_buf_t,
      key_a_share0,
      ARRAYSIZE(key_a_share0));

  otcrypto_word32_buf_t key_a_share1_buf = OTCRYPTO_MAKE_BUF(
      otcrypto_word32_buf_t,
      key_a_share1,
      ARRAYSIZE(key_a_share1));

  otcrypto_word32_buf_t key_b_share0_buf = OTCRYPTO_MAKE_BUF(
      otcrypto_word32_buf_t,
      key_b_share0,
      ARRAYSIZE(key_b_share0));

  otcrypto_word32_buf_t key_b_share1_buf = OTCRYPTO_MAKE_BUF(
      otcrypto_word32_buf_t,
      key_b_share1,
      ARRAYSIZE(key_b_share1));

  TRY(otcrypto_export_blinded_key(
      &shared_key_a, &key_a_share0_buf, &key_a_share1_buf));

  TRY(otcrypto_export_blinded_key(
      &shared_key_b, &key_b_share0_buf, &key_b_share1_buf));

  /*
   * Unmask each shared secret:
   *
   * raw_key = share0 XOR share1
   */
  uint32_t raw_shared_key_a[kP256SharedKeyWords];
  uint32_t raw_shared_key_b[kP256SharedKeyWords];

  TRY(hardened_xor(
      key_a_share0,
      key_a_share1,
      kP256SharedKeyWords,
      raw_shared_key_a));

  TRY(hardened_xor(
      key_b_share0,
      key_b_share1,
      kP256SharedKeyWords,
      raw_shared_key_b));

  CHECK_ARRAYS_EQ(
      raw_shared_key_a,
      raw_shared_key_b,
      ARRAYSIZE(raw_shared_key_a));

  LOG_INFO("Upstream P-256 ECDH test passed.");
  return OTCRYPTO_OK;
}

bool test_main(void) {
  CHECK_STATUS_OK(otcrypto_init(kOtcryptoKeySecurityLevelLow));
  CHECK_STATUS_OK(run_p256_ecdh_test());
  return true;
}