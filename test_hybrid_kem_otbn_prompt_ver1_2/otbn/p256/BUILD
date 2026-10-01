# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("//rules:otbn.bzl", "otbn_binary", "otbn_library", "otbn_sim_test")

package(default_visibility = ["//visibility:public"])

# ── 新侧：P-256 域乘 = 一条折叠指令（`bn.p256mul`）──────────────────────
# 包里是 **ECDH 闭环所需的最小自包含集**（不引用 `//sw/otbn/crypto`）。逐文件来历与用处：
#   p256_base.s                 本包主角：上游 `p256_base.s` 只差 `mul_modp` 函数体
#   p256_b2a.s                  链接必需：`p256_base.s` 的 `p256_key_from_seed` 调
#                               `boolean_to_arithmetic`（OTBN 链接按文件、不做未用函数回收）
#   p256_isoncurve.s            链接必需：`p256_base.s` 调 `p256_isoncurve`；设备 app 调
#                               `p256_check_public_key`
#   p256_isoncurve_proj.s       ECDH 的曲线自检（`p256_shared_key` 调）
#   p256_shared_key.s           ECDH 共享密钥例程
#   p256_a2b.s                  `p256_shared_key.s` 的一部分（`arithmetic_to_boolean*`）
#   p256_ecdh_shared_key_test.s ECDH 测试程序（与 ver0 的同名测试同源）
#   p256.dexp                   ECDH 期望值（sim test 用）
#   p256_mul_modp_test.s        单函数 app 的测试程序（域乘本身）
#   run_p256_local.s            设备 app 入口（裁剪掉签名/验签路径）
# 上游文件均为**逐字节副本**（sha256 前 16 位，2026-10-01 记录；`sha256sum` 可复核）：
#   b2a 4e5e6dfa688bc92a · isoncurve 20e60989318a3d61 · isoncurve_proj e57276af1da77d22 ·
#   shared_key f099dff3ff3a19b8 · a2b 7544d2406d06b538 · mul_modp_test.s d12f7936f1d5c4da
# 注：上游 `p256_isoncurve_check.s` **不在包里** —— 它的符号（`p256_check_isoncurve` /
#     `p256_not_on_curve`）在本闭环里无人引用（符号引用分析核对过）。
# 与 `../p256_old/` 的关系：唯一差别是 `p256_base.s` 的 `mul_modp` 函数体
# （1 条 `bn.p256mul` ↔ 53 条软件实现）；p256_old 不含设备 app（只供 ECDH 对照）。
#
# ⚠ 分节规则（2026-10-01 立规，检查器 `test_perf/tools/check/check_asm_sections.py`）：
# 同一目标的 `srcs` 是一次汇编、**分节状态跨文件延续** ⇒ 多文件 `srcs` 里每个文件都要显式写
# `.text`。本包两个多文件库（base+b2a、a2b+shared_key）里的文件都自带 `.text`。
otbn_library(
    name = "p256_base_lib",
    srcs = [
        "p256_base.s",
        "p256_b2a.s",
    ],
)

otbn_library(name = "p256_isoncurve_lib", srcs = ["p256_isoncurve.s"])
otbn_library(name = "p256_isoncurve_proj_lib", srcs = ["p256_isoncurve_proj.s"])
otbn_library(name = "p256_shared_key_lib", srcs = ["p256_a2b.s", "p256_shared_key.s"])

# 本版设备 app：入口是本目录裁剪过的 `run_p256_local.s`（不含签名/验签路径）。
# ⚠ 目标名必须是 `run_p256`，不能带 `_local` 后缀：`rules/otbn.bzl` 把**目标名**作为
# `--app-name` 传给 `util/otbn_build.py`，而后者按该名字生成宿主侧符号
# （`util/otbn_build.py:326-327`）；设备侧 `sw/device/lib/crypto/impl/ecc/p256.c` 里 app 名
# 写死为 `run_p256`（`OTBN_APP_T_INIT(run_p256)`，见 `drivers/otbn.h:142,153`）⇒ 名字不同则
# 链接报 undefined symbol。
otbn_binary(
    name = "run_p256",
    srcs = ["run_p256_local.s"],
    deps = [
        ":p256_base_lib",
        ":p256_isoncurve_lib",
        ":p256_isoncurve_proj_lib",
        ":p256_shared_key_lib",
    ],
)

# ECDH 级金标（`.dexp` 期望值）：端到端的共享密钥必须是 `.dexp` 里那个值。
# 注意：**不要**再加单独一份 `p256_a2b.s` 的库 —— `p256_shared_key_lib` 已含
# `arithmetic_to_boolean*`，重复引入会 multiple definition（实测报错）。
otbn_sim_test(
    name = "p256_ecdh_local_test",
    srcs = ["p256_ecdh_shared_key_test.s"],
    dexp = "p256.dexp",
    deps = [
        ":p256_base_lib",
        ":p256_isoncurve_lib",
        ":p256_isoncurve_proj_lib",
        ":p256_shared_key_lib",
    ],
)

# harness 剖面的 app 目标（`test_perf/harness_config.yaml` 的 `p256_ver1_2` 条目）：
# **otbn_binary** + 自包含测试程序入口（`bazel cquery --output=files` 只对 binary 给出 `.elf`）。
otbn_binary(
    name = "p256_ecdh_shared_key",
    srcs = ["p256_ecdh_shared_key_test.s"],
    deps = [
        ":p256_base_lib",
        ":p256_isoncurve_lib",
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

# 旧侧（未使用折叠指令的对照实现）在**本版树另建一个包**：`../p256_old/` —— 与上面同一套文件，
# 只把 `p256_base.s` 换成未折叠那份。本包只放"新指令"这一侧。
