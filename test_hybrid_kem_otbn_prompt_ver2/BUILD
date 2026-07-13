# ================================================================
# BUILD — Hybrid KEM test following otbn_mlkem_test.c pattern
#        from "Improving ML-KEM & ML-DSA on OpenTitan" (2025).
#
# One test binary links all OTBN binaries + C reference.
# Primary target: FPGA (not Verilator chip sim).
# ================================================================

load("//rules/opentitan:defs.bzl", "opentitan_test",
     "EARLGREY_TEST_ENVS", "EARLGREY_SILICON_OWNER_ROM_EXT_ENVS",
     "verilator_params")
load("@bazel_skylib//lib:dicts.bzl", "dicts")

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
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/hkdf:hkdf_sha3_256",
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
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/hkdf:hkdf_sha3_256",
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
    name = "test_hkdf_only",
    srcs = ["ibex/test_hkdf_only.c"],
    exec_env = EARLGREY_TEST_ENVS,
    deps = [
        "//hw/top/dt",
        "//sw/device/lib/dif:otbn",
        "//sw/device/lib/runtime:log",
        "//sw/device/lib/testing:entropy_testutils",
        "//sw/device/lib/testing:otbn_testutils",
        "//sw/device/lib/testing/test_framework:check",
        "//sw/device/lib/testing/test_framework:ottf_main",
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/hkdf:hkdf_sha3_256",
    ],
)

opentitan_test(
    name = "test_p256_official",
    srcs = ["ibex/test_p256_official.c"],
    exec_env = EARLGREY_TEST_ENVS,
    deps = [
        "//hw/top/dt",
        "//sw/device/lib/dif:otbn",
        "//sw/device/lib/runtime:log",
        "//sw/device/lib/testing:entropy_testutils",
        "//sw/device/lib/testing:otbn_testutils",
        "//sw/device/lib/testing/test_framework:check",
        "//sw/device/lib/testing/test_framework:ottf_main",
        "//sw/otbn/crypto:run_p256",
    ],
)

# ---- C Reference Library ----
cc_library(
    name = "hybrid_kem_ref",
    srcs = ["ref/hybrid_kem_ref.c"],
    hdrs = ["ref/hybrid_kem_ref.h"],
    deps = [
        "//sw/device/lib/base:memory",
    ],
)

# ---- Ibex Test ----
opentitan_test(
    name = "hybrid_kem_test",
    srcs = ["ibex/hybrid_kem_test.c"],
    exec_env = dicts.add(
        EARLGREY_TEST_ENVS,
        EARLGREY_SILICON_OWNER_ROM_EXT_ENVS,
        {
            "//hw/top_earlgrey:fpga_cw310_sival": None,
            "//hw/top_earlgrey:fpga_cw310_sival_rom_ext": None,
            "//hw/top_earlgrey:silicon_creator": None,
        },
    ),
    verilator = verilator_params(timeout = "long"),
    deps = [
        ":hybrid_kem_ref",
        "//hw/top/dt",
        "//sw/device/lib/dif:otbn",
        "//sw/device/lib/runtime:ibex",
        "//sw/device/lib/runtime:log",
        "//sw/device/lib/testing:entropy_testutils",
        "//sw/device/lib/testing:otbn_testutils",
        "//sw/device/lib/testing/test_framework:check",
        "//sw/device/lib/testing/test_framework:ottf_main",
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/p256:p256_ecdh",
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/mlkem768:mlkem768_keypair",
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/mlkem768:mlkem768_encap",
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/mlkem768:mlkem768_decap",
        "//test_hybrid_kem_otbn_prompt_ver2/otbn/hkdf:hkdf_sha3_256",
    ],
)
