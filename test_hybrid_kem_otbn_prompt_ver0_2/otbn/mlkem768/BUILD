load("//rules:otbn.bzl", "otbn_binary", "otbn_library")

package(default_visibility = ["//visibility:public"])

# ML-KEM-768（数学同 ver1 Plantard；哈希全部走官方 xof.s 驱动）
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

otbn_binary(
    name = "mlkem768_keypair",
    srcs = [
        "//test_hybrid_kem_otbn_prompt_ver0_2/otbn/test:mlkem_base_keypair_test.s",
        "mlkem_keypair.s", "basemul.s", "cbd.s", "ntt.s",
        "poly.s", "poly_gen_matrix.s", "pack_keys.s",
        "//test_hybrid_kem_otbn_prompt_ver0_2/otbn/kmac_official:xof.s",
    ],
)

otbn_binary(
    name = "mlkem768_encap",
    srcs = [
        "//test_hybrid_kem_otbn_prompt_ver0_2/otbn/test:mlkem_base_encap_test.s",
        "mlkem_encap.s", "basemul.s", "cbd.s", "intt.s", "ntt.s",
        "poly.s", "poly_gen_matrix.s", "pack_keys.s", "pack_ciphertext.s",
        "//test_hybrid_kem_otbn_prompt_ver0_2/otbn/kmac_official:xof.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap",
    srcs = [
        "//test_hybrid_kem_otbn_prompt_ver0_2/otbn/test:mlkem_base_decap_test.s",
        "mlkem_decap.s", "mlkem_encap.s", "basemul.s", "cbd.s",
        "intt.s", "ntt.s", "poly.s", "poly_gen_matrix.s",
        "pack_keys.s", "pack_ciphertext.s",
        "//test_hybrid_kem_otbn_prompt_ver0_2/otbn/kmac_official:xof.s",
    ],
)

# ────────── harness 法剖面目标（算术类 14 对；移植自 ver0_1，2026-09-18）──────────
# 用法：python3 test_perf/harness.py --config test_perf/harness_config.yaml --version ver0_2
# 待补：hash 类 11 对（poly_gen_matrix / hash_h / hash_g / shake_z_ct / noise /
#       sha3_init_update_final / *_rejection / *_stub_overhead）需把调用改成 xof.s 的 KMAC 序列。

otbn_binary(
    name = "mlkem768_keygen_ntt_profiling",
    srcs = [
        "keygen_ntt_profiling.s",
        "keygen_ntt_data.s",
        "ntt.s",
    ],
)

otbn_binary(
    name = "mlkem768_keygen_ntt_control",
    srcs = [
        "keygen_ntt_control.s",
    ],
)

otbn_binary(
    name = "mlkem768_keygen_pack_sk_profiling",
    srcs = [
        "keygen_pack_sk_profiling.s",
        "pack_keys.s",
    ],
)

otbn_binary(
    name = "mlkem768_keygen_pack_sk_control",
    srcs = [
        "keygen_pack_sk_control.s",
    ],
)

otbn_binary(
    name = "mlkem768_keygen_basemul_basemul_acc_profiling",
    srcs = [
        "keygen_basemul_basemul_acc_profiling.s",
        "keygen_basemul_basemul_acc_data.s",
        "basemul.s",
    ],
)

otbn_binary(
    name = "mlkem768_keygen_basemul_basemul_acc_control",
    srcs = [
        "keygen_basemul_basemul_acc_control.s",
    ],
)

otbn_binary(
    name = "mlkem768_keygen_poly_reduce_profiling",
    srcs = [
        "keygen_poly_reduce_profiling.s",
        "keygen_poly_reduce_impl.s",
        "keygen_poly_reduce_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_keygen_poly_reduce_control",
    srcs = [
        "keygen_poly_reduce_control.s",
    ],
)

otbn_binary(
    name = "mlkem768_keygen_poly_add_profiling",
    srcs = [
        "keygen_poly_add_profiling.s",
        "keygen_poly_add_impl.s",
    ],
)

otbn_binary(
    name = "mlkem768_keygen_poly_add_control",
    srcs = [
        "keygen_poly_add_control.s",
    ],
)

otbn_binary(
    name = "mlkem768_keygen_pack_pk_profiling",
    srcs = [
        "keygen_pack_pk_profiling.s",
        "pack_keys.s",
    ],
)

otbn_binary(
    name = "mlkem768_keygen_pack_pk_control",
    srcs = [
        "keygen_pack_pk_control.s",
    ],
)

otbn_binary(
    name = "mlkem768_encap_poly_frommsg_profiling",
    srcs = [
        "encap_poly_frommsg_profiling.s",
        "encap_poly_frommsg_impl.s",
    ],
)

otbn_binary(
    name = "mlkem768_encap_poly_frommsg_control",
    srcs = [
        "encap_poly_frommsg_control.s",
    ],
)

otbn_binary(
    name = "mlkem768_encap_unpack_pk_profiling",
    srcs = [
        "encap_unpack_pk_profiling.s",
        "encap_unpack_pk_impl.s",
    ],
)

otbn_binary(
    name = "mlkem768_encap_unpack_pk_control",
    srcs = [
        "encap_unpack_pk_control.s",
    ],
)

otbn_binary(
    name = "mlkem768_encap_intt_profiling",
    srcs = [
        "encap_intt_profiling.s",
        "encap_intt_data.s",
        "intt.s",
    ],
)

otbn_binary(
    name = "mlkem768_encap_intt_control",
    srcs = [
        "encap_intt_control.s",
        "encap_intt_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_encap_pack_ciphertext_profiling",
    srcs = [
        "encap_pack_ciphertext_profiling.s",
        "encap_pack_ciphertext_data.s",
        "pack_ciphertext.s",
    ],
)

otbn_binary(
    name = "mlkem768_encap_pack_ciphertext_control",
    srcs = [
        "encap_pack_ciphertext_control.s",
        "encap_pack_ciphertext_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_unpack_ciphertext_profiling",
    srcs = [
        "decap_unpack_ciphertext_profiling.s",
        "decap_unpack_ciphertext_data.s",
        "pack_ciphertext.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_unpack_ciphertext_control",
    srcs = [
        "decap_unpack_ciphertext_control.s",
        "decap_unpack_ciphertext_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_poly_sub_profiling",
    srcs = [
        "decap_poly_sub_profiling.s",
        "decap_poly_sub_impl.s",
        "decap_poly_sub_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_poly_sub_control",
    srcs = [
        "decap_poly_sub_control.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_poly_tomsg_profiling",
    srcs = [
        "decap_poly_tomsg_profiling.s",
        "decap_poly_tomsg_impl.s",
        "encap_pack_ciphertext_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_poly_tomsg_control",
    srcs = [
        "decap_poly_tomsg_control.s",
        "encap_pack_ciphertext_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_verify_cmov_profiling",
    srcs = [
        "decap_verify_cmov_profiling.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_verify_cmov_control",
    srcs = [
        "decap_verify_cmov_control.s",
    ],
)

