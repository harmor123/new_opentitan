# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("//rules:otbn.bzl", "otbn_binary", "otbn_library")

package(default_visibility = ["//visibility:public"])

# ver1_1 本地的 P-256 域乘：与上游 `sw/otbn/crypto/p256_base.s` **只差 `mul_modp` 的函数体**
# （换成一条 `bn.p256mul w19, w24, w25` + `ret`）。上游文件一字不动；本文件的生成方式是
# 「按行拼接、只替换 419–561」并由脚本逐字节校验前后缀一致（见 run_dir/rtl/ 的记录）。
#
# 其余 P-256 文件仍用上游（用 label 指过去，不做多余的副本）。
otbn_library(
    name = "p256_base_lib",
    srcs = ["p256_base.s"],
)

# 本版 app：入口是本目录裁剪过的 `run_p256_local.s`（**不含签名/验签路径**：
# MODE_SIGN / MODE_SIGN_CONFIG_K / MODE_VERIFY / MODE_SIDELOAD_SIGN 及其例程已删，
# 11 个模式常量与全部内存符号保留，供 cryptolib 链接期使用）。
# 依赖 = 上游 `run_p256` 去掉 `p256_sign` / `p256_verify`，并把 `p256_base` 换成本地实现。
otbn_binary(
    name = "run_p256_local",
    srcs = ["run_p256_local.s"],
    deps = [
        ":p256_base_lib",
        "//sw/otbn/crypto:p256_isoncurve",
        "//sw/otbn/crypto:p256_isoncurve_check",
        "//sw/otbn/crypto:p256_isoncurve_proj",
        "//sw/otbn/crypto:p256_shared_key",
    ],
)
