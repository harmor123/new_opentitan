# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("//rules:otbn.bzl", "otbn_binary", "otbn_library", "otbn_sim_test")

package(default_visibility = ["//visibility:public"])

# ── 新侧：P-256 域乘 = 一条折叠指令 ─────────────────────────────────────────
# **完全自包含**：不引用 `//sw/otbn/crypto` 的任何文件；上游文件的副本都放在本包内，
# 逐字节一致（sha256 前 16 位，2026-10-01 记录；`sha256sum` 可复核）：
#   p256_base.s            240d6738323e3658  ← **本包独有**：上游版本只差 `mul_modp` 函数体
#                                              （换成一条 `bn.p256mul w19, w24, w25` + `ret`）
#   p256_b2a.s             4e5e6dfa688bc92a  上游 sw/otbn/crypto/p256_b2a.s
#   p256_isoncurve.s       20e60989318a3d61
#   p256_isoncurve_check.s 3e8c9e8a7e29d1db
#   p256_isoncurve_proj.s  e57276af1da77d22
#   p256_shared_key.s      f099dff3ff3a19b8
#   p256_a2b.s             7544d2406d06b538
#   p256_mul_modp_test.s   d12f7936f1d5c4da  上游 sw/otbn/crypto/tests/
#   p256_mul_modp_test.exp 364160ebdc37817b  上游 sw/otbn/crypto/tests/
#   测试程序/入口/.dexp：p256_ecdh_shared_key_test.s（与 ver0 同名测试同源）、run_p256_local.s、
#   p256.dexp —— 本就出自本版树，与 `../p256_old/` 逐字节相同。
# 与 `../p256_old/` 的关系：**逐文件、逐目标镜像**，唯一差别是 `p256_base.s` 的 `mul_modp`
# 函数体（1 条 `bn.p256mul` ↔ 53 条软件实现）。
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

# 本版 app：入口是本目录裁剪过的 `run_p256_local.s`（**不含签名/验签路径**：
# MODE_SIGN / MODE_SIGN_CONFIG_K / MODE_VERIFY / MODE_SIDELOAD_SIGN 及其例程已删，
# 11 个模式常量与全部内存符号保留，供 cryptolib 链接期使用）。
#
# ⚠ 目标名必须是 `run_p256`，不能带 `_local` 后缀：`rules/otbn.bzl` 把**目标名**作为
# `--app-name` 传给 `util/otbn_build.py`，而后者按该名字生成宿主侧符号
# （`util/otbn_build.py:326-327`：`_otbn_local_app_<app_name>_*` / `_otbn_remote_app_<app_name>_*`）。
# 设备侧 `sw/device/lib/crypto/impl/ecc/p256.c` 里 app 名写死为 `run_p256`
# （`OTBN_APP_T_INIT(run_p256)` / `OTBN_ADDR_T_INIT(run_p256, …)`，见 `drivers/otbn.h:142,153`）
# ⇒ 目标名不同则符号对不上，链接报 undefined symbol。
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

# 官方单函数金标（`.exp` 在本包内）：同一个测试程序，只把实现的域乘换成本地这份
# ⇒ 用官方期望值直接验证「换掉 mul_modp 函数体之后结果不变」。
otbn_sim_test(
    name = "p256_mul_modp_local_test",
    srcs = ["p256_mul_modp_test.s"],
    exp = "p256_mul_modp_test.exp",
    deps = [
        ":p256_base_lib",
        ":p256_isoncurve_lib",
    ],
)

# ECDH 级：与 ver0 的同名测试同源（测试程序与 `.dexp` 一并放进本版目录），
# 唯一差别是域乘用本地这份 ⇒ 端到端的共享密钥仍必须是 `.dexp` 里那个期望值。
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

# harness 剖面的 app 目标（`test_perf/harness_config.yaml` 的 `p256_ver1_2` 条目；
# 与其他包同一约定：**otbn_binary** + 自包含测试程序入口 —— `bazel cquery --output=files`
# 只有对 binary 才给出 `.elf`）。srcs/deps 与上面两个 `otbn_sim_test` 逐项相同 ⇒ ELF 内的
# 指令与 sim test 完全一致（exp/dexp 只是测试流用的校验）。
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

# 旧侧（未使用折叠指令的对照实现）在**本版树另建一个包**：`../p256_old/` —— 与上面逐文件、
# 逐目标镜像，只有 `p256_base.s` 不同。本包只放"新指令"这一侧。
