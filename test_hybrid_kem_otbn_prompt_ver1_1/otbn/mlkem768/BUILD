# BUILD — ver1_1 ML-KEM-768（官方向量指令实现）
#
# 内核逐字移植自 //sw/otbn/crypto/mlkem1024（含掩码与官方 xof.s 驱动），
# 文件与函数布局沿用 ver0_2/otbn/mlkem768。

load("//rules:otbn.bzl", "otbn_binary", "otbn_library")

package(default_visibility = ["//visibility:public"])

XOF = "//test_hybrid_kem_otbn_prompt_ver1_1/otbn/kmac_official:xof.s"

otbn_library(name = "mlkem_keypair",   srcs = [
        "mlkem_keypair.s",
    ])
otbn_library(name = "mlkem_encap",     srcs = [
        "mlkem_encap.s",
    ])
otbn_library(name = "mlkem_decap",     srcs = [
        "mlkem_decap.s",
    ])
otbn_library(name = "basemul",         srcs = [
        "basemul.s",
    ])
otbn_library(name = "cbd",             srcs = [
        "cbd.s",
    ])
otbn_library(name = "intt",            srcs = [
        "intt.s",
    ])
otbn_library(name = "ntt",             srcs = [
        "ntt.s",
    ])
otbn_library(name = "pack_keys",       srcs = [
        "pack_keys.s",
    ])
otbn_library(name = "pack_ciphertext", srcs = [
        "pack_ciphertext.s",
    ])
otbn_library(name = "poly",            srcs = [
        "poly.s",
    ])
otbn_library(name = "poly_gen_matrix", srcs = [
        "poly_gen_matrix.s",
    ])

otbn_binary(
    name = "mlkem768_keypair",
    srcs = [
        "//test_hybrid_kem_otbn_prompt_ver1_1/otbn/test:mlkem_base_keypair_test.s",
        "mlkem_keypair.s", "basemul.s", "cbd.s", "ntt.s",
        "poly.s", "poly_gen_matrix.s", "pack_keys.s",
        XOF,
    ],
)

otbn_binary(
    name = "mlkem768_encap",
    srcs = [
        "//test_hybrid_kem_otbn_prompt_ver1_1/otbn/test:mlkem_base_encap_test.s",
        "mlkem_encap.s", "basemul.s", "cbd.s", "intt.s", "ntt.s",
        "poly.s", "poly_gen_matrix.s", "pack_keys.s", "pack_ciphertext.s",
        XOF,
    ],
)

otbn_binary(
    name = "mlkem768_decap",
    srcs = [
        "//test_hybrid_kem_otbn_prompt_ver1_1/otbn/test:mlkem_base_decap_test.s",
        "mlkem_decap.s", "mlkem_encap.s", "basemul.s", "cbd.s",
        "intt.s", "ntt.s", "poly.s", "poly_gen_matrix.s",
        "pack_keys.s", "pack_ciphertext.s",
        XOF,
    ],
)

# ────────── harness 法剖面目标（22 对；2026-09-20 按 ver1_1 内核约定重写）──────────
#
# 用法：python3 test_perf/harness.py --config test_perf/harness_config.yaml --version ver1_1
#
# 每对的 srcs = **最小闭包**（调用段 + 被调内核 + 其传递依赖 + 共享数据），
# 与 ver0_1/ver0_2 的写法一致；不再是"整份内核"。
#   - 调用段 .s：复刻 app（mlkem_keypair/encap/decap.s）的真实寄存器约定与调用次数
#   - common_data.s：内核代码里引用的常量/缓冲（stack、_expand_buf、_compress_* 等）
#   - xof.s：KMAC 驱动（官方逐字）
# 静态预检（不需要 bazel）：
#   python3 test_perf/otbn_symbol_check.py --build test_hybrid_kem_otbn_prompt_ver1_1/otbn/mlkem768/BUILD
#
# 未接线（有意）：keygen_poly_reduce / keygen_poly_gen_matrix_rejection /
#   keygen_poly_gen_matrix_stub_overhead —— ver1_1 无对应内核（归约融进 basemul_acc、
#   poly_gen_matrix 自己驱动硬件 XOF），目录里同名 .s 仍是 ver0_2 遗留的桩法版本。

