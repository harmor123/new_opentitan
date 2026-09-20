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


# ── hash 类 harness（KMAC 路径）—— 2026-09-18 起逐个移植 ──
otbn_binary(
    name = "mlkem768_keygen_hash_h_profiling",
    srcs = [
        "keygen_hash_h_profiling.s",
        "//test_hybrid_kem_otbn_prompt_ver0_2/otbn/kmac_official:xof.s",
    ],
)

otbn_binary(
    name = "mlkem768_keygen_hash_h_control",
    srcs = [
        "keygen_hash_h_control.s",
    ],
)


# ── hash 类 harness（KMAC 路径）续：4 对复用 + 3 对重写 ──
otbn_binary(
    name = "mlkem768_keygen_sha3_init_update_final_profiling",
    srcs = [
        "keygen_sha3_init_update_final_profiling.s",
        "//test_hybrid_kem_otbn_prompt_ver0_2/otbn/kmac_official:xof.s",
    ],
)

otbn_binary(
    name = "mlkem768_keygen_sha3_init_update_final_control",
    srcs = [
        "keygen_sha3_init_update_final_control.s",
    ],
)

otbn_binary(
    name = "mlkem768_keygen_poly_getnoise_eta_1_profiling",
    srcs = [
        "keygen_poly_getnoise_eta_1_profiling.s",
        "keygen_poly_getnoise_eta_1_data.s",
        "poly.s",
        "cbd.s",
        "//test_hybrid_kem_otbn_prompt_ver0_2/otbn/kmac_official:xof.s",
    ],
)

otbn_binary(
    name = "mlkem768_keygen_poly_getnoise_eta_1_control",
    srcs = [
        "keygen_poly_getnoise_eta_1_control.s",
    ],
)

otbn_binary(
    name = "mlkem768_keygen_poly_gen_matrix_profiling",
    srcs = [
        "keygen_poly_gen_matrix_profiling.s",
        "keygen_poly_gen_matrix_data.s",
        "poly_gen_matrix.s",
        "//test_hybrid_kem_otbn_prompt_ver0_2/otbn/kmac_official:xof.s",
    ],
)

otbn_binary(
    name = "mlkem768_keygen_poly_gen_matrix_control",
    srcs = [
        "keygen_poly_gen_matrix_control.s",
    ],
)

otbn_binary(
    name = "mlkem768_encap_hash_g_profiling",
    srcs = [
        "encap_hash_g_profiling.s",
        "//test_hybrid_kem_otbn_prompt_ver0_2/otbn/kmac_official:xof.s",
    ],
)

otbn_binary(
    name = "mlkem768_encap_hash_g_control",
    srcs = [
        "encap_hash_g_control.s",
    ],
)

otbn_binary(
    name = "mlkem768_encap_poly_gen_matrix_profiling",
    srcs = [
        "encap_poly_gen_matrix_profiling.s",
        "encap_poly_gen_matrix_data.s",
        "poly_gen_matrix.s",
        "//test_hybrid_kem_otbn_prompt_ver0_2/otbn/kmac_official:xof.s",
    ],
)

