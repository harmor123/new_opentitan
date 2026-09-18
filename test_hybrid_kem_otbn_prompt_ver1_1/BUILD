# BUILD — ver1_1（官方向量指令基线）chip sim 测试
#
# Ibex 侧测试代码逐字复用 ver0_2（app 目标名与内存符号名 coins/ek/dk/ct/ss 相同），
# 因此两版基线的测量口径完全一致，可直接对比周期数与 OTBN 指令数。

load("//rules/opentitan:defs.bzl", "opentitan_test", "EARLGREY_TEST_ENVS", "verilator_params")

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
        "//sw/device/lib/testing:profile",
        "//sw/device/lib/testing/test_framework:check",
        "//sw/device/lib/testing/test_framework:ottf_main",
        "//test_hybrid_kem_otbn_prompt_ver1_1/otbn/mlkem768:mlkem768_keypair",
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
        "//sw/device/lib/testing:profile",
        "//sw/device/lib/testing/test_framework:check",
        "//sw/device/lib/testing/test_framework:ottf_main",
        "//test_hybrid_kem_otbn_prompt_ver1_1/otbn/mlkem768:mlkem768_encap",
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
        "//sw/device/lib/testing:profile",
        "//sw/device/lib/testing/test_framework:check",
        "//sw/device/lib/testing/test_framework:ottf_main",
        "//test_hybrid_kem_otbn_prompt_ver1_1/otbn/mlkem768:mlkem768_decap",
    ],
)

# ---- HKDF 单模块（自包含副本；与 ML-KEM 实现无关，口径完整）----
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
        "//sw/device/lib/testing:profile",
        "//sw/device/lib/testing/test_framework:check",
        "//sw/device/lib/testing/test_framework:ottf_main",
        "//test_hybrid_kem_otbn_prompt_ver1_1/otbn/hkdf:hkdf_sha3_256",
    ],
)

# ---- P-256（官方 cryptolib API，与 ML-KEM 实现无关；为口径完整保留）----
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
        "//sw/device/lib/testing:profile",
        "//sw/device/lib/testing/test_framework:ottf_main",
    ],
)

# ---- Phase 1: Key Generation（端到端）----
# HKDF app 与 ML-KEM 实现无关（同一份代码）；本目录已自带副本，保持 ver1_1 自包含。
opentitan_test(
    name = "phase1_keygen_test",
    srcs = ["ibex/phase1_keygen/phase1_keygen_test.c"],
    exec_env = EARLGREY_TEST_ENVS,
    deps = [
        "//hw/top_earlgrey/sw/autogen:top_earlgrey",
        "//sw/device/lib/dif:otbn",
        "//sw/device/lib/runtime:log",
        "//sw/device/lib/testing:otbn_testutils",
        "//sw/device/lib/testing:profile",
        "//sw/device/lib/testing/test_framework:check",
        "//sw/device/lib/testing/test_framework:ottf_main",
        "//sw/device/lib/crypto/impl:config",
        "//sw/device/lib/crypto/impl:ecc_p256",
        "//sw/device/lib/crypto/impl:entropy_src",
        "//sw/device/lib/testing:entropy_testutils",
        "//test_hybrid_kem_otbn_prompt_ver1_1/otbn/mlkem768:mlkem768_keypair",
    ],
)

# ---- Phase 2: Alice / Bob（端到端）----
opentitan_test(
    name = "phase2_alice_encap_test",
    srcs = ["ibex/phase2_encap_decap/phase2_alice_encap.c"],
    exec_env = EARLGREY_TEST_ENVS,
    deps = [
        "//hw/top_earlgrey/sw/autogen:top_earlgrey",

        "//sw/device/lib/crypto/drivers:otbn",
        "//sw/device/lib/crypto/impl:config",
        "//sw/device/lib/crypto/impl:ecc_p256",
        "//sw/device/lib/crypto/impl:integrity",
        "//sw/device/lib/crypto/impl:key_transport",

        "//sw/device/lib/dif:otbn",
        "//sw/device/lib/runtime:log",
        "//sw/device/lib/testing:entropy_testutils",
        "//sw/device/lib/testing:otbn_testutils",
        "//sw/device/lib/testing:profile",
        "//sw/device/lib/testing/test_framework:check",
        "//sw/device/lib/testing/test_framework:ottf_main",

        "//test_hybrid_kem_otbn_prompt_ver1_1/otbn/mlkem768:mlkem768_encap",
        "//test_hybrid_kem_otbn_prompt_ver1_1/otbn/hkdf:hkdf_sha3_256",
    ],
)

opentitan_test(
    name = "phase2_bob_decap_test",
    srcs = ["ibex/phase2_encap_decap/phase2_bob_decap.c"],
    exec_env = EARLGREY_TEST_ENVS,
    deps = [
        "//hw/top_earlgrey/sw/autogen:top_earlgrey",

        "//sw/device/lib/crypto/drivers:otbn",
        "//sw/device/lib/crypto/impl:config",
        "//sw/device/lib/crypto/impl:ecc_p256",
        "//sw/device/lib/crypto/impl:integrity",
        "//sw/device/lib/crypto/impl:key_transport",

        "//sw/device/lib/dif:otbn",
        "//sw/device/lib/runtime:log",
        "//sw/device/lib/testing:entropy_testutils",
        "//sw/device/lib/testing:otbn_testutils",
        "//sw/device/lib/testing:profile",
        "//sw/device/lib/testing/test_framework:check",
        "//sw/device/lib/testing/test_framework:ottf_main",

        "//test_hybrid_kem_otbn_prompt_ver1_1/otbn/mlkem768:mlkem768_decap",
        "//test_hybrid_kem_otbn_prompt_ver1_1/otbn/hkdf:hkdf_sha3_256",
    ],
)
