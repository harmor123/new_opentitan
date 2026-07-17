# ================================================================
# BUILD — Hybrid KEM test following otbn_mlkem_test.c pattern
#        from "Improving ML-KEM & ML-DSA on OpenTitan" (2025).
#
# One test binary links all OTBN binaries + C reference.
# Primary target: FPGA (not Verilator chip sim).
# ================================================================

load("//rules/opentitan:defs.bzl", "opentitan_test",
     "EARLGREY_TEST_ENVS")

package(default_visibility = ["//visibility:public"])

# ================================================================
# Single-binary chip sim tests (one OTBN binary per firmware)
# ================================================================

opentitan_test(
    name = "test_p256_only",
    srcs = ["ibex/test_p256_only.c"],
    exec_env = EARLGREY_TEST_ENVS,
    deps = [
        "//hw/top/dt",
        "//sw/device/lib/dif:otbn",
        "//sw/device/lib/runtime:log",
        "//sw/device/lib/testing:entropy_testutils",
        "//sw/device/lib/testing:otbn_testutils",
        "//sw/device/lib/testing/test_framework:check",
        "//sw/device/lib/testing/test_framework:ottf_main",
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/p256:p256_ecdh_shared_key",
    ],
)

# ---- Phase 1: Key Generation (P-256 + ML-KEM) ----
opentitan_test(
    name = "phase1_keygen_test",
    srcs = ["ibex/phase1_keygen/phase1_keygen_test.c"],
    exec_env = EARLGREY_TEST_ENVS,
    deps = [
        "//hw/top/dt",
        "//sw/device/lib/dif:otbn",
        "//sw/device/lib/runtime:log",
        "//sw/device/lib/testing:entropy_testutils",
        "//sw/device/lib/testing:otbn_testutils",
        "//sw/device/lib/testing/test_framework:check",
        "//sw/device/lib/testing/test_framework:ottf_main",
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/p256:p256_ecdh_shared_key",
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/mlkem768:mlkem768_keypair",
    ],
)

# ---- Phase 2: Alice Encapsulation ----
opentitan_test(
    name = "phase2_alice_encap_test",
    srcs = ["ibex/phase2_encap_decap/phase2_alice_encap.c"],
    exec_env = EARLGREY_TEST_ENVS,
    deps = [
        "//hw/top/dt",
        "//sw/device/lib/dif:otbn",
        "//sw/device/lib/runtime:log",
        "//sw/device/lib/testing:entropy_testutils",
        "//sw/device/lib/testing:otbn_testutils",
        "//sw/device/lib/testing/test_framework:check",
        "//sw/device/lib/testing/test_framework:ottf_main",
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/p256:p256_ecdh_shared_key",
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/mlkem768:mlkem768_encap",
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/kmac:kmac_kdf",
    ],
)

# ---- Phase 2: Bob Decapsulation ----
opentitan_test(
    name = "phase2_bob_decap_test",
    srcs = ["ibex/phase2_encap_decap/phase2_bob_decap.c"],
    exec_env = EARLGREY_TEST_ENVS,
    deps = [
        "//hw/top/dt",
        "//sw/device/lib/dif:otbn",
        "//sw/device/lib/runtime:log",
        "//sw/device/lib/testing:entropy_testutils",
        "//sw/device/lib/testing:otbn_testutils",
        "//sw/device/lib/testing/test_framework:check",
        "//sw/device/lib/testing/test_framework:ottf_main",
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/p256:p256_ecdh_shared_key",
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/mlkem768:mlkem768_decap",
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/kmac:kmac_kdf",
    ],
)

opentitan_test(
    name = "test_mlkem_keypair_only",
    srcs = ["ibex/test_mlkem_keypair_only.c"],
    exec_env = EARLGREY_TEST_ENVS,
    deps = [
        "//hw/top/dt",
        "//sw/device/lib/dif:otbn",
        "//sw/device/lib/runtime:log",
        "//sw/device/lib/testing:entropy_testutils",
        "//sw/device/lib/testing:otbn_testutils",
        "//sw/device/lib/testing/test_framework:check",
        "//sw/device/lib/testing/test_framework:ottf_main",
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/mlkem768:mlkem768_keypair",
    ],
)

opentitan_test(
    name = "test_mlkem_encap_only",
    srcs = ["ibex/test_mlkem_encap_only.c"],
    exec_env = EARLGREY_TEST_ENVS,
    deps = [
        "//hw/top/dt",
        "//sw/device/lib/dif:otbn",
        "//sw/device/lib/runtime:log",
        "//sw/device/lib/testing:entropy_testutils",
        "//sw/device/lib/testing:otbn_testutils",
        "//sw/device/lib/testing/test_framework:check",
        "//sw/device/lib/testing/test_framework:ottf_main",
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/mlkem768:mlkem768_encap",
    ],
)

opentitan_test(
    name = "test_mlkem_decap_only",
    srcs = ["ibex/test_mlkem_decap_only.c"],
    exec_env = EARLGREY_TEST_ENVS,
    deps = [
        "//hw/top/dt",
        "//sw/device/lib/dif:otbn",
        "//sw/device/lib/runtime:log",
        "//sw/device/lib/testing:entropy_testutils",
        "//sw/device/lib/testing:otbn_testutils",
        "//sw/device/lib/testing/test_framework:check",
        "//sw/device/lib/testing/test_framework:ottf_main",
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/mlkem768:mlkem768_decap",
    ],
)

opentitan_test(
    name = "test_kdf_only",
    srcs = ["ibex/test_kdf_only.c"],
    exec_env = EARLGREY_TEST_ENVS,
    deps = [
        "//hw/top/dt",
        "//sw/device/lib/dif:otbn",
        "//sw/device/lib/runtime:log",
        "//sw/device/lib/testing:entropy_testutils",
        "//sw/device/lib/testing:otbn_testutils",
        "//sw/device/lib/testing/test_framework:check",
        "//sw/device/lib/testing/test_framework:ottf_main",
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/kmac:kmac_kdf",
    ],
)