otbn_binary(
    name = "mlkem768_encap_poly_gen_matrix_control",
    srcs = [
        "encap_poly_gen_matrix_control.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_poly_gen_matrix_profiling",
    srcs = [
        "decap_poly_gen_matrix_profiling.s",
        "decap_poly_gen_matrix_data.s",
        "poly_gen_matrix.s",
        "//test_hybrid_kem_otbn_prompt_ver0_2/otbn/kmac_official:xof.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_poly_gen_matrix_control",
    srcs = [
        "decap_poly_gen_matrix_control.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_shake_z_ct_profiling",
    srcs = [
        "decap_shake_z_ct_profiling.s",
        "//test_hybrid_kem_otbn_prompt_ver0_2/otbn/kmac_official:xof.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_shake_z_ct_control",
    srcs = [
        "decap_shake_z_ct_control.s",
    ],
)

# ── poly_gen_matrix 子分解（闭环=0；桩法同 ver0_1，直接把 KMAC API 换桩）──
otbn_binary(
    name = "mlkem768_keygen_poly_gen_matrix_rejection_profiling",
    srcs = [
        "keygen_poly_gen_matrix_rejection_profiling.s",
        "keygen_poly_gen_matrix_rejection_streams.s",
        "keygen_poly_gen_matrix_rejection_stubs.s",
        "keygen_poly_gen_matrix_data.s",
        "poly_gen_matrix.s",
    ],
)

otbn_binary(
    name = "mlkem768_keygen_poly_gen_matrix_rejection_control",
    srcs = [
        "keygen_poly_gen_matrix_rejection_control.s",
        "keygen_poly_gen_matrix_rejection_streams.s",
    ],
)

otbn_binary(
    name = "mlkem768_keygen_poly_gen_matrix_stub_overhead_profiling",
    srcs = [
        "keygen_poly_gen_matrix_stub_overhead_profiling.s",
        "keygen_poly_gen_matrix_rejection_stubs.s",
        "keygen_poly_gen_matrix_rejection_streams.s",
    ],
)

otbn_binary(
    name = "mlkem768_keygen_poly_gen_matrix_stub_overhead_control",
    srcs = [
        "keygen_poly_gen_matrix_stub_overhead_control.s",
        "keygen_poly_gen_matrix_rejection_streams.s",
    ],
)

otbn_binary(
    name = "mlkem768_keygen_poly_gen_matrix_shake_profiling",
    srcs = [
        "keygen_poly_gen_matrix_shake_profiling.s",
        "//test_hybrid_kem_otbn_prompt_ver0_2/otbn/kmac_official:xof.s",
    ],
)

otbn_binary(
    name = "mlkem768_keygen_poly_gen_matrix_shake_control",
    srcs = [
        "keygen_poly_gen_matrix_shake_control.s",
    ],
)


# ── 实测行（2026-09-20）：原 reuse 估算行改为在各自 op 里现场实测 ─────────
# 次数 = 该 app 源码的静态调用数（.rept/LOOPI 连乘）；行名与旧 reuse 行一致。
# 生成器：test_perf/gen_harness.py + test_perf/harness_specs_ver0_2.py

otbn_binary(
    name = "mlkem768_encap_intt_x4_profiling",
    srcs = [
        "encap_intt_x4_profiling.s",
        "intt.s",
        "encap_intt_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_encap_intt_x4_control",
    srcs = [
        "encap_intt_x4_control.s",
        "intt.s",
        "encap_intt_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_encap_noise_x7_profiling",
    srcs = [
        "encap_noise_x7_profiling.s",
        "poly.s",
        "cbd.s",
        "//test_hybrid_kem_otbn_prompt_ver0_2/otbn/kmac_official:xof.s",
        "keygen_poly_getnoise_eta_1_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_encap_noise_x7_control",
    srcs = [
        "encap_noise_x7_control.s",
        "poly.s",
        "cbd.s",
        "//test_hybrid_kem_otbn_prompt_ver0_2/otbn/kmac_official:xof.s",
        "keygen_poly_getnoise_eta_1_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_encap_h_ek_profiling",
    srcs = [
        "encap_h_ek_profiling.s",
        "//test_hybrid_kem_otbn_prompt_ver0_2/otbn/kmac_official:xof.s",
    ],
)

otbn_binary(
    name = "mlkem768_encap_h_ek_control",
    srcs = [
        "encap_h_ek_control.s",
        "//test_hybrid_kem_otbn_prompt_ver0_2/otbn/kmac_official:xof.s",
    ],
)

otbn_binary(
    name = "mlkem768_encap_basemul_acc_x12_profiling",
    srcs = [
        "encap_basemul_acc_x12_profiling.s",
        "basemul.s",
        "keygen_basemul_basemul_acc_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_encap_basemul_acc_x12_control",
    srcs = [
        "encap_basemul_acc_x12_control.s",
        "basemul.s",
        "keygen_basemul_basemul_acc_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_encap_ntt_x3_profiling",
    srcs = [
        "encap_ntt_x3_profiling.s",
        "ntt.s",
        "keygen_ntt_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_encap_ntt_x3_control",
    srcs = [
        "encap_ntt_x3_control.s",
        "ntt.s",
        "keygen_ntt_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_encap_poly_add_x5_profiling",
    srcs = [
        "encap_poly_add_x5_profiling.s",
        "keygen_poly_add_impl.s",
    ],
)

otbn_binary(
    name = "mlkem768_encap_poly_add_x5_control",
    srcs = [
        "encap_poly_add_x5_control.s",
        "keygen_poly_add_impl.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_noise_x7_profiling",
    srcs = [
        "decap_noise_x7_profiling.s",
        "poly.s",
        "cbd.s",
        "//test_hybrid_kem_otbn_prompt_ver0_2/otbn/kmac_official:xof.s",
        "keygen_poly_getnoise_eta_1_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_noise_x7_control",
    srcs = [
        "decap_noise_x7_control.s",
        "poly.s",
        "cbd.s",
        "//test_hybrid_kem_otbn_prompt_ver0_2/otbn/kmac_official:xof.s",
        "keygen_poly_getnoise_eta_1_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_basemul_acc_x15_profiling",
    srcs = [
        "decap_basemul_acc_x15_profiling.s",
        "basemul.s",
        "keygen_basemul_basemul_acc_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_basemul_acc_x15_control",
    srcs = [
        "decap_basemul_acc_x15_control.s",
        "basemul.s",
        "keygen_basemul_basemul_acc_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_ntt_x6_profiling",
    srcs = [
        "decap_ntt_x6_profiling.s",
        "ntt.s",
        "keygen_ntt_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_ntt_x6_control",
    srcs = [
        "decap_ntt_x6_control.s",
        "ntt.s",
        "keygen_ntt_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_intt_x5_profiling",
    srcs = [
        "decap_intt_x5_profiling.s",
        "intt.s",
        "encap_intt_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_intt_x5_control",
    srcs = [
        "decap_intt_x5_control.s",
        "intt.s",
        "encap_intt_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_pack_ciphertext_profiling",
    srcs = [
        "decap_pack_ciphertext_profiling.s",
        "pack_ciphertext.s",
        "encap_pack_ciphertext_data.s",
        "decap_poly_sub_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_pack_ciphertext_control",
    srcs = [
        "decap_pack_ciphertext_control.s",
        "pack_ciphertext.s",
        "encap_pack_ciphertext_data.s",
        "decap_poly_sub_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_poly_add_x5_profiling",
    srcs = [
        "decap_poly_add_x5_profiling.s",
        "keygen_poly_add_impl.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_poly_add_x5_control",
    srcs = [
        "decap_poly_add_x5_control.s",
        "keygen_poly_add_impl.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_hash_g_reuse_profiling",
    srcs = [
        "decap_hash_g_reuse_profiling.s",
        "//test_hybrid_kem_otbn_prompt_ver0_2/otbn/kmac_official:xof.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_hash_g_reuse_control",
    srcs = [
        "decap_hash_g_reuse_control.s",
        "//test_hybrid_kem_otbn_prompt_ver0_2/otbn/kmac_official:xof.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_unpack_sk_pk_profiling",
    srcs = [
        "decap_unpack_sk_pk_profiling.s",
        "pack_keys.s",
        "decap_unpack_ciphertext_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_unpack_sk_pk_control",
    srcs = [
        "decap_unpack_sk_pk_control.s",
        "pack_keys.s",
        "decap_unpack_ciphertext_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_poly_frommsg_reuse_profiling",
    srcs = [
        "decap_poly_frommsg_reuse_profiling.s",
        "encap_poly_frommsg_impl.s",
        "encap_pack_ciphertext_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_poly_frommsg_reuse_control",
    srcs = [
        "decap_poly_frommsg_reuse_control.s",
        "encap_poly_frommsg_impl.s",
        "encap_pack_ciphertext_data.s",
    ],
)

# ── 实测行（补）：poly_reduce（ver0_1/ver0_2 有独立内核；ver1_1 无）──
otbn_binary(
    name = "mlkem768_encap_poly_reduce_x4_profiling",
    srcs = [
        "encap_poly_reduce_x4_profiling.s",
        "keygen_poly_reduce_impl.s",
        "keygen_poly_reduce_data.s",
        "encap_pack_ciphertext_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_encap_poly_reduce_x4_control",
    srcs = [
        "encap_poly_reduce_x4_control.s",
        "keygen_poly_reduce_impl.s",
        "keygen_poly_reduce_data.s",
        "encap_pack_ciphertext_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_poly_reduce_x5_profiling",
    srcs = [
        "decap_poly_reduce_x5_profiling.s",
        "keygen_poly_reduce_impl.s",
        "keygen_poly_reduce_data.s",
        "encap_pack_ciphertext_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_poly_reduce_x5_control",
    srcs = [
        "decap_poly_reduce_x5_control.s",
        "keygen_poly_reduce_impl.s",
        "keygen_poly_reduce_data.s",
        "encap_pack_ciphertext_data.s",
    ],
)
