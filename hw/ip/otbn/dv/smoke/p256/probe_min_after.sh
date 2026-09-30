#!/bin/bash
# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# 最小复现探针：**一次假警报的否证记录**（留作证据，不是待修问题）。
#
# 背景：p256_mixed_test.s 第一次运行时，otbn_top_sim 在第一条 bn.mulqacc 处报 ACC 分歧
# （RTL 0x…7ccc92ef_f7c2f9a4_c887770a_3dba84b0 vs ISS 0x0），一度被解释成"bn.p256mul 留下的
# ACC 末值让旧指令对 ACC 的看法不一致"。
#
# 本脚本用最小变体否掉了该解释：判据 = co-sim 是否报分歧（每条指令后都比 ACC）。
#   · p256_only / p256_then_mulvm                              → PASS（新指令本身没问题）
#   · mulqacc_only（**不含**任何新指令，只是读到未初始化的 w2/w3）→ DIVERGENCE
#   · wdr_cleared_then_mulqacc（同样两条指令，只是先 bn.xor 把 w2/w3 清零）→ PASS
# ⇒ 分歧与 bn.p256mul 无关：**读未初始化的 WDR** 就会分歧。
#
# 根因（RTL 有据）：OTBN 每次 start 都用 URND 随机数把 32 个 WDR 全写一遍 ——
#   `otbn_core.sv:1018-1025` 的 `sec_wipe_wdr_q` 分支把 `urnd_data` 写进 WDR（非 0），
#   由 `otbn_start_stop_control.sv:289` 的 `OtbnStartStopSecureWipeWdrUrnd` 状态驱动；
#   `otbn_rf_bignum.sv:189` 的断言（"Make sure we're not outputting X … during the initial
#   secure wipe"）也写明启动后 WDR 不该读到未初始化值。
#   而 Python ISS 把 WDR 建模为 0；otbn_top_sim 的 URND 种子固定 ⇒ 每次都是同一个常数。
#
# ⇒ 结论：写 OTBN 测试程序必须**先显式清零用到的 WDR**（本仓库所有正规内核测试的前奏都这么做）；
#   原先报的"新指令/交替场景 RTL bug"不成立。各变体保留在此，供复核这条否证。
#
# Usage: bash hw/ip/otbn/dv/smoke/p256/probe_min_after.sh
# 输出：每个变体一行 PASS / DIVERGENCE（后者附**出错的那条指令**与两侧的值）。
# 注：最小变体不需要把 ACC 读出来 —— 对拍器在每条指令后都比 ACC，所以不写 .so/.wo，
#     少一个可疑自由度（`.wo` = 整字写回 WDR，`.so` = 移位输出半字，二者目的侧才带 .L/.H）。
set -uo pipefail
rm -rf build/lowrisc_ip_otbn_top_sim_0.1
SCRIPT_DIR="$(dirname "$(readlink -e "${BASH_SOURCE[0]}")")"
ROOT_DIR="$(readlink -e "$SCRIPT_DIR/../../../../../..")" || { echo "no root dir" >&2; exit 1; }
source "$ROOT_DIR/util/build_consts.sh"

OTBN_UTIL="$ROOT_DIR/hw/ip/otbn/util"
SIM="$ROOT_DIR/build/lowrisc_ip_otbn_top_sim_0.1/sim-verilator/Votbn_top_sim"
[ -x "$SIM" ] || { echo "缺 $SIM（先跑 run_p256_fold.sh 让它构建）" >&2; exit 1; }

WORK="$BIN_DIR/otbn/probe_min_after"
mkdir -p "$WORK"

HEAD='.section .text.start
  /* w24 = d0, w25 = x（与 p256_fold_test 同一组官方向量） */
  li        x2, 24
  la        x3, d0
  bn.lid    x2, 0(x3)
  li        x2, 25
  la        x3, x
  bn.lid    x2, 0(x3)
'
TAIL='  ecall

