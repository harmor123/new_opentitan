load("//rules:otbn.bzl", "otbn_binary", "otbn_library")

package(default_visibility = ["//visibility:public"])

# ML-KEM-768 with KMAC SHA3 (no BNMULV)
# Library targets for ISS tests
otbn_library(name = "mlkem_keypair",  srcs = ["mlkem_keypair.s"])
otbn_library(name = "mlkem_encap",    srcs = ["mlkem_encap.s"])
otbn_library(name = "mlkem_decap",    srcs = ["mlkem_decap.s"])
otbn_library(name = "basemul",        srcs = ["basemul.s"])
otbn_library(name = "cbd",            srcs = ["cbd.s"])
otbn_library(name = "intt",           srcs = ["intt.s"])
otbn_library(name = "ntt",            srcs = ["ntt.s"])
otbn_library(name = "pack_keys",      srcs = ["pack_keys.s"])
otbn_library(name = "pack_ciphertext",srcs = ["pack_ciphertext.s"])
otbn_library(name = "poly",           srcs = ["poly.s"])
otbn_library(name = "poly_gen_matrix",srcs = ["poly_gen_matrix.s"])
otbn_library(name = "kmac_xof",      srcs = ["kmac_xof.s"])

otbn_binary(
    name = "mlkem768_keypair",
    srcs = [
        "//test_hybrid_kem_otbn_prompt_ver1/otbn/test:mlkem_base_keypair_test.s",
        "mlkem_keypair.s", "basemul.s", "cbd.s", "intt.s", "ntt.s",
        "poly.s", "poly_gen_matrix.s", "pack_keys.s", "kmac_xof.s",
    ],
)

otbn_binary(
    name = "mlkem768_encap",
    srcs = [
        "//test_hybrid_kem_otbn_prompt_ver1/otbn/test:mlkem_base_encap_test.s",
        "mlkem_encap.s", "basemul.s", "cbd.s", "intt.s", "ntt.s",
        "poly.s", "poly_gen_matrix.s", "pack_keys.s", "pack_ciphertext.s",
        "kmac_xof.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap",
    srcs = [
        "//test_hybrid_kem_otbn_prompt_ver1/otbn/test:mlkem_base_decap_test.s",
        "mlkem_decap.s", "mlkem_encap.s", "basemul.s", "cbd.s",
        "intt.s", "ntt.s", "poly.s", "poly_gen_matrix.s",
        "pack_keys.s", "pack_ciphertext.s", "kmac_xof.s",
    ],
)
