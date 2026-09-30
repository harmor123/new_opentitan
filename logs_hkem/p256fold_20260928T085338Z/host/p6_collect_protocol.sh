#!/usr/bin/env bash
# P6 Step 5/6：采集 ver1_2 三个协议测试的 HKEM_PROF 分段，并与冻结基线（ver1_1）逐段对照。
#
# 用法（在 Linux 构建机仓库根执行；前置：刚跑过三个 phase 的 `bazel test`）：
#   bash logs_hkem/p256fold_20260928T085338Z/host/p6_collect_protocol.sh
#
# 产出（都可由本脚本重跑覆盖）：
#   host/<test>.ver1_2.txt   本版三个测试的 HKEM_PROF/PASS/指令数行（入库）
#   host/<test>.base.txt     基线（logs_hkem/ver1_1/*.uart0.log）的同名行（入库）
#   host/protocol_ver1_2.log 三者合一（入库）
# 判据（PDF §11 P6）：**保留原有 HKEM_PROF 分段、不移动 protocol_total 边界** ⇒
#   段名集合的差异应为空（我们没有改任何打印代码）；只有 P-256 那些段的值应变小。
set -euo pipefail

PKG=test_hybrid_kem_otbn_prompt_ver1_2
VER=ver1_2
BASE_DIR=logs_hkem/ver1_1
RUN=logs_hkem/p256fold_20260928T085338Z/host
TESTS="phase1_keygen_test phase2_alice_encap_test phase2_bob_decap_test"

cd "$(git rev-parse --show-toplevel)"
mkdir -p "$RUN"

for t in $TESTS; do
  L="bazel-testlogs/$PKG/${t}_sim_verilator/test.log"
  if [ ! -f "$L" ]; then echo "找不到 $L —— 先跑 ${t}_sim_verilator" >&2; exit 1; fi
  grep -E "HKEM_PROF|OTBN instruction count|PASS!|FAIL" "$L" > "$RUN/$t.$VER.txt" || true
  grep -E "HKEM_PROF|OTBN instruction count|PASS!|FAIL" "$BASE_DIR/$t.uart0.log" > "$RUN/$t.base.txt" || true
  echo "[采] $t：本版 $(wc -l < "$RUN/$t.$VER.txt") 行 / 基线 $(wc -l < "$RUN/$t.base.txt") 行"
done

cat "$RUN"/phase1_keygen_test.$VER.txt "$RUN"/phase2_alice_encap_test.$VER.txt \
    "$RUN"/phase2_bob_decap_test.$VER.txt > "$RUN/protocol_$VER.log"

echo
echo "== 段名集合的差异（应为空 = 没有新增/删除/改名）=="
for t in $TESTS; do
  echo "-- $t"
  diff <(grep -oE "HKEM_PROF[A-Z_]*,[a-z0-9_]+,[a-z0-9_]+" "$RUN/$t.base.txt" | sort -u) \
       <(grep -oE "HKEM_PROF[A-Z_]*,[a-z0-9_]+,[a-z0-9_]+" "$RUN/$t.$VER.txt"  | sort -u) \
    && echo "   （无差异）"
done

echo
echo "== 关键段：基线 → 本版（Ibex mcycle）=="
for seg in p256_keygen_total p256_ecdh_official_api p256_unmask mlkem_keypair_load \
           mlkem_encap_execute_wait mlkem_decap_execute_wait hkdf_load \
           protocol_total scope_total accounted_total unaccounted_total; do
  b=$(grep -h ",$seg," "$RUN"/phase1_keygen_test.base.txt "$RUN"/phase2_alice_encap_test.base.txt \
        "$RUN"/phase2_bob_decap_test.base.txt 2>/dev/null | head -1 | awk -F, '{print $NF}')
  n=$(grep -h ",$seg," "$RUN"/phase1_keygen_test.$VER.txt "$RUN"/phase2_alice_encap_test.$VER.txt \
        "$RUN"/phase2_bob_decap_test.$VER.txt 2>/dev/null | head -1 | awk -F, '{print $NF}')
  if [ -n "$b" ] || [ -n "$n" ]; then
    printf "  %-28s %12s -> %12s   Δ=%s\n" "$seg" "${b:-—}" "${n:-—}" "$(( ${n:-0} - ${b:-0} ))"
  fi
done

echo
echo "== P-256 指令数（本版 / 基线）与 PASS =="
for t in $TESTS; do
  echo "-- $t"
  grep -hE "OTBN instruction count" "$RUN/$t.base.txt" "$RUN/$t.$VER.txt" | sed 's/^/   /'
  grep -hE "PASS!|FAIL" "$RUN/$t.base.txt" "$RUN/$t.$VER.txt" | sed 's/^/   /'
done
