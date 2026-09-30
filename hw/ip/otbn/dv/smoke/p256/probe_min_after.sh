#!/bin/bash
# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# 最小复现探针（P6 Step 4 发现的问题）：bn.p256mul 之后紧跟一条**写 ACC 的旧指令**时，
# RTL 与 ISS 对 ACC 的看法不一致（RTL 保留新指令留下的值、ISS 按 ".z + 累加" 语义更新）。
#
# 本脚本把该问题缩到最小：每个变体只有几条指令，**判据就是 co-sim 是否报分歧**
# （otbn_top_sim 把 RTL 与 Python ISS 逐条对拍，有分歧立刻报 Mismatch 并中断）。
# 由此判定：
#   · 是瞬态（隔一条无关指令就恢复正常）还是持续；
#   · 哪些旧指令受影响（写 ACC 的 bn.mulqacc* vs 不写 ACC 的 bn.mulvm 等）；
#   · 新指令自己是否受影响（mulqacc → p256mul → mulqacc 反序）。
#
# Usage: bash hw/ip/otbn/dv/smoke/p256/probe_min_after.sh
# 输出：每个变体一行 PASS / DIVERGENCE（后者附对拍报错的第一行）。
set -uo pipefail

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
    echo "$name: DIVERGENCE  $(printf '%s' "$out" | grep -m1 'Mismatch between RTL and ISS' || echo "(exit=$rc)")"
  fi
}

echo "== 最小复现探针（serial 档）=="

run_variant p256_then_mulqacc '  /* 新指令 → 紧跟写 ACC 的旧指令（混合测试里的最小形态） */
  bn.p256mul    w19, w24, w25
  bn.mulqacc.z  w2.0, w3.0, 0
  bn.mulqacc.so w4.L, w2.1, w3.1, 64
'

run_variant p256_gap1_then_mulqacc '  /* 中间隔一条无关指令（判定瞬态/持续） */
  bn.p256mul    w19, w24, w25
  bn.xor        w23, w23, w23
  bn.mulqacc.z  w2.0, w3.0, 0
  bn.mulqacc.so w4.L, w2.1, w3.1, 64
'

run_variant p256_then_mulvm '  /* 新指令 → 紧跟**不写 ACC** 的向量指令 */
  bn.p256mul    w19, w24, w25
  bn.mulvm.8S   w4, w24, w25
'

run_variant mulqacc_then_p256_then_mulqacc '  /* 反序：旧 → 新 → 旧 */
  bn.mulqacc.z  w2.0, w3.0, 0
  bn.p256mul    w19, w24, w25
  bn.mulqacc.z  w2.1, w3.1, 0
  bn.mulqacc.so w4.L, w2.2, w3.2, 64
'

run_variant p256_twice_then_mulqacc '  /* 两条新指令之后再接旧指令 */
  bn.p256mul    w19, w24, w25
  bn.p256mul    w20, w25, w25
  bn.mulqacc.z  w2.0, w3.0, 0
  bn.mulqacc.so w4.L, w2.1, w3.1, 64
'

run_variant mulqacc_only '  /* 对照：不出现新指令（应 PASS） */
  bn.mulqacc.z  w2.0, w3.0, 0
  bn.mulqacc.so w4.L, w2.1, w3.1, 64
'

run_variant p256_only '  /* 对照：不出现旧指令（应 PASS） */
  bn.p256mul    w19, w24, w25
'

echo "== 完（每个变体一次独立仿真）=="
