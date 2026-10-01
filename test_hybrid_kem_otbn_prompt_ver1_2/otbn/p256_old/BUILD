# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("//rules:otbn.bzl", "otbn_binary", "otbn_library", "otbn_sim_test")

package(default_visibility = ["//visibility:public"])

# ── p256_old = `../p256` 的**逐文件镜像**，只有 `p256_base.s` 不同 ─────────────────
# 本包 = 未使用折叠指令的 P-256（域乘 = 上游软件 `mul_modp`，函数体 53 条）。
# 逐文件对照（除 base 外都是 `../p256/` 的**逐字节副本**，sha256 一致，2026-10-01 复核）：
#   p256_base.s                 = 上游 `sw/otbn/crypto/p256_base.s` 的逐字节副本
#                                 （sha256 9acc61e4…）；`../p256` 那份与它只差 `mul_modp` 函数体
#                                 （1 条 `bn.p256mul` ↔ 53 条软件实现）
#   p256_ecdh_shared_key_test.s = `../p256/` 同名文件副本（sha256 e2175025…；与 ver0 的测试同源）
#   run_p256_local.s            = `../p256/` 同名文件副本（sha256 3529d506…）
#   p256.dexp                   = `../p256/` 同名文件副本（sha256 8cafeaae…）
# 用途：① harness 专表旧侧（`test_perf/harness_config.yaml` 的 `p256_old` 条目：ecdh / mul_modp）；
#      ② 需要设备侧 A/B 时，把设备链路的 app 依赖指到本包 `:run_p256`（app 名必须仍是 run_p256）。
#
# ⚠ 分节规则（2026-10-01 立规，检查器 `test_perf/tools/check/check_asm_sections.py`）：
# 同一目标的 `srcs` 是一次汇编、分节状态跨文件延续 ⇒ `p256_base_lib` 的第一个文件
# `p256_base.s` 结尾停在 `.section .bss`，所以后面那个文件（上游 `p256_b2a.s`）**必须自带
# `.text`**（它有 ✓）。本包的其它 `srcs` 都是单文件。
otbn_library(
    name = "p256_base_lib",
    srcs = [
        "p256_base.s",
        "//sw/otbn/crypto:p256_b2a.s",
    ],
)

# 设备 app（未折叠版）：与 `../p256:run_p256` 同构，只有 base 不同。
# 目标名同样必须是 `run_p256`：cryptolib 的 `OTBN_APP_T_INIT(run_p256)` 按 **app 名**生成宿主
# 符号（见 `../p256/BUILD` 的说明）；改的是实现，来源仍是同一支 `run_p256_local.s`。
otbn_binary(
    name = "run_p256",
    srcs = ["run_p256_local.s"],
    deps = [
        ":p256_base_lib",
        "//sw/otbn/crypto:p256_isoncurve",
        "//sw/otbn/crypto:p256_isoncurve_check",
        "//sw/otbn/crypto:p256_isoncurve_proj",
        "//sw/otbn/crypto:p256_shared_key",
    ],
)

# 官方单函数金标：对未折叠实现 = 原样通过；与 `../p256:p256_mul_modp_local_test` 成对。
otbn_sim_test(
    name = "p256_mul_modp_local_test",
    srcs = ["//sw/otbn/crypto/tests:p256_mul_modp_test.s"],
    exp = "//sw/otbn/crypto/tests:p256_mul_modp_test.exp",
    deps = [
        ":p256_base_lib",
        "//sw/otbn/crypto:p256_isoncurve",
    ],
)

# ECDH 级金标（`.dexp` 期望值）：与 `../p256:p256_ecdh_local_test` 成对。
# 注意：**不要**加 `//sw/otbn/crypto:p256_a2b` —— 上游 `p256_shared_key.s` 自身已含
# `arithmetic_to_boolean*`，再加会 multiple definition（实测报错）。
otbn_sim_test(
    name = "p256_ecdh_local_test",
    srcs = ["p256_ecdh_shared_key_test.s"],
    dexp = "p256.dexp",
    deps = [
        ":p256_base_lib",
        "//sw/otbn/crypto:p256_isoncurve",
        "//sw/otbn/crypto:p256_isoncurve_check",
        "//sw/otbn/crypto:p256_isoncurve_proj",
        "//sw/otbn/crypto:p256_shared_key",
    ],
)

# harness 剖面的 app 目标（专表 `p256_old` 条目）：srcs/deps 与上面两个 sim test 逐项相同。
otbn_binary(
    name = "p256_ecdh_shared_key",
    srcs = ["p256_ecdh_shared_key_test.s"],
    deps = [
        ":p256_base_lib",
        "//sw/otbn/crypto:p256_isoncurve",
        "//sw/otbn/crypto:p256_isoncurve_check",
        "//sw/otbn/crypto:p256_isoncurve_proj",
        "//sw/otbn/crypto:p256_shared_key",
    ],
)

otbn_binary(
    name = "p256_mul_modp",
    srcs = ["//sw/otbn/crypto/tests:p256_mul_modp_test.s"],
    deps = [
        ":p256_base_lib",
        "//sw/otbn/crypto:p256_isoncurve",
    ],
)
