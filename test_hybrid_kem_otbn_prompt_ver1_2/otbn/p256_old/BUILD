# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("//rules:otbn.bzl", "otbn_binary", "otbn_library")

package(default_visibility = ["//visibility:public"])

# ── 旧侧（未使用折叠指令的 P-256）───────────────────────────────────────────
# 用途：与 `../p256/`（域乘 = 一条 `bn.p256mul`）做**同源对照** —— 同一支测试程序、同一套依赖，
# 唯一差别是 `p256_base.s` 里的 `mul_modp` 函数体。数值口径与设备侧一致：ver0_1→ver1_1 的
# ibex 走的也是官方实现（见 `test_perf/harness_config.yaml` 的 P-256 专表注释）。
#
# `p256_base.s` 是上游 `//sw/otbn/crypto:p256_base.s` 的**逐字节副本**
# （sha256 = 9acc61e4bbbe4d0ba3a68a4160aa75c0a519faa60a64be3f2585da3602d08435，与上游一致；
# 校验：`sha256sum sw/otbn/crypto/p256_base.s`），文件的**任何一个字都没有改**。
#
# ⚠ 分节规则（2026-10-01 立规，检查器 `test_perf/tools/check/check_asm_sections.py`）：
# 同一个目标的 `srcs` 是**一次**汇编（分节状态跨文件延续）⇒ 多文件时每个 `.s` 都必须显式写
# `.text`。本包按上游惯例**一文件一 `otbn_library`**（各自独立汇编）⇒ 段状态不跨文件，天然合规。
otbn_library(
    name = "p256_base_lib",
    srcs = ["p256_base.s"],
)

# ECDH 级自包含测试（app 目标，供 harness 剖面）：srcs/deps 与 `../p256:p256_ecdh_shared_key`
# 逐项相同，只把 `:p256_base_lib` 换成这里这份未折叠的实现。
otbn_binary(
    name = "p256_ecdh_shared_key",
    srcs = ["//test_hybrid_kem_otbn_prompt_ver1_2/otbn/p256:p256_ecdh_shared_key_test.s"],
    deps = [
        ":p256_base_lib",
        "//sw/otbn/crypto:p256_isoncurve",
        "//sw/otbn/crypto:p256_isoncurve_check",
        "//sw/otbn/crypto:p256_isoncurve_proj",
        "//sw/otbn/crypto:p256_shared_key",
    ],
)

# 单函数测试（官方 mul_modp 测试程序）的 app 目标：与 `../p256:p256_mul_modp` 同源。
otbn_binary(
    name = "p256_mul_modp",
    srcs = ["//sw/otbn/crypto/tests:p256_mul_modp_test.s"],
    deps = [
        ":p256_base_lib",
        "//sw/otbn/crypto:p256_isoncurve",
    ],
)
