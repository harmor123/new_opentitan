# Copyright 2026 Hybrid KEM Project Authors. All rights reserved.

load("//rules:otbn.bzl", "otbn_binary", "otbn_library")

package(default_visibility = ["//visibility:public"])

# KMAC hardware driver (SHA3-256/512, SHAKE128/256)
otbn_library(
    name = "kmac_xof_lib",
    srcs = ["kmac_xof.s"],
)

# KMAC-KDF (NIST SP 800-108r1), depends on kmac_xof
otbn_library(
    name = "kmac_kdf_lib",
    srcs = ["kmac_kdf.s"],
)

# SHA3 / SHAKE test binary
otbn_binary(
    name = "sha3_test_bin",
    srcs = [
        "kmac_xof.s",
        "//test_hybrid_kem_otbn_prompt_ver1/otbn/test:sha3_test.s",
    ],
)

# KMAC-KDF test binary
otbn_binary(
    name = "kmac_kdf",
    srcs = [
        "kmac_kdf.s",
        "kmac_xof.s",
        "//test_hybrid_kem_otbn_prompt_ver1/otbn/test:kdf_test.s",
    ],
)
