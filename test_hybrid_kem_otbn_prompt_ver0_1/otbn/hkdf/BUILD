load("//rules:otbn.bzl", "otbn_binary", "otbn_library")

package(default_visibility = ["//visibility:public"])

# Pure software HKDF-SHA3-256 (no KMAC hardware)
otbn_library(name = "hkdf_sha3_256_lib", srcs = ["hkdf_sha3_256.s"])
otbn_library(name = "hmac_sha3_lib",     srcs = ["hmac.s"])
otbn_library(name = "sha3_shake_lib",     srcs = ["sha3_shake.s"])
otbn_binary(
    name = "hkdf_sha3_256",
    srcs = [
        "//test_hybrid_kem_otbn_prompt_ver0_1/otbn/test:hkdf_test.s",
        "hkdf_sha3_256.s", "hmac.s", "sha3_shake.s",
    ],
)

otbn_binary(
    name = "hmac_sha3_256",
    srcs = [
        "//test_hybrid_kem_otbn_prompt_ver0_1/otbn/test:hmac_test.s",
        "hmac.s", "sha3_shake.s",
    ],
)

otbn_binary(
    name = "sha3_shake",
    srcs = [
        "//test_hybrid_kem_otbn_prompt_ver0_1/otbn/test:sha3_shake_test.s",
        "sha3_shake.s",
    ],
)
