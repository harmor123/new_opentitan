# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# 本版（ver1_1）设备侧的 P-256 接线：**cryptolib 的源码仍用上游（label 引用，不复制一字）**，
# 只把 OTBN app 依赖从 `//sw/otbn/crypto:run_p256` 换成本版的
# `//test_hybrid_kem_otbn_prompt_ver1_1/otbn/p256:run_p256_local`
# （域乘走本目录那份 p256_base.s 的 bn.p256mul）。
# 目的：上游文件一字不动，而 ver1_1 的设备测试（test_p256_only / 三个 phase 测试）
# 跑的是新 app ⇒ 拿到真实的会话级周期与指令数。

load("//rules/opentitan:defs.bzl", "OPENTITAN_CPU")

package(default_visibility = ["//visibility:public"])

cc_library(
    name = "p256_local",
    srcs = ["//sw/device/lib/crypto/impl/ecc:p256.c"],
    hdrs = ["//sw/device/lib/crypto/impl/ecc:p256.h"],
    target_compatible_with = [OPENTITAN_CPU],
    # 与 //sw/device/lib/crypto/impl/ecc:p256 逐项相同，唯一差别是最后一项。
    deps = [
        "//sw/device/lib/base:crc32",
        "//sw/device/lib/base:hardened",
        "//sw/device/lib/base:hardened_memory",
        "//sw/device/lib/crypto/drivers:otbn",
        "//sw/device/lib/crypto/drivers:rv_core_ibex",
        "//sw/device/lib/crypto/impl:integrity",
        "//sw/device/lib/crypto/impl:status",
        "//test_hybrid_kem_otbn_prompt_ver1_1/otbn/p256:run_p256_local",
    ],
)

cc_library(
    name = "ecc_p256_local",
    srcs = ["//sw/device/lib/crypto/impl:ecc_p256.c"],
    hdrs = ["//sw/device/lib/crypto/include:ecc_p256.h"],
    target_compatible_with = [OPENTITAN_CPU],
    # 与 //sw/device/lib/crypto/impl:ecc_p256 逐项相同，唯一差别是把 :p256 换成上面那份。
    deps = [
        "//sw/device/lib/crypto/drivers:hmac",
        "//sw/device/lib/crypto/impl:config",
        "//sw/device/lib/crypto/impl:keyblob",
        "//sw/device/lib/crypto/include:datatypes",
        ":p256_local",
    ],
)
