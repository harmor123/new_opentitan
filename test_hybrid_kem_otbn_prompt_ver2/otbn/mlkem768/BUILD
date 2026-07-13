load("//rules:otbn.bzl", "otbn_binary", "otbn_library")

package(default_visibility = ["//visibility:public"])

otbn_library(name = "basemul",     srcs = ["basemul.s"],          copts = ["--bnmulv_version_id=2"])
otbn_library(name = "cbd",         srcs = ["cbd.s"],              copts = ["--bnmulv_version_id=2"])
otbn_library(name = "ntt",         srcs = ["ntt.s"],              copts = ["--bnmulv_version_id=2"])
otbn_library(name = "intt",        srcs = ["intt.s"],             copts = ["--bnmulv_version_id=2"])
otbn_library(name = "poly",        srcs = ["poly.s"],             copts = ["--bnmulv_version_id=2"])
otbn_library(name = "poly_gen_matrix", srcs = ["poly_gen_matrix.s"], copts = ["--bnmulv_version_id=2"])
otbn_library(name = "pack_keys",   srcs = ["pack_keys.s"],        copts = ["--bnmulv_version_id=2"])
otbn_library(name = "pack_ciphertext", srcs = ["pack_ciphertext.s"], copts = ["--bnmulv_version_id=2"])
otbn_library(name = "kmac_sha3",   srcs = ["kmac_sha3_template.s"])
otbn_library(name = "mlkem_keypair_s", srcs = ["mlkem_keypair.s"], copts = ["--bnmulv_version_id=2"])
otbn_library(name = "mlkem_encap_s",  srcs = ["mlkem_encap.s"],   copts = ["--bnmulv_version_id=2"])
otbn_library(name = "mlkem_decap_s",  srcs = ["mlkem_decap.s"],   copts = ["--bnmulv_version_id=2"])

otbn_binary(
    name = "mlkem768_keypair",
    srcs = [
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/test:mlkem_base_keypair_test.s",
        "mlkem_keypair.s", "basemul.s", "cbd.s", "ntt.s",
        "pack_keys.s", "poly.s", "poly_gen_matrix.s", "kmac_sha3_template.s",
    ],
    args = ["--bnmulv_version_id=2"],
)

otbn_binary(
    name = "mlkem768_encap",
    srcs = [
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/test:mlkem_base_encap_test.s",
        "mlkem_encap.s", "pack_ciphertext.s", "basemul.s", "cbd.s",
        "intt.s", "ntt.s", "pack_keys.s", "poly.s",
        "poly_gen_matrix.s", "kmac_sha3_template.s",
    ],
    args = ["--bnmulv_version_id=2"],
)

otbn_binary(
    name = "mlkem768_decap",
    srcs = [
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/test:mlkem_base_decap_test.s",
        "mlkem_decap.s", "mlkem_encap.s", "pack_ciphertext.s", "basemul.s",
        "cbd.s", "intt.s", "ntt.s", "pack_keys.s", "poly.s",
        "poly_gen_matrix.s", "kmac_sha3_template.s",
    ],
    args = ["--bnmulv_version_id=2"],
)
