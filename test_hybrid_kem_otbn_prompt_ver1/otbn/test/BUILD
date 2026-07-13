# BUILD — OTBN simulation tests (ver1: SW ML-KEM + KMAC Hash)
#
# ML-KEM/P-256 纯软件, SHA3/HMAC/HKDF 用 KMAC 硬件加速。

load("//rules:otbn.bzl", "otbn_sim_test")

package(default_visibility = ["//visibility:public"])

exports_files([
    "hmac_test.s",
    "mlkem_base_keypair_test.s",
    "mlkem_base_encap_test.s",
    "mlkem_base_decap_test.s",
    "p256_ecdh_shared_key_test.s",
    "hkdf_test.s",
    "sha3_test.s",
])

# ================================================================
# ML-KEM-768 (纯软件, 同 ver0)
# ================================================================

otbn_sim_test(
    name = "mlkem768_keypair_test",
    srcs = ["mlkem_base_keypair_test.s"],
    dexp = "kp.dexp",
    deps = [
        "//test_hybrid_kem_otbn_prompt_ver1/otbn/mlkem768:basemul",
        "//test_hybrid_kem_otbn_prompt_ver1/otbn/mlkem768:cbd",
        "//test_hybrid_kem_otbn_prompt_ver1/otbn/mlkem768:ntt",
        "//test_hybrid_kem_otbn_prompt_ver1/otbn/mlkem768:pack_keys",
        "//test_hybrid_kem_otbn_prompt_ver1/otbn/mlkem768:poly",
        "//test_hybrid_kem_otbn_prompt_ver1/otbn/mlkem768:poly_gen_matrix",
        "//test_hybrid_kem_otbn_prompt_ver1/otbn/mlkem768:mlkem_keypair",
        "//test_hybrid_kem_otbn_prompt_ver1/otbn/mlkem768:kmac_sha3_template",
    ],
)

otbn_sim_test(
    name = "mlkem768_encap_test",
    srcs = ["mlkem_base_encap_test.s"],
    dexp = "enc.dexp",
    deps = [
        "//test_hybrid_kem_otbn_prompt_ver1/otbn/mlkem768:basemul",
        "//test_hybrid_kem_otbn_prompt_ver1/otbn/mlkem768:cbd",
        "//test_hybrid_kem_otbn_prompt_ver1/otbn/mlkem768:intt",
        "//test_hybrid_kem_otbn_prompt_ver1/otbn/mlkem768:ntt",
        "//test_hybrid_kem_otbn_prompt_ver1/otbn/mlkem768:pack_keys",
        "//test_hybrid_kem_otbn_prompt_ver1/otbn/mlkem768:pack_ciphertext",
        "//test_hybrid_kem_otbn_prompt_ver1/otbn/mlkem768:poly",
        "//test_hybrid_kem_otbn_prompt_ver1/otbn/mlkem768:poly_gen_matrix",
        "//test_hybrid_kem_otbn_prompt_ver1/otbn/mlkem768:mlkem_encap",
        "//test_hybrid_kem_otbn_prompt_ver1/otbn/mlkem768:kmac_sha3_template",
    ],
)

otbn_sim_test(
    name = "mlkem768_decap_test",
    srcs = ["mlkem_base_decap_test.s"],
    dexp = "dec.dexp",
    deps = [
        "//test_hybrid_kem_otbn_prompt_ver1/otbn/mlkem768:basemul",
        "//test_hybrid_kem_otbn_prompt_ver1/otbn/mlkem768:cbd",
        "//test_hybrid_kem_otbn_prompt_ver1/otbn/mlkem768:intt",
        "//test_hybrid_kem_otbn_prompt_ver1/otbn/mlkem768:ntt",
        "//test_hybrid_kem_otbn_prompt_ver1/otbn/mlkem768:pack_keys",
        "//test_hybrid_kem_otbn_prompt_ver1/otbn/mlkem768:pack_ciphertext",
        "//test_hybrid_kem_otbn_prompt_ver1/otbn/mlkem768:poly",
        "//test_hybrid_kem_otbn_prompt_ver1/otbn/mlkem768:poly_gen_matrix",
        "//test_hybrid_kem_otbn_prompt_ver1/otbn/mlkem768:mlkem_encap",
        "//test_hybrid_kem_otbn_prompt_ver1/otbn/mlkem768:mlkem_decap",
        "//test_hybrid_kem_otbn_prompt_ver1/otbn/mlkem768:kmac_sha3_template",
    ],
)

# ================================================================
# P-256 ECDH
# ================================================================

otbn_sim_test(
    name = "p256_ecdh_test",
    srcs = ["p256_ecdh_shared_key_test.s"],
    dexp = "p256.dexp",
    deps = [
        "//test_hybrid_kem_otbn_prompt_ver1/otbn/p256:p256_base_lib",
        "//test_hybrid_kem_otbn_prompt_ver1/otbn/p256:p256_isoncurve_proj_lib",
        "//test_hybrid_kem_otbn_prompt_ver1/otbn/p256:p256_shared_key_lib",
    ],
)

# ================================================================
# SHA3 / HMAC / HKDF (KMAC hardware, 同 ver2)
# ================================================================

otbn_sim_test(
    name = "sha3_test",
    srcs = ["sha3_test.s"],
    deps = [
        "//test_hybrid_kem_otbn_prompt_ver1/otbn/hkdf:kmac_sha3_lib",
    ],
)

otbn_sim_test(
    name = "hmac_test",
    srcs = ["hmac_test.s"],
    deps = [
        "//test_hybrid_kem_otbn_prompt_ver1/otbn/hkdf:hmac_sha3_lib",
        "//test_hybrid_kem_otbn_prompt_ver1/otbn/hkdf:kmac_sha3_lib",
    ],
)

otbn_sim_test(
    name = "hkdf_test",
    srcs = ["hkdf_test.s"],
    dexp = "hkdf_test.dexp",
    deps = [
        "//test_hybrid_kem_otbn_prompt_ver1/otbn/hkdf:hkdf_sha3_256_lib",
        "//test_hybrid_kem_otbn_prompt_ver1/otbn/hkdf:hmac_sha3_lib",
        "//test_hybrid_kem_otbn_prompt_ver1/otbn/hkdf:kmac_sha3_lib",
    ],
)
