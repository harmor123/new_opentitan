# BUILD — OTBN simulation tests (ver0_base pure software)
#
# Uses otbn_sim_test to run each OTBN app on the ISS simulator
# with hardcoded test vectors and verify against expected outputs.
#
# No --bnmulv_version_id=2 copts (baseline OTBN instructions).
# No KMAC hardware dependencies (pure software SHA3).

load("//rules:otbn.bzl", "otbn_sim_test")

package(default_visibility = ["//visibility:public"])

exports_files([
    "mlkem_base_keypair_test.s",
    "mlkem_base_encap_test.s",
    "mlkem_base_decap_test.s",
    "p256_ecdh_shared_key_test.s",
    "kdf_test.s",
    "sha3_test.s",
])

# ================================================================
# ML-KEM-768 KeyPair
# ================================================================

otbn_sim_test(
    name = "mlkem768_keypair_test",
    srcs = ["mlkem_base_keypair_test.s"],
    dexp = "kp.dexp",
    deps = [
        "//test_hybrid_kem_otbn_prompt_ver0/otbn/mlkem768:basemul",
        "//test_hybrid_kem_otbn_prompt_ver0/otbn/mlkem768:cbd",
        "//test_hybrid_kem_otbn_prompt_ver0/otbn/mlkem768:ntt",
        "//test_hybrid_kem_otbn_prompt_ver0/otbn/mlkem768:pack_keys",
        "//test_hybrid_kem_otbn_prompt_ver0/otbn/mlkem768:poly",
        "//test_hybrid_kem_otbn_prompt_ver0/otbn/mlkem768:poly_gen_matrix",
        "//test_hybrid_kem_otbn_prompt_ver0/otbn/mlkem768:mlkem_keypair",
        "//test_hybrid_kem_otbn_prompt_ver0/otbn/mlkem768:sha3_shake",
    ],
)

# ================================================================
# ML-KEM-768 Encap
# ================================================================

otbn_sim_test(
    name = "mlkem768_encap_test",
    srcs = ["mlkem_base_encap_test.s"],
    dexp = "enc.dexp",
    deps = [
        "//test_hybrid_kem_otbn_prompt_ver0/otbn/mlkem768:basemul",
        "//test_hybrid_kem_otbn_prompt_ver0/otbn/mlkem768:cbd",
        "//test_hybrid_kem_otbn_prompt_ver0/otbn/mlkem768:intt",
        "//test_hybrid_kem_otbn_prompt_ver0/otbn/mlkem768:ntt",
        "//test_hybrid_kem_otbn_prompt_ver0/otbn/mlkem768:pack_keys",
        "//test_hybrid_kem_otbn_prompt_ver0/otbn/mlkem768:pack_ciphertext",
        "//test_hybrid_kem_otbn_prompt_ver0/otbn/mlkem768:poly",
        "//test_hybrid_kem_otbn_prompt_ver0/otbn/mlkem768:poly_gen_matrix",
        "//test_hybrid_kem_otbn_prompt_ver0/otbn/mlkem768:mlkem_encap",
        "//test_hybrid_kem_otbn_prompt_ver0/otbn/mlkem768:sha3_shake",
    ],
)

# ================================================================
# ML-KEM-768 Decap
# ================================================================

otbn_sim_test(
    name = "mlkem768_decap_test",
    srcs = ["mlkem_base_decap_test.s"],
    dexp = "dec.dexp",
    deps = [
        "//test_hybrid_kem_otbn_prompt_ver0/otbn/mlkem768:basemul",
        "//test_hybrid_kem_otbn_prompt_ver0/otbn/mlkem768:cbd",
        "//test_hybrid_kem_otbn_prompt_ver0/otbn/mlkem768:intt",
        "//test_hybrid_kem_otbn_prompt_ver0/otbn/mlkem768:ntt",
        "//test_hybrid_kem_otbn_prompt_ver0/otbn/mlkem768:pack_keys",
        "//test_hybrid_kem_otbn_prompt_ver0/otbn/mlkem768:pack_ciphertext",
        "//test_hybrid_kem_otbn_prompt_ver0/otbn/mlkem768:poly",
        "//test_hybrid_kem_otbn_prompt_ver0/otbn/mlkem768:poly_gen_matrix",
        "//test_hybrid_kem_otbn_prompt_ver0/otbn/mlkem768:mlkem_encap",
        "//test_hybrid_kem_otbn_prompt_ver0/otbn/mlkem768:mlkem_decap",
        "//test_hybrid_kem_otbn_prompt_ver0/otbn/mlkem768:sha3_shake",
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
        "//test_hybrid_kem_otbn_prompt_ver0/otbn/p256:p256_base_lib",
        "//test_hybrid_kem_otbn_prompt_ver0/otbn/p256:p256_a2b_lib",
        "//test_hybrid_kem_otbn_prompt_ver0/otbn/p256:p256_isoncurve_proj_lib",
        "//test_hybrid_kem_otbn_prompt_ver0/otbn/p256:p256_shared_key_lib",
    ],
)

# ================================================================
# KMAC-KDF (NIST SP 800-108r1) — software SHAKE256
# ================================================================

otbn_sim_test(
    name = "kdf_test",
    srcs = ["kdf_test.s"],
    dexp = "kdf_test.dexp",
    deps = [
        "//test_hybrid_kem_otbn_prompt_ver0/otbn/hkdf:kmac_kdf_lib",
        "//test_hybrid_kem_otbn_prompt_ver0/otbn/hkdf:sha3_shake_lib",
    ],
)

# ================================================================
# SHA3 / SHAKE (pure software)
# ================================================================

otbn_sim_test(
    name = "sha3_test",
    srcs = ["sha3_test.s"],
    dexp = "sha3_test.dexp",
    deps = [
        "//test_hybrid_kem_otbn_prompt_ver0/otbn/hkdf:sha3_shake_lib",
    ],
)