# ── KeyGen ──────────────────────────────────────────────────────────────
otbn_binary(
    name = "mlkem768_keygen_ntt_profiling",
    srcs = [
        "keygen_ntt_profiling.s",
        "ntt.s",
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_keygen_ntt_control",
    srcs = [
        "keygen_ntt_control.s",
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_keygen_poly_gen_matrix_profiling",
    srcs = [
        "keygen_poly_gen_matrix_profiling.s",
        "poly_gen_matrix.s",
        XOF,
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_keygen_poly_gen_matrix_control",
    srcs = [
        "keygen_poly_gen_matrix_control.s",
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_keygen_hash_h_profiling",
    srcs = [
        "keygen_hash_h_profiling.s",
        XOF,
    ],
)

otbn_binary(
    name = "mlkem768_keygen_hash_h_control",
    srcs = [
        "keygen_hash_h_control.s",
    ],
)

otbn_binary(
    name = "mlkem768_keygen_sha3_init_update_final_profiling",
    srcs = [
        "keygen_sha3_init_update_final_profiling.s",
        XOF,
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
        "poly.s",
        "cbd.s",
        XOF,
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_keygen_poly_getnoise_eta_1_control",
    srcs = [
        "keygen_poly_getnoise_eta_1_control.s",
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_keygen_basemul_basemul_acc_profiling",
    srcs = [
        "keygen_basemul_basemul_acc_profiling.s",
        "basemul.s",
        "ntt.s",
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_keygen_basemul_basemul_acc_control",
    srcs = [
        "ntt.s",
        "keygen_basemul_basemul_acc_control.s",
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_keygen_poly_add_profiling",
    srcs = [
        "keygen_poly_add_profiling.s",
        "poly.s",
        "cbd.s",
        XOF,
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_keygen_poly_add_control",
    srcs = [
        "keygen_poly_add_control.s",
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_keygen_pack_pk_profiling",
    srcs = [
        "keygen_pack_pk_profiling.s",
        "pack_keys.s",
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_keygen_pack_pk_control",
    srcs = [
        "keygen_pack_pk_control.s",
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_keygen_pack_sk_profiling",
    srcs = [
        "keygen_pack_sk_profiling.s",
        "pack_keys.s",
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_keygen_pack_sk_control",
    srcs = [
        "keygen_pack_sk_control.s",
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_keygen_poly_gen_matrix_shake_profiling",
    srcs = [
        "keygen_poly_gen_matrix_shake_profiling.s",
        XOF,
    ],
)

otbn_binary(
    name = "mlkem768_keygen_poly_gen_matrix_shake_control",
    srcs = [
        "keygen_poly_gen_matrix_shake_control.s",
    ],
)

# ── Encaps ──────────────────────────────────────────────────────────────
otbn_binary(
    name = "mlkem768_encap_poly_gen_matrix_profiling",
    srcs = [
        "encap_poly_gen_matrix_profiling.s",
        "poly_gen_matrix.s",
        XOF,
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_encap_poly_gen_matrix_control",
    srcs = [
        "encap_poly_gen_matrix_control.s",
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_encap_intt_profiling",
    srcs = [
        "encap_intt_profiling.s",
        "intt.s",
        "ntt.s",
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_encap_intt_control",
    srcs = [
        "encap_intt_control.s",
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_encap_hash_g_profiling",
    srcs = [
        "encap_hash_g_profiling.s",
        XOF,
    ],
)

otbn_binary(
    name = "mlkem768_encap_hash_g_control",
    srcs = [
        "encap_hash_g_control.s",
    ],
)

otbn_binary(
    name = "mlkem768_encap_pack_ciphertext_profiling",
    srcs = [
        "encap_pack_ciphertext_profiling.s",
        "pack_ciphertext.s",
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_encap_pack_ciphertext_control",
    srcs = [
        "encap_pack_ciphertext_control.s",
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_encap_unpack_pk_profiling",
    srcs = [
        "encap_unpack_pk_profiling.s",
        "pack_keys.s",
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_encap_unpack_pk_control",
    srcs = [
        "encap_unpack_pk_control.s",
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_encap_poly_frommsg_profiling",
    srcs = [
        "encap_poly_frommsg_profiling.s",
        "poly.s",
        "cbd.s",
        XOF,
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_encap_poly_frommsg_control",
    srcs = [
        "encap_poly_frommsg_control.s",
        "common_data.s",
    ],
)

# ── Decaps ──────────────────────────────────────────────────────────────
otbn_binary(
    name = "mlkem768_decap_poly_gen_matrix_profiling",
    srcs = [
        "decap_poly_gen_matrix_profiling.s",
        "poly_gen_matrix.s",
        XOF,
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_poly_gen_matrix_control",
    srcs = [
        "decap_poly_gen_matrix_control.s",
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_unpack_ciphertext_profiling",
    srcs = [
        "decap_unpack_ciphertext_profiling.s",
        "pack_ciphertext.s",
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_unpack_ciphertext_control",
    srcs = [
        "decap_unpack_ciphertext_control.s",
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_poly_sub_profiling",
    srcs = [
        "decap_poly_sub_profiling.s",
        "poly.s",
        "cbd.s",
        XOF,
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_poly_sub_control",
    srcs = [
        "decap_poly_sub_control.s",
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_poly_tomsg_profiling",
    srcs = [
        "decap_poly_tomsg_profiling.s",
        "poly.s",
        "cbd.s",
        XOF,
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_poly_tomsg_control",
    srcs = [
        "decap_poly_tomsg_control.s",
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_shake_z_ct_profiling",
    srcs = [
        "decap_shake_z_ct_profiling.s",
        XOF,
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_shake_z_ct_control",
    srcs = [
        "decap_shake_z_ct_control.s",
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_verify_cmov_profiling",
    srcs = [
        "decap_verify_cmov_profiling.s",
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_verify_cmov_control",
    srcs = [
        "decap_verify_cmov_control.s",
        "common_data.s",
    ],
)

# ── 实测行（2026-09-20）：原 reuse 估算行改为在各自 op 里现场实测 ─────────
# 次数 = 该 app 源码的动态调用次数；生成器 test_perf/gen_harness.py +
# test_perf/harness_specs.py（行名与旧的 reuse 行保持一致）

otbn_binary(
    name = "mlkem768_encap_intt_x4_profiling",
    srcs = [
        "encap_intt_x4_profiling.s",
        "intt.s",
        "ntt.s",
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_encap_intt_x4_control",
    srcs = [
        "encap_intt_x4_control.s",
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_encap_noise_x7_profiling",
    srcs = [
        "encap_noise_x7_profiling.s",
        "poly.s",
        "cbd.s",
        "//test_hybrid_kem_otbn_prompt_ver1_1/otbn/kmac_official:xof.s",
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_encap_noise_x7_control",
    srcs = [
        "encap_noise_x7_control.s",
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_encap_basemul_acc_x12_profiling",
    srcs = [
        "encap_basemul_acc_x12_profiling.s",
        "basemul.s",
        "ntt.s",
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_encap_basemul_acc_x12_control",
    srcs = [
        "ntt.s",
        "encap_basemul_acc_x12_control.s",
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_encap_ntt_x3_profiling",
    srcs = [
        "encap_ntt_x3_profiling.s",
        "ntt.s",
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_encap_ntt_x3_control",
    srcs = [
        "encap_ntt_x3_control.s",
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_encap_poly_add_x5_profiling",
    srcs = [
        "encap_poly_add_x5_profiling.s",
        "poly.s",
        "cbd.s",
        "//test_hybrid_kem_otbn_prompt_ver1_1/otbn/kmac_official:xof.s",
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_encap_poly_add_x5_control",
    srcs = [
        "encap_poly_add_x5_control.s",
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_encap_h_ek_profiling",
    srcs = [
        "encap_h_ek_profiling.s",
        "//test_hybrid_kem_otbn_prompt_ver1_1/otbn/kmac_official:xof.s",
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_encap_h_ek_control",
    srcs = [
        "encap_h_ek_control.s",
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_noise_x7_profiling",
    srcs = [
        "decap_noise_x7_profiling.s",
        "poly.s",
        "cbd.s",
        "//test_hybrid_kem_otbn_prompt_ver1_1/otbn/kmac_official:xof.s",
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_noise_x7_control",
    srcs = [
        "decap_noise_x7_control.s",
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_basemul_acc_x15_profiling",
    srcs = [
        "decap_basemul_acc_x15_profiling.s",
        "basemul.s",
        "ntt.s",
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_basemul_acc_x15_control",
    srcs = [
        "ntt.s",
        "decap_basemul_acc_x15_control.s",
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_ntt_x6_profiling",
    srcs = [
        "decap_ntt_x6_profiling.s",
        "ntt.s",
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_ntt_x6_control",
    srcs = [
        "decap_ntt_x6_control.s",
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_intt_x5_profiling",
    srcs = [
        "decap_intt_x5_profiling.s",
        "intt.s",
        "ntt.s",
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_intt_x5_control",
    srcs = [
        "decap_intt_x5_control.s",
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_pack_ciphertext_profiling",
    srcs = [
        "decap_pack_ciphertext_profiling.s",
        "pack_ciphertext.s",
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_pack_ciphertext_control",
    srcs = [
        "decap_pack_ciphertext_control.s",
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_poly_add_x5_profiling",
    srcs = [
        "decap_poly_add_x5_profiling.s",
        "poly.s",
        "cbd.s",
        "//test_hybrid_kem_otbn_prompt_ver1_1/otbn/kmac_official:xof.s",
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_poly_add_x5_control",
    srcs = [
        "decap_poly_add_x5_control.s",
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_hash_g_reuse_profiling",
    srcs = [
        "decap_hash_g_reuse_profiling.s",
        "//test_hybrid_kem_otbn_prompt_ver1_1/otbn/kmac_official:xof.s",
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_hash_g_reuse_control",
    srcs = [
        "decap_hash_g_reuse_control.s",
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_unpack_sk_pk_profiling",
    srcs = [
        "decap_unpack_sk_pk_profiling.s",
        "pack_keys.s",
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_unpack_sk_pk_control",
    srcs = [
        "decap_unpack_sk_pk_control.s",
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_poly_frommsg_reuse_profiling",
    srcs = [
        "decap_poly_frommsg_reuse_profiling.s",
        "poly.s",
        "cbd.s",
        "//test_hybrid_kem_otbn_prompt_ver1_1/otbn/kmac_official:xof.s",
        "common_data.s",
    ],
)

otbn_binary(
    name = "mlkem768_decap_poly_frommsg_reuse_control",
    srcs = [
        "decap_poly_frommsg_reuse_control.s",
        "common_data.s",
    ],
)
