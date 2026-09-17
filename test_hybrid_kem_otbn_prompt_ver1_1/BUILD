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
