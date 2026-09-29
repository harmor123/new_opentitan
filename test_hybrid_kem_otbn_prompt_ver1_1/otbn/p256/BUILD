# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("//rules:otbn.bzl", "otbn_binary", "otbn_library", "otbn_sim_test")

package(default_visibility = ["//visibility:public"])

# ver1_1 本地的 P-256 域乘：与上游 `sw/otbn/crypto/p256_base.s` **只差 `mul_modp` 的函数体**
# （换成一条 `bn.p256mul w19, w24, w25` + `ret`）。上游文件一字不动；本文件的生成方式是
# 「按行拼接、只替换 419–561」并由脚本逐字节校验前后缀一致（见 run_dir/rtl/ 的记录）。
#
# 其余 P-256 文件仍用上游（用 label 指过去，不做多余的副本）。
# 与上游 `p256_base` 库**同构**：上游那个库就是这两个文件一对（`p256_base.s` 里的
# `p256_key_from_seed` 要调 `p256_b2a.s` 的 `boolean_to_arithmetic`，而 OTBN 的链接是整目标
# 文件级的、不做未用函数回收 ⇒ 两个都要在）。本地只改 `p256_base.s` 一份，
# `p256_b2a.s` 直接用上游源文件。
otbn_library(
    name = "p256_base_lib",
    srcs = [
        "p256_base.s",
        "//sw/otbn/crypto:p256_b2a.s",
    ],
)

# 本版 app：入口是本目录裁剪过的 `run_p256_local.s`（**不含签名/验签路径**：
# MODE_SIGN / MODE_SIGN_CONFIG_K / MODE_VERIFY / MODE_SIDELOAD_SIGN 及其例程已删，
# 11 个模式常量与全部内存符号保留，供 cryptolib 链接期使用）。
# 依赖 = 上游 `run_p256` 去掉 `p256_sign` / `p256_verify`，并把 `p256_base` 换成本地实现。
#
# ⚠ 目标名必须是 `run_p256`，不能带 `_local` 后缀：`rules/otbn.bzl` 把**目标名**作为
# `--app-name` 传给 `util/otbn_build.py`，而后者按该名字生成宿主侧符号
# （`util/otbn_build.py:326-327`：`_otbn_local_app_<app_name>_*` / `_otbn_remote_app_<app_name>_*`）。
# 设备侧 `sw/device/lib/crypto/impl/ecc/p256.c` 里 app 名写死为 `run_p256`
# （`OTBN_APP_T_INIT(run_p256)` / `OTBN_ADDR_T_INIT(run_p256, …)`，见 `drivers/otbn.h:142,153`）
# ⇒ 目标名不同则符号对不上，链接报 undefined symbol。改的是目标名，源码与上游仍一字不差。
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

# 官方单函数金标：同一个测试程序、同一份 `.exp`，只把实现的域乘换成本地这份
# ⇒ 用官方期望值直接验证「换掉 mul_modp 函数体之后结果不变」。
otbn_sim_test(
    name = "p256_mul_modp_local_test",
    srcs = ["//sw/otbn/crypto/tests:p256_mul_modp_test.s"],
    exp = "//sw/otbn/crypto/tests:p256_mul_modp_test.exp",
    deps = [
        ":p256_base_lib",
        "//sw/otbn/crypto:p256_isoncurve",
    ],
)

# ECDH 级：与 ver0 的同名测试同源（测试程序与 `.dexp` 一并放进本版目录），
# 唯一差别是域乘用本地这份 ⇒ 端到端的共享密钥仍必须是 `.dexp` 里那个期望值。
otbn_sim_test(
    name = "p256_ecdh_local_test",
    srcs = ["p256_ecdh_shared_key_test.s"],
    dexp = "p256.dexp",
    # 依赖集与 `:run_p256` 相同（上游 run_p256 去掉 p256_sign / p256_verify）。
    # 注意：**不要**加 `//sw/otbn/crypto:p256_a2b` —— 上游的 `p256_shared_key.s` 自身已含
    # `arithmetic_to_boolean*`，再加会 multiple definition（实测报错）。
    deps = [
        ":p256_base_lib",
        "//sw/otbn/crypto:p256_isoncurve",
        "//sw/otbn/crypto:p256_isoncurve_check",
        "//sw/otbn/crypto:p256_isoncurve_proj",
        "//sw/otbn/crypto:p256_shared_key",
    ],
)
