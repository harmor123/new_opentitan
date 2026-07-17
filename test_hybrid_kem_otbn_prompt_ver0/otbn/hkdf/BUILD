load("//rules:otbn.bzl", "otbn_binary", "otbn_library")

package(default_visibility = ["//visibility:public"])

# Software SHA3/SHAKE implementation (Keccak-f permutation)
otbn_library(name = "sha3_shake_lib", srcs = ["sha3_shake.s"])

# Software KMAC-KDF (NIST SP 800-108r1), uses sha3_shake.s primitives
otbn_library(name = "kmac_kdf_lib",     srcs = ["kmac_kdf.s"])

# ---- binaries ----

# SHA3 / SHAKE test binary
otbn_binary(
    name = "sha3_test",
    srcs = [
        "sha3_shake.s",
        "//test_hybrid_kem_otbn_prompt_ver0/otbn/test:sha3_test.s",
    ],
)

# KMAC-KDF test binary
otbn_binary(
    name = "kmac_kdf",
    srcs = [
        "kmac_kdf.s",
        "sha3_shake.s",
        "//test_hybrid_kem_otbn_prompt_ver0/otbn/test:kdf_test.s",
    ],
)
