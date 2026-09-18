load("//rules:otbn.bzl", "otbn_binary", "otbn_library")

package(default_visibility = ["//visibility:public"])

# HKDF-SHA3-256（ver1 结构移植，KMAC 调用换官方 xof.s 驱动）
# 与 ML-KEM 实现无关，ver1_1 自包含（xof.s 取自官方 //sw/otbn/crypto）。
otbn_library(name = "hkdf_sha3_256_lib", srcs = ["hkdf_sha3_256.s"])
otbn_library(name = "hmac_sha3_lib",     srcs = ["hmac_sha3.s"])

otbn_binary(
    name = "hkdf_sha3_256",
    srcs = [
        "//test_hybrid_kem_otbn_prompt_ver1_1/otbn/test:hkdf_test.s",
        "hkdf_sha3_256.s", "hmac_sha3.s",
        "//sw/otbn/crypto:xof.s",
    ],
)
