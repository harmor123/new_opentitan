load("//rules:otbn.bzl", "otbn_binary", "otbn_library")

package(default_visibility = ["//visibility:public"])

otbn_library(
    name = "p256_base_lib",
    srcs = ["p256_base.s"],
)

otbn_library(
    name = "p256_isoncurve_proj_lib",
    srcs = ["p256_isoncurve_proj.s"],
)

otbn_library(
    name = "p256_shared_key_lib",
    srcs = ["p256_shared_key.s"],
)

otbn_library(
    name = "p256_keygen_lib",
    srcs = ["p256_keygen.s"],
)

otbn_binary(
    name = "p256_ecdh_shared_key",
    srcs = [
        "//test_hybrid_kem_otbn_prompt_ver0_1/otbn/test:p256_ecdh_shared_key_test.s",
        "p256_base.s",
        "p256_isoncurve_proj.s",
        "p256_shared_key.s",
    ],
)

otbn_binary(
    name = "p256_keygen",
    srcs = [
        "//test_hybrid_kem_otbn_prompt_ver0_1/otbn/test:p256_keygen_test.s",
        "p256_base.s",
        "p256_isoncurve_proj.s",
        "p256_keygen.s",
    ],
)
