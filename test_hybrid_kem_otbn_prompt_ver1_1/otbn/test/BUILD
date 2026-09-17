# BUILD — ver1_1 OTBN 仿真测试
#
# 输入向量与期望值 (dexp) 均取自 ver0_2，用于验证 ver1_1（官方向量指令实现）
# 与 ver0_2（Plantard 标量实现）产生完全相同的 FIPS 203 输出。

load("//rules:otbn.bzl", "otbn_sim_test")

package(default_visibility = ["//visibility:public"])

exports_files([
    "mlkem_base_keypair_test.s",
    "mlkem_base_encap_test.s",
    "mlkem_base_decap_test.s",
    "kp.dexp",
    "enc.dexp",
    "dec.dexp",
])

otbn_sim_test(
    name = "mlkem768_keypair_test",
    srcs = ["mlkem_base_keypair_test.s"],
    dexp = "kp.dexp",
    deps = [
        "//test_hybrid_kem_otbn_prompt_ver1_1/otbn/mlkem768:basemul",
        "//test_hybrid_kem_otbn_prompt_ver1_1/otbn/mlkem768:cbd",
        "//test_hybrid_kem_otbn_prompt_ver1_1/otbn/mlkem768:ntt",
        "//test_hybrid_kem_otbn_prompt_ver1_1/otbn/mlkem768:pack_keys",
        "//test_hybrid_kem_otbn_prompt_ver1_1/otbn/mlkem768:poly",
        "//test_hybrid_kem_otbn_prompt_ver1_1/otbn/mlkem768:poly_gen_matrix",
        "//test_hybrid_kem_otbn_prompt_ver1_1/otbn/mlkem768:mlkem_keypair",
        "//sw/otbn/crypto:xof",
    ],
)

otbn_sim_test(
    name = "mlkem768_encap_test",
    srcs = ["mlkem_base_encap_test.s"],
    dexp = "enc.dexp",
    deps = [
        "//test_hybrid_kem_otbn_prompt_ver1_1/otbn/mlkem768:basemul",
        "//test_hybrid_kem_otbn_prompt_ver1_1/otbn/mlkem768:cbd",
        "//test_hybrid_kem_otbn_prompt_ver1_1/otbn/mlkem768:intt",
        "//test_hybrid_kem_otbn_prompt_ver1_1/otbn/mlkem768:ntt",
        "//test_hybrid_kem_otbn_prompt_ver1_1/otbn/mlkem768:pack_keys",
        "//test_hybrid_kem_otbn_prompt_ver1_1/otbn/mlkem768:pack_ciphertext",
        "//test_hybrid_kem_otbn_prompt_ver1_1/otbn/mlkem768:poly",
        "//test_hybrid_kem_otbn_prompt_ver1_1/otbn/mlkem768:poly_gen_matrix",
        "//test_hybrid_kem_otbn_prompt_ver1_1/otbn/mlkem768:mlkem_encap",
        "//sw/otbn/crypto:xof",
    ],
)

otbn_sim_test(
    name = "mlkem768_decap_test",
    srcs = ["mlkem_base_decap_test.s"],
    dexp = "dec.dexp",
    deps = [
        "//test_hybrid_kem_otbn_prompt_ver1_1/otbn/mlkem768:basemul",
        "//test_hybrid_kem_otbn_prompt_ver1_1/otbn/mlkem768:cbd",
        "//test_hybrid_kem_otbn_prompt_ver1_1/otbn/mlkem768:intt",
        "//test_hybrid_kem_otbn_prompt_ver1_1/otbn/mlkem768:ntt",
        "//test_hybrid_kem_otbn_prompt_ver1_1/otbn/mlkem768:pack_keys",
        "//test_hybrid_kem_otbn_prompt_ver1_1/otbn/mlkem768:pack_ciphertext",
        "//test_hybrid_kem_otbn_prompt_ver1_1/otbn/mlkem768:poly",
        "//test_hybrid_kem_otbn_prompt_ver1_1/otbn/mlkem768:poly_gen_matrix",
        "//test_hybrid_kem_otbn_prompt_ver1_1/otbn/mlkem768:mlkem_decap",
        "//test_hybrid_kem_otbn_prompt_ver1_1/otbn/mlkem768:mlkem_encap",
        "//sw/otbn/crypto:xof",
    ],
)