.section .data
.balign 32
d0:
  .word 0xfe6d1071
  .word 0x21d0a016
  .word 0xb0b2c781
  .word 0x9590ef5d
  .word 0x3fdfa379
  .word 0x1b76ebe8
  .word 0x74210263
  .word 0x1420fc41
.balign 32
x:
  .word 0xbfa8c334
  .word 0x9773b7b3
  .word 0xf36b0689
  .word 0x6ec0c0b2
  .word 0xdb6c8bf3
  .word 0x1628ce58
  .word 0xfacdc546
  .word 0xb5511a6a
'

# 变体：名字 → 正文（放在 HEAD 与 TAIL 之间）
run_variant() {
  local name="$1" body="$2" s="$WORK/$1.s" out rc
  printf '%s%s%s' "$HEAD" "$body" "$TAIL" > "$s"
  if ! "$OTBN_UTIL/otbn_as.py" -o "$WORK/$1.o" "$s" > "$WORK/$1.as.log" 2>&1; then
    echo "$name: ASSEMBLE-FAIL  $(grep -m1 -iE 'error|cannot' "$WORK/$1.as.log" | cut -c1-160)"
    return
  fi
  if ! "$OTBN_UTIL/otbn_ld.py" -o "$WORK/$1.elf" "$WORK/$1.o" > "$WORK/$1.ld.log" 2>&1; then
    echo "$name: LINK-FAIL  $(grep -m1 -iE 'error|undefined' "$WORK/$1.ld.log" | cut -c1-160)"
    return
  fi
  out=$(timeout 60s "$SIM" --load-elf="$WORK/$1.elf" -t 2>&1)
  rc=$?
  if [ $rc -eq 0 ]; then
    echo "$name: PASS（无 RTL/ISS 分歧）"
  else
    echo "$name: DIVERGENCE"
    # 打出**出错的那条指令**与两侧的值（只打第一行看不出是哪条 —— 踩过）
    printf '%s\n' "$out" | grep -A 5 -m1 'Mismatch between RTL and ISS' | sed 's/^/    /'
  fi
}

echo "== 最小复现探针（serial 档）=="

run_variant p256_then_mulqacc '  /* 新指令 → 紧跟写 ACC 的旧指令；用 .wo.z 把 ACC 写回 w4（函数结果可比） */
  bn.p256mul      w19, w24, w25
  bn.mulqacc.wo.z w4, w2.0, w3.0, 0
'

run_variant p256_gap1_then_mulqacc '  /* 中间隔一条无关指令（判定瞬态/持续） */
  bn.p256mul    w19, w24, w25
  bn.xor        w23, w23, w23
  bn.mulqacc.z  w2.0, w3.0, 0
'

run_variant wdr_cleared_then_mulqacc '  /* 先把用到的 WDR 显式清零，再 .wo.z（排除"复位值是否为 0"的假设） */
  bn.xor          w2, w2, w2
  bn.xor          w3, w3, w3
  bn.mulqacc.wo.z w4, w2.0, w3.0, 0
'

run_variant p256_then_mulvm '  /* 新指令 → 紧跟**不写 ACC** 的向量指令 */
  bn.p256mul    w19, w24, w25
  bn.mulvm.8S   w4, w24, w25
'

run_variant mulqacc_then_p256_then_mulqacc '  /* 反序：旧 → 新 → 旧 */
  bn.mulqacc.z  w2.0, w3.0, 0
  bn.p256mul    w19, w24, w25
  bn.mulqacc.z  w2.1, w3.1, 0
'

run_variant p256_twice_then_mulqacc '  /* 两条新指令之后再接旧指令 */
  bn.p256mul    w19, w24, w25
  bn.p256mul    w20, w25, w25
  bn.mulqacc.z  w2.0, w3.0, 0
'

run_variant mulqacc_only '  /* 对照：不出现新指令（应 PASS） */
  bn.mulqacc.wo.z w4, w2.0, w3.0, 0
'

run_variant p256_only '  /* 对照：不出现旧指令（应 PASS） */
  bn.p256mul    w19, w24, w25
'

echo "== 完（每个变体一次独立仿真）=="
