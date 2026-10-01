# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("//rules:otbn.bzl", "otbn_binary", "otbn_library", "otbn_sim_test")

package(default_visibility = ["//visibility:public"])

# ── 旧侧：P-256 域乘 = 软件 `mul_modp`（函数体 53 条）──────────────────────
# 包里是 **ECDH 闭环所需的最小自包含集**（不引用 `//sw/otbn/crypto`）。逐文件来历与用处：
#   p256_base.s                 本包主角：上游 `p256_base.s` 原样（未折叠）
#   p256_b2a.s                  链接必需：`p256_base.s` 的 `p256_key_from_seed` 调
#                               `boolean_to_arithmetic`（OTBN 链接按文件、不做未用函数回收）
#   p256_isoncurve.s            链接必需：`p256_base.s` 调 `p256_isoncurve`
#   p256_isoncurve_proj.s       ECDH 的曲线自检（`p256_shared_key` 调）
#   p256_shared_key.s           ECDH 共享密钥例程
#   p256_a2b.s                  `p256_shared_key.s` 的一部分（`arithmetic_to_boolean*`）
#   p256_ecdh_shared_key_test.s ECDH 测试程序（与 ver0 的同名测试同源）
#   p256_ecdh_key.exp           期望寄存器：w11 = 解出的共享密钥（见下方 sim test 的说明；
#                               不用 `../p256/p256.dexp`，那个查的是掩码份额、URND 相关）
#   p256_mul_modp_test.s        单函数 app 的测试程序（域乘本身）
# 上游文件均为**逐字节副本**（sha256 前 16 位，2026-10-01 记录；`sha256sum` 可复核）：
#   base 9acc61e4bbbe4d0b（与上游一致，未折叠）· b2a 4e5e6dfa688bc92a ·
#   isoncurve 20e60989318a3d61 · isoncurve_proj e57276af1da77d22 ·
#   shared_key f099dff3ff3a19b8 · a2b 7544d2406d06b538 · mul_modp_test.s d12f7936f1d5c4da
# 注：不含 `run_p256_local.s`（本包只供 ECDH 对照，不做设备 app）；也不含上游
#     `p256_isoncurve_check.s`（其符号在本闭环里无人引用）。
# 与 `../p256/` 的关系：唯一差别是 `p256_base.s` 的 `mul_modp` 函数体
# （53 条软件实现 ↔ 1 条 `bn.p256mul`）。
# 用途：harness 专表旧侧（`test_perf/harness_config.yaml` 的 `p256_old` 条目：ecdh / mul_modp）。
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

# ECDH 级金标：查 **w11 = 解出的共享密钥**（URND 无关）。
# 为什么不用 `../p256/p256.dexp`：那个 dexp 查 **掩码份额**（dmem x/y），份额由 URND 决定；
# ISS 的 URND 每拍推进，而两个实现拍数不同（53 条 vs 1 条 + 27 停滞）⇒ 收到的随机值不同
# ⇒ 份额必然不同（2026-10-01 实测：本测试跑 dexp 报 dmem x/y 不匹配）。两侧份额各自异或出的
# **密钥相同**（0x4a67a980…5281 ✓）—— 与上游官方 ECDH 测试"只查 w11"同一口径。
# 期望值来历（非自证）：由 `../p256/p256.dexp` 的两组份额按 little-endian
# （`dmem.py:169 load_u256`）解开后异或得到；该 dexp 由折叠实现通过，折叠实现另由设备侧
# （cryptolib 的 KAT）验证。
# 注意：**不要**再加单独一份 `p256_a2b.s` 的库 —— `p256_shared_key_lib` 已含
# `arithmetic_to_boolean*`，重复引入会 multiple definition（实测报错）。
otbn_sim_test(
    name = "p256_ecdh_local_test",
    srcs = ["p256_ecdh_shared_key_test.s"],
    exp = "p256_ecdh_key.exp",
    deps = [
        ":p256_base_lib",
        ":p256_isoncurve_lib",
        ":p256_isoncurve_proj_lib",
        ":p256_shared_key_lib",
    ],
)

# harness 剖面的 app 目标（专表 `p256_old` 条目）：srcs/deps 与上面的 sim test 逐项相同。
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
