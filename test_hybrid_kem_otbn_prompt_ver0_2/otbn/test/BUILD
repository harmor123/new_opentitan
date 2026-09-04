# BUILD — ver0_2 OTBN 仿真测试（官方资源基线）
#
# ML-KEM 数学同 ver1（Plantard），哈希全部走官方 xof.s 驱动
# （sw/otbn/crypto/xof.s 逐字版，见 ../kmac_official/）。

load("//rules:otbn.bzl", "otbn_sim_test")

package(default_visibility = ["//visibility:public"])

exports_files([
    "mlkem_base_keypair_test.s",
    "mlkem_base_encap_test.s",
    "mlkem_base_decap_test.s",
    "hkdf_test.s",
])

otbn_sim_test(
    name = "hkdf_test",
    srcs = ["hkdf_test.s"],
    dexp = "hkdf_test.dexp",
    deps = [
        "//test_hybrid_kem_otbn_prompt_ver0_2/otbn/hkdf:hkdf_sha3_256_lib",
        "//test_hybrid_kem_otbn_prompt_ver0_2/otbn/hkdf:hmac_sha3_lib",
        "//test_hybrid_kem_otbn_prompt_ver0_2/otbn/kmac_official:xof",
    ],
)

otbn_sim_test(
    name = "mlkem768_keypair_test",
    srcs = ["mlkem_base_keypair_test.s"],
    dexp = "kp.dexp",
    deps = [
        "//test_hybrid_kem_otbn_prompt_ver0_2/otbn/mlkem768:basemul",
        "//test_hybrid_kem_otbn_prompt_ver0_2/otbn/mlkem768:cbd",
        "//test_hybrid_kem_otbn_prompt_ver0_2/otbn/mlkem768:ntt",
        "//test_hybrid_kem_otbn_prompt_ver0_2/otbn/mlkem768:pack_keys",
        "//test_hybrid_kem_otbn_prompt_ver0_2/otbn/mlkem768:poly",
        "//test_hybrid_kem_otbn_prompt_ver0_2/otbn/mlkem768:poly_gen_matrix",
        "//test_hybrid_kem_otbn_prompt_ver0_2/otbn/mlkem768:mlkem_keypair",
        "//test_hybrid_kem_otbn_prompt_ver0_2/otbn/kmac_official:xof",
    ],
)

otbn_sim_test(
    name = "mlkem768_encap_test",
    srcs = ["mlkem_base_encap_test.s"],
    dexp = "enc.dexp",
    deps = [
        "//test_hybrid_kem_otbn_prompt_ver0_2/otbn/mlkem768:basemul",
        "//test_hybrid_kem_otbn_prompt_ver0_2/otbn/mlkem768:cbd",
        "//test_hybrid_kem_otbn_prompt_ver0_2/otbn/mlkem768:intt",
        "//test_hybrid_kem_otbn_prompt_ver0_2/otbn/mlkem768:ntt",
        "//test_hybrid_kem_otbn_prompt_ver0_2/otbn/mlkem768:pack_keys",
        "//test_hybrid_kem_otbn_prompt_ver0_2/otbn/mlkem768:pack_ciphertext",
        "//test_hybrid_kem_otbn_prompt_ver0_2/otbn/mlkem768:poly",
        "//test_hybrid_kem_otbn_prompt_ver0_2/otbn/mlkem768:poly_gen_matrix",
        "//test_hybrid_kem_otbn_prompt_ver0_2/otbn/mlkem768:mlkem_encap",
        "//test_hybrid_kem_otbn_prompt_ver0_2/otbn/kmac_official:xof",
    ],
)

otbn_sim_test(
    name = "mlkem768_decap_test",
    srcs = ["mlkem_base_decap_test.s"],
    dexp = "dec.dexp",
    deps = [
        "//test_hybrid_kem_otbn_prompt_ver0_2/otbn/mlkem768:basemul",
        "//test_hybrid_kem_otbn_prompt_ver0_2/otbn/mlkem768:cbd",
        "//test_hybrid_kem_otbn_prompt_ver0_2/otbn/mlkem768:intt",
        "//test_hybrid_kem_otbn_prompt_ver0_2/otbn/mlkem768:ntt",
        "//test_hybrid_kem_otbn_prompt_ver0_2/otbn/mlkem768:pack_keys",
        "//test_hybrid_kem_otbn_prompt_ver0_2/otbn/mlkem768:pack_ciphertext",
        "//test_hybrid_kem_otbn_prompt_ver0_2/otbn/mlkem768:poly",
        "//test_hybrid_kem_otbn_prompt_ver0_2/otbn/mlkem768:poly_gen_matrix",
        "//test_hybrid_kem_otbn_prompt_ver0_2/otbn/mlkem768:mlkem_encap",
        "//test_hybrid_kem_otbn_prompt_ver0_2/otbn/mlkem768:mlkem_decap",
        "//test_hybrid_kem_otbn_prompt_ver0_2/otbn/kmac_official:xof",
    ],
)
