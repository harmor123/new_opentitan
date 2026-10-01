# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("//rules:otbn.bzl", "otbn_binary", "otbn_library", "otbn_sim_test")

package(default_visibility = ["//visibility:public"])

# ── 旧侧：P-256 域乘 = 软件 `mul_modp`（函数体 53 条）──────────────────────
# **完全自包含**：不引用 `//sw/otbn/crypto` 的任何文件；上游文件的副本都放在本包内，
# 逐字节一致（sha256 前 16 位，2026-10-01 记录；`sha256sum` 可复核）：
#   p256_base.s            9acc61e4bbbe4d0b  ← **本包独有**：上游 p256_base.s 原样（未折叠）
#   p256_b2a.s             4e5e6dfa688bc92a  上游 sw/otbn/crypto/p256_b2a.s
#   p256_isoncurve.s       20e60989318a3d61
#   p256_isoncurve_check.s 3e8c9e8a7e29d1db
#   p256_isoncurve_proj.s  e57276af1da77d22
#   p256_shared_key.s      f099dff3ff3a19b8
#   p256_a2b.s             7544d2406d06b538
#   p256_mul_modp_test.s   d12f7936f1d5c4da  上游 sw/otbn/crypto/tests/
#   p256_mul_modp_test.exp 364160ebdc37817b  上游 sw/otbn/crypto/tests/
#   测试程序/入口/.dexp：p256_ecdh_shared_key_test.s（与 ver0 同名测试同源）、run_p256_local.s、
#   p256.dexp —— 本就出自本版树，与 `../p256/` 逐字节相同。
# 与 `../p256/` 的关系：**逐文件、逐目标镜像**，唯一差别是 `p256_base.s` 的 `mul_modp`
# 函数体（53 条软件实现 ↔ 1 条 `bn.p256mul`）。
# 用途：① harness 专表旧侧（`test_perf/harness_config.yaml` 的 `p256_old` 条目：ecdh / mul_modp）；
#      ② 需要设备侧 A/B 时，把设备链路的 app 依赖指到本包 `:run_p256`（app 名必须仍是 run_p256）。
#
# ⚠ 分节规则（2026-10-01 立规，检查器 `test_perf/tools/check/check_asm_sections.py`）：
# 同一目标的 `srcs` 是一次汇编、**分节状态跨文件延续** ⇒ 多文件 `srcs` 里每个文件都要显式写
# `.text`。本包 `p256_base_lib` 的两个文件都符合（`p256_base.s` 自带 `.text`；`p256_b2a.s`
# 也自带 `.text`），其余库都是单文件。
otbn_library(
    name = "p256_base_lib",
    srcs = [
        "p256_base.s",
        "p256_b2a.s",
    ],
)

otbn_library(name = "p256_isoncurve_lib", srcs = ["p256_isoncurve.s"])
otbn_library(name = "p256_isoncurve_check_lib", srcs = ["p256_isoncurve_check.s"])
otbn_library(name = "p256_isoncurve_proj_lib", srcs = ["p256_isoncurve_proj.s"])
otbn_library(name = "p256_shared_key_lib", srcs = ["p256_a2b.s", "p256_shared_key.s"])

# 设备 app（未折叠版）：与 `../p256:run_p256` 同构，只有 base 不同。
# 目标名同样必须是 `run_p256`：cryptolib 的 `OTBN_APP_T_INIT(run_p256)` 按 **app 名**生成宿主
# 符号（原因见 `../p256/BUILD`）；来源仍是同一支 `run_p256_local.s`。
otbn_binary(
    name = "run_p256",
    srcs = ["run_p256_local.s"],
    deps = [
        ":p256_base_lib",
        ":p256_isoncurve_lib",
        ":p256_isoncurve_check_lib",
        ":p256_isoncurve_proj_lib",
        ":p256_shared_key_lib",
    ],
)

# 官方单函数金标（`.exp` 在本包内）：对未折叠实现 = 原样通过；
# 与 `../p256:p256_mul_modp_local_test` 成对。
otbn_sim_test(
    name = "p256_mul_modp_local_test",
    srcs = ["p256_mul_modp_test.s"],
    exp = "p256_mul_modp_test.exp",
    deps = [
        ":p256_base_lib",
        ":p256_isoncurve_lib",
    ],
)

# ECDH 级金标（`.dexp` 期望值）：与 `../p256:p256_ecdh_local_test` 成对。
# 注意：**不要**再加 `p256_a2b.s` 的独立库 —— `p256_shared_key_lib` 已含
# `arithmetic_to_boolean*`，重复引入会 multiple definition（实测报错）。
otbn_sim_test(
    name = "p256_ecdh_local_test",
    srcs = ["p256_ecdh_shared_key_test.s"],
    dexp = "p256.dexp",
    deps = [
        ":p256_base_lib",
        ":p256_isoncurve_lib",
        ":p256_isoncurve_check_lib",
        ":p256_isoncurve_proj_lib",
        ":p256_shared_key_lib",
    ],
)

# harness 剖面的 app 目标（专表 `p256_old` 条目）：srcs/deps 与上面两个 sim test 逐项相同。
otbn_binary(
    name = "p256_ecdh_shared_key",
    srcs = ["p256_ecdh_shared_key_test.s"],
    deps = [
        ":p256_base_lib",
        ":p256_isoncurve_lib",
        ":p256_isoncurve_check_lib",
        ":p256_isoncurve_proj_lib",
        ":p256_shared_key_lib",
    ],
)

otbn_binary(
    name = "p256_mul_modp",
    srcs = ["p256_mul_modp_test.s"],
    deps = [
        ":p256_base_lib",
        ":p256_isoncurve_lib",
    ],
)
