# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

package(default_visibility = ["//visibility:public"])

# OTBN 指令级追踪器（`otbn_tracer.core` + rtl/cpp/lint 文件）。
#
# 为什么需要这个 filegroup：`//hw:verilator_real`（chip 的 Verilator 模型）把
# `//hw:rtl_files` 的 glob 明确**排除了 `**/dv/**`**，而 fusesoc 构建是在 bazel 沙箱里跑的
# ⇒ 不显式列出，沙箱里就没有这些文件，fusesoc 会报 "missing package lowrisc:ip:otbn_tracer"。
# chip 的仿真台 `chip_sim_tb.sv` 现在 bind 了这个 tracer（PC/cycle trace），所以把它列进
# `//hw:verilator_real` 的 srcs（见 hw/BUILD）。
filegroup(
    name = "tracer_files",
    srcs = glob(["**"]),
)
