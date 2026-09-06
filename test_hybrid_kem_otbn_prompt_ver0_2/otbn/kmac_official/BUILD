# BUILD — 官方 KMAC XOF 驱动（逐字取自官方 master: sw/otbn/crypto/xof.s）
#
# 用途：验证"官方 OTBN KMAC 驱动"在本工作区（fork RTL + ISS）上可用，
# 为 ver0_2 官方资源基线提供哈希基座。xof.s 与测试文件均未做任何修改。
#
# 运行：bazel test //test_hybrid_kem_otbn_prompt_ver0_2/otbn/kmac_official:all

load("//rules:otbn.bzl", "otbn_binary", "otbn_library", "otbn_sim_test")

package(default_visibility = ["//visibility:public"])

exports_files(["xof.s"])

otbn_library(
    name = "xof",
    srcs = [
        "xof.s",
    ],
)

# co-sim 用：官方 xof 测试的独立 ELF 目标
otbn_binary(
    name = "xof_shake128_test_bin",
    srcs = [
        "tests/xof_shake128_test.s",
        "xof.s",
    ],
)

otbn_binary(
    name = "xof_sha3_256_test_bin",
    srcs = [
        "tests/xof_sha3_256_test.s",
        "xof.s",
    ],
)

otbn_sim_test(
    name = "xof_shake128_test",
    srcs = [
        "tests/xof_shake128_test.s",
    ],
    testcase = "tests/xof_shake128_test.hjson",
    deps = [
        ":xof",
    ],
)

otbn_sim_test(
    name = "xof_shake256_test",
    srcs = [
        "tests/xof_shake256_test.s",
    ],
    testcase = "tests/xof_shake256_test.hjson",
    deps = [
        ":xof",
    ],
)

otbn_sim_test(
    name = "xof_sha3_256_test",
    srcs = [
        "tests/xof_sha3_256_test.s",
    ],
    testcase = "tests/xof_sha3_256_test.hjson",
    deps = [
        ":xof",
    ],
)

otbn_sim_test(
    name = "xof_sha3_512_test",
    srcs = [
        "tests/xof_sha3_512_test.s",
    ],
    testcase = "tests/xof_sha3_512_test.hjson",
    deps = [
        ":xof",
    ],
)
