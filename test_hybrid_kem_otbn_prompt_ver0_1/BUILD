load("//rules/opentitan:defs.bzl", "opentitan_test", "EARLGREY_TEST_ENVS", "verilator_params")
load("@bazel_skylib//lib:dicts.bzl", "dicts")

package(default_visibility = ["//visibility:public"])

# ---- Standalone Tests ----
opentitan_test(
    name = "test_mlkem_keypair_only",
    srcs = ["ibex/test_mlkem_keypair_only.c"],
    exec_env = EARLGREY_TEST_ENVS,
    deps = [
        "//hw/top_earlgrey/sw/autogen:top_earlgrey",
        "//sw/device/lib/dif:otbn",
        "//sw/device/lib/runtime:log",
        "//sw/device/lib/testing:entropy_testutils",
        "//sw/device/lib/testing:otbn_testutils",
        "//sw/device/lib/testing/test_framework:check",
        "//sw/device/lib/testing/test_framework:ottf_main",
        "//test_hybrid_kem_otbn_prompt_ver0_1/otbn/mlkem768:mlkem768_keypair",
    ],
)

opentitan_test(
    name = "test_mlkem_encap_only",
    srcs = ["ibex/test_mlkem_encap_only.c"],
    exec_env = EARLGREY_TEST_ENVS,
    deps = [
        "//hw/top_earlgrey/sw/autogen:top_earlgrey",
        "//sw/device/lib/dif:otbn",
        "//sw/device/lib/runtime:log",
        "//sw/device/lib/testing:entropy_testutils",
        "//sw/device/lib/testing:otbn_testutils",
        "//sw/device/lib/testing/test_framework:check",
        "//sw/device/lib/testing/test_framework:ottf_main",
        "//test_hybrid_kem_otbn_prompt_ver0_1/otbn/mlkem768:mlkem768_encap",
    ],
)

opentitan_test(
    name = "test_mlkem_decap_only",
    srcs = ["ibex/test_mlkem_decap_only.c"],
    exec_env = EARLGREY_TEST_ENVS,
    deps = [
        "//hw/top_earlgrey/sw/autogen:top_earlgrey",
        "//sw/device/lib/dif:otbn",
        "//sw/device/lib/runtime:log",
        "//sw/device/lib/testing:entropy_testutils",
        "//sw/device/lib/testing:otbn_testutils",
        "//sw/device/lib/testing/test_framework:check",
        "//sw/device/lib/testing/test_framework:ottf_main",
        "//test_hybrid_kem_otbn_prompt_ver0_1/otbn/mlkem768:mlkem768_decap",
    ],
)

opentitan_test(
    name = "test_p256_only",
    srcs = ["ibex/test_p256_only.c"],
    exec_env = EARLGREY_TEST_ENVS,
    deps = [
        "//sw/device/lib/base:hardened_memory",
        "//sw/device/lib/crypto/drivers:otbn",
        "//sw/device/lib/crypto/impl:config",
        "//sw/device/lib/crypto/impl:ecc_p256",
        "//sw/device/lib/crypto/impl:entropy_src",
        "//sw/device/lib/crypto/impl:key_transport",
        "//sw/device/lib/runtime:log",
        "//sw/device/lib/testing/test_framework:ottf_main",
    ],
)

opentitan_test(
    name = "test_hkdf_only",
    srcs = ["ibex/test_hkdf_only.c"],
    exec_env = EARLGREY_TEST_ENVS,
    deps = [
        "//hw/top_earlgrey/sw/autogen:top_earlgrey",
        "//sw/device/lib/dif:otbn",
        "//sw/device/lib/runtime:log",
        "//sw/device/lib/testing:entropy_testutils",
        "//sw/device/lib/testing:otbn_testutils",
        "//sw/device/lib/testing/test_framework:check",
        "//sw/device/lib/testing/test_framework:ottf_main",
        "//test_hybrid_kem_otbn_prompt_ver0_1/otbn/hkdf:hkdf_sha3_256",
    ],
)

# ---- Phase 1: Key Generation ----
opentitan_test(
    name = "phase1_keygen_test",
    srcs = ["ibex/phase1_keygen/phase1_keygen_test.c"],
    exec_env = EARLGREY_TEST_ENVS,
    deps = [
        "//hw/top_earlgrey/sw/autogen:top_earlgrey",
        "//sw/device/lib/dif:otbn",
        "//sw/device/lib/runtime:log",
        "//sw/device/lib/testing:entropy_testutils",
        "//sw/device/lib/testing:otbn_testutils",
        "//sw/device/lib/testing:profile",
        "//sw/device/lib/testing/test_framework:check",
        "//sw/device/lib/testing/test_framework:ottf_main",
        "//test_hybrid_kem_otbn_prompt_ver0_1/otbn/p256:p256_keygen",
        "//test_hybrid_kem_otbn_prompt_ver0_1/otbn/mlkem768:mlkem768_keypair",
    ],
)

# ---- Phase 2: Alice / Bob ----
opentitan_test(
    name = "phase2_alice_encap_test",
    srcs = ["ibex/phase2_encap_decap/phase2_alice_encap.c"],
    exec_env = EARLGREY_TEST_ENVS,
    deps = [
        "//hw/top_earlgrey/sw/autogen:top_earlgrey",
        "//sw/device/lib/dif:otbn",
        "//sw/device/lib/runtime:log",
        "//sw/device/lib/testing:entropy_testutils",
        "//sw/device/lib/testing:otbn_testutils",
        "//sw/device/lib/testing:profile",
        "//sw/device/lib/testing/test_framework:check",
        "//sw/device/lib/testing/test_framework:ottf_main",
        "//test_hybrid_kem_otbn_prompt_ver0_1/otbn/p256:p256_keygen",
        "//test_hybrid_kem_otbn_prompt_ver0_1/otbn/p256:p256_ecdh_shared_key",
        "//test_hybrid_kem_otbn_prompt_ver0_1/otbn/mlkem768:mlkem768_encap",
        "//test_hybrid_kem_otbn_prompt_ver0_1/otbn/hkdf:hkdf_sha3_256",
    ],
)

opentitan_test(
    name = "phase2_bob_decap_test",
    srcs = ["ibex/phase2_encap_decap/phase2_bob_decap.c"],
    exec_env = EARLGREY_TEST_ENVS,
    deps = [
        "//hw/top_earlgrey/sw/autogen:top_earlgrey",
        "//sw/device/lib/dif:otbn",
        "//sw/device/lib/runtime:log",
        "//sw/device/lib/testing:entropy_testutils",
        "//sw/device/lib/testing:otbn_testutils",
        "//sw/device/lib/testing:profile",
        "//sw/device/lib/testing/test_framework:check",
        "//sw/device/lib/testing/test_framework:ottf_main",
        "//test_hybrid_kem_otbn_prompt_ver0_1/otbn/p256:p256_ecdh_shared_key",
        "//test_hybrid_kem_otbn_prompt_ver0_1/otbn/mlkem768:mlkem768_decap",
        "//test_hybrid_kem_otbn_prompt_ver0_1/otbn/hkdf:hkdf_sha3_256",
    ],
)
