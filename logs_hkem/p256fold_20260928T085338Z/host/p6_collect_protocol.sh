#!/usr/bin/env bash
# P6 Step 5/6：采集 ver1_2 三个协议测试的 HKEM_PROF 分段，并与基线逐段对照。
#
# 用法（在 Linux 构建机仓库根执行；前置：刚跑过两边三个 phase 的 `bazel test`）：
#   bash logs_hkem/p256fold_20260928T085338Z/host/p6_collect_protocol.sh            # 基线 = 仓库里 ver1_1 早期的 uart0 日志
#   bash logs_hkem/p256fold_20260928T085338Z/host/p6_collect_protocol.sh --base-cur # 基线 = **当前模型上**跑 ver1_1 同测试（推荐）
#
# 为什么要有 --base-cur：仓库里那份 ver1_1 日志来自**早期 build**，而含 sec wipe / 熵链的
# 宿主 I/O 段（*_load / *_write_inputs / *_read_outputs）对 build 敏感（13 号文档 §5 3c 登记过
# "跨 build 会变、方向不一"）。要比就得比**同模型**：ver1_1 没被改过，它的同一个测试就是
# "同代码 + 当前模型"的基线。
#
# 产出（都可由本脚本重跑覆盖）：
#   host/<test>.ver1_2.txt            本版三个测试的 HKEM_PROF/PASS/指令数行
#   host/<test>.base.txt（或 .base_cur.txt）  基线同名行
#   host/protocol_ver1_2.log          三者合一
set -euo pipefail

PKG=test_hybrid_kem_otbn_prompt_ver1_2
PKG_BASE=test_hybrid_kem_otbn_prompt_ver1_1
VER=ver1_2
BASE_DIR=logs_hkem/ver1_1
RUN=logs_hkem/p256fold_20260928T085338Z/host
TESTS="phase1_keygen_test phase2_alice_encap_test phase2_bob_decap_test"
BASESUF=base
[ "${1:-}" = "--base-cur" ] && BASESUF=base_cur

cd "$(git rev-parse --show-toplevel)"
mkdir -p "$RUN"

# grep 无匹配会返回 1；本脚本开了 set -e ⇒ 一律 `|| true`
pick() { grep -E "HKEM_PROF|OTBN instruction count|PASS!|FAIL" "$1" || true; }

for t in $TESTS; do
  L="bazel-testlogs/$PKG/${t}_sim_verilator/test.log"
  [ -f "$L" ] || { echo "找不到 $L —— 先跑 //$PKG:${t}_sim_verilator" >&2; exit 1; }
  pick "$L" > "$RUN/$t.$VER.txt"
  if [ "$BASESUF" = "base_cur" ]; then
    LB="bazel-testlogs/$PKG_BASE/${t}_sim_verilator/test.log"
    [ -f "$LB" ] || { echo "找不到 $LB —— 先跑 //$PKG_BASE:${t}_sim_verilator" >&2; exit 1; }
    pick "$LB" > "$RUN/$t.$BASESUF.txt"
  else
    pick "$BASE_DIR/$t.uart0.log" > "$RUN/$t.$BASESUF.txt"
  fi
  echo "[采] $t：本版 $(wc -l < "$RUN/$t.$VER.txt") 行 / 基线 $(wc -l < "$RUN/$t.$BASESUF.txt") 行（$BASESUF）"
done

cat "$RUN"/phase1_keygen_test.$VER.txt "$RUN"/phase2_alice_encap_test.$VER.txt \
    "$RUN"/phase2_bob_decap_test.$VER.txt > "$RUN/protocol_$VER.log"

echo
echo "== 段名集合的差异（应为空 = 没有新增/删除/改名）=="
for t in $TESTS; do
  echo "-- $t"
  diff <(grep -oE "HKEM_PROF[A-Z_]*,[a-z0-9_]+,[a-z0-9_]+" "$RUN/$t.$BASESUF.txt" | sort -u) \
       <(grep -oE "HKEM_PROF[A-Z_]*,[a-z0-9_]+,[a-z0-9_]+" "$RUN/$t.$VER.txt" | sort -u) \
    && echo "   （无差异）"
done

echo
echo "== 关键段：基线（$BASESUF）→ 本版（Ibex mcycle）=="
for seg in p256_keygen_total p256_ecdh_official_api p256_unmask mlkem_keypair_load \
           mlkem_encap_load mlkem_decap_load hkdf_load \
           mlkem_keypair_write_inputs mlkem_decap_write_inputs mlkem_keypair_read_outputs \
           protocol_total scope_total accounted_total unaccounted_total; do
  # 基线文件在库里可能是 CRLF ⇒ 取数一律 tr -d '\r'（否则 $(( )) 报 invalid arithmetic operator）
  b=$( { grep -h ",$seg," "$RUN"/phase1_keygen_test.$BASESUF.txt \
                   "$RUN"/phase2_alice_encap_test.$BASESUF.txt \
                   "$RUN"/phase2_bob_decap_test.$BASESUF.txt 2>/dev/null || true; } \
        | head -1 | awk -F, '{print $NF}' | tr -d '\r')
  n=$( { grep -h ",$seg," "$RUN"/phase1_keygen_test.$VER.txt \
                   "$RUN"/phase2_alice_encap_test.$VER.txt \
                   "$RUN"/phase2_bob_decap_test.$VER.txt 2>/dev/null || true; } \
        | head -1 | awk -F, '{print $NF}' | tr -d '\r')
  if [ -n "$b" ] && [ -n "$n" ]; then
    printf "  %-28s %12s -> %12s   Δ=%+d\n" "$seg" "$b" "$n" "$(( n - b ))"
  elif [ -n "$b" ] || [ -n "$n" ]; then
    printf "  %-28s %12s -> %12s   Δ=—\n" "$seg" "${b:-—}" "${n:-—}"
  fi
done

echo
echo "== P-256 指令数（基线 / 本版）与 PASS =="
for t in $TESTS; do
  echo "-- $t"
  { grep -hE "OTBN instruction count" "$RUN/$t.$BASESUF.txt" "$RUN/$t.$VER.txt" || true; } | sed 's/^/   /'
  { grep -hE "PASS!|FAIL"               "$RUN/$t.$BASESUF.txt" "$RUN/$t.$VER.txt" || true; } | sed 's/^/   /'
done
