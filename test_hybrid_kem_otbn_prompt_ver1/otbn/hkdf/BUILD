load("//rules:otbn.bzl", "otbn_binary", "otbn_library")

package(default_visibility = ["//visibility:public"])

otbn_library(name = "hkdf_sha3_256_lib", srcs = ["hkdf_sha3_256.s"])
otbn_library(name = "hmac_sha3_lib",     srcs = ["hmac_sha3.s"])
otbn_library(name = "kmac_sha3_lib",     srcs = ["kmac_sha3_template.s"])

otbn_binary(
    name = "sha3_test_bin",
    srcs = [
        "kmac_sha3_template.s",
        "//test_hybrid_kem_otbn_prompt_ver1/otbn/test:sha3_test.s",
    ],
)

otbn_binary(
    name = "hmac_sha3_256",
    srcs = [
        "hmac_sha3.s", "kmac_sha3_template.s",
        "//test_hybrid_kem_otbn_prompt_ver1/otbn/test:hmac_test.s",
    ],
)

otbn_binary(
    name = "hkdf_sha3_256",
    srcs = [
        "//test_hybrid_kem_otbn_prompt_ver1/otbn/test:hkdf_test.s",
        "hkdf_sha3_256.s", "hmac_sha3.s", "kmac_sha3_template.s",
    ],
)
