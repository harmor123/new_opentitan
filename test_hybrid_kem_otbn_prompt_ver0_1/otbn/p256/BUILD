load("//rules:otbn.bzl", "otbn_binary", "otbn_library")

package(default_visibility = ["//visibility:public"])

# ⚠ **已知缺陷（2026-10-01 定位；这里只标记、不修改）** —— 本包的 `otbn_binary` 目标不可用：
#   本包把 4 个 `.s` 放进**同一个** `srcs`（`otbn_as.py` 一次汇编，分节状态跨文件延续），而
#   `p256_isoncurve_proj.s` 没有 `.text`/`.section` 指示 ⇒ 它继承前一个文件（`p256_base.s`，
#   结尾停在 `.section .data`）的段 ⇒ **该函数 51 条指令被汇编进 `.data`**：
#     · 实测指纹：其 ELF 的 data 段 684 B = 数据 480 B + 代码 204 B（204 = 51×4）；IMEM 里没有它；
#     · 该符号落进数据段（逐符号工具会把它滤掉）；对它的 `jal` 跳进 IMEM 里别处 ⇒ 返回垃圾值；
#     · 运行期症状：`p256_shared_key` 的曲线自检（`bn.cmp w18,w19` + `trigger_fault_if_fg0_z`）
#       拿到垃圾值后**故意触发** `ILLEGAL_INSN`（`ERR_BITS=0x8`）⇒ ISS/设备都会中止。
#   规则与检查器：`test_perf/tools/check/check_asm_sections.py`（多文件 `srcs` 里每个 `.s` 都要
#   显式写 `.text`；或按上游惯例"一文件一 otbn_library"）。
#   需要可用的旧侧（未折叠）实现：见 `//test_hybrid_kem_otbn_prompt_ver1_2/otbn/p256_old`。
#   需要可用的 ML-KEM 数：本包不受影响（本缺陷只在这些 p256 目标里）。

otbn_library(
    name = "p256_base_lib",
    srcs = ["p256_base.s"],
)

otbn_library(
    name = "p256_isoncurve_proj_lib",
    srcs = ["p256_isoncurve_proj.s"],
)

otbn_library(
    name = "p256_shared_key_lib",
    srcs = ["p256_shared_key.s"],
)

otbn_library(
    name = "p256_keygen_lib",
    srcs = ["p256_keygen.s"],
)

otbn_binary(
    name = "p256_ecdh_shared_key",
    srcs = [
        "//test_hybrid_kem_otbn_prompt_ver0_1/otbn/test:p256_ecdh_shared_key_test.s",
        "p256_base.s",
        "p256_isoncurve_proj.s",
        "p256_shared_key.s",
    ],
)

otbn_binary(
    name = "p256_keygen",
    srcs = [
        "//test_hybrid_kem_otbn_prompt_ver0_1/otbn/test:p256_keygen_test.s",
        "p256_base.s",
        "p256_isoncurve_proj.s",
        "p256_keygen.s",
    ],
)
