load("//rules:otbn.bzl", "otbn_sim_test")

package(default_visibility = ["//visibility:public"])

exports_files([
    "mlkem_base_keypair_test.s",
    "mlkem_base_encap_test.s",
    "mlkem_base_decap_test.s",
    "p256_ecdh_shared_key_test.s",
    "kdf_test.s",
    "sha3_test.s",
    "modp256_test.s",
])

otbn_sim_test(
    name = "mlkem768_keypair_test",
    srcs = ["mlkem_base_keypair_test.s"],
    deps = [
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/mlkem768:basemul",
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/mlkem768:cbd",
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/mlkem768:ntt",
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/mlkem768:pack_keys",
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/mlkem768:poly",
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/mlkem768:poly_gen_matrix",
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/mlkem768:kmac_sha3",
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/mlkem768:mlkem_keypair_s",
    ],
    dexp = "kp.dexp",
    copts = ["--bnmulv_version_id=2"],
)

otbn_sim_test(
    name = "mlkem768_encap_test",
    srcs = ["mlkem_base_encap_test.s"],
    deps = [
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/mlkem768:basemul",
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/mlkem768:cbd",
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/mlkem768:ntt",
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/mlkem768:intt",
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/mlkem768:pack_keys",
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/mlkem768:pack_ciphertext",
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/mlkem768:poly",
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/mlkem768:poly_gen_matrix",
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/mlkem768:kmac_sha3",
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/mlkem768:mlkem_encap_s",
    ],
    dexp = "enc.dexp",
    copts = ["--bnmulv_version_id=2"],
)

otbn_sim_test(
    name = "mlkem768_decap_test",
    srcs = ["mlkem_base_decap_test.s"],
    deps = [
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/mlkem768:basemul",
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/mlkem768:cbd",
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/mlkem768:ntt",
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/mlkem768:intt",
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/mlkem768:pack_keys",
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/mlkem768:pack_ciphertext",
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/mlkem768:poly",
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/mlkem768:poly_gen_matrix",
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/mlkem768:kmac_sha3",
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/mlkem768:mlkem_decap_s",
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/mlkem768:mlkem_encap_s",
    ],
    dexp = "dec.dexp",
    copts = ["--bnmulv_version_id=2"],
)

otbn_sim_test(
    name = "p256_ecdh_test",
    srcs = ["p256_ecdh_shared_key_test.s"],
    deps = [
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/p256:p256_base_lib",
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/p256:p256_isoncurve_proj_lib",
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/p256:p256_shared_key_lib",
    ],
    dexp = "p256.dexp",
    copts = ["--bnmulv_version_id=2"],
)

otbn_sim_test(
    name = "kdf_test",
    srcs = ["kdf_test.s"],
    deps = [
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/kmac:kmac_kdf_lib",
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/kmac:kmac_xof_lib",
    ],
    dexp = "kdf_test.dexp",
)

otbn_sim_test(
    name = "sha3_test",
    srcs = ["sha3_test.s"],
    deps = [
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/kmac:kmac_xof_lib",
    ],
    dexp = "sha3_test.dexp",
)

otbn_sim_test(
    name = "modp256_test",
    srcs = ["modp256_test.s"],
    dexp = "modp256_test.dexp",
    copts = ["--bnmulv_version_id=2"],
)
