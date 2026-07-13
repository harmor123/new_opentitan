load("//rules:otbn.bzl", "otbn_binary", "otbn_library")

package(default_visibility = ["//visibility:public"])

otbn_library(
    name = "p256_base_lib",
    srcs = ["p256_base.s"],
    copts = ["--bnmulv_version_id=2"],
)

otbn_library(
    name = "p256_isoncurve_proj_lib",
    srcs = ["p256_isoncurve_proj.s"],
    copts = ["--bnmulv_version_id=2"],
)

otbn_library(
    name = "p256_shared_key_lib",
    srcs = ["p256_shared_key.s"],
    copts = ["--bnmulv_version_id=2"],
)

otbn_binary(
    name = "p256_ecdh_shared_key",
    srcs = [
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/test:p256_ecdh_shared_key_test.s",
        "p256_base.s",
        "p256_isoncurve_proj.s",
        "p256_shared_key.s",
    ],
    copts = ["--bnmulv_version_id=2"],
)
