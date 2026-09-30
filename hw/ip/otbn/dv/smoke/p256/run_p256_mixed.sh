#!/bin/bash
# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Runs the P-256 mixed-instruction test (P6 Step 4 of the fold-unit work):
# exercises BN.P256MUL interleaved with the *old* MAC/vector instructions
# (bn.mulqacc.* / bn.mulvm.8S / bn.addvm.8S / bn.mulvml.8S) plus the aliasing
# combinations (wa=wb, wd=wa, wd=wb, all-equal) and two back-to-back
# BN.P256MULs with different inputs.
#
# Two layers of checking:
#   ① otbn_top_sim co-simulates the RTL against the Python ISS instruction by
#      instruction - any RTL/ISS divergence aborts the run (mismatch error);
#   ② the program itself compares every "mixed" sequence against the same
#      sequence *without* the new instruction and ORs the XORs into w29 (err).
#      This script asserts err == 0 explicitly, then diffs the full dump
#      against the golden file.
#
# Usage: bash hw/ip/otbn/dv/smoke/p256/run_p256_mixed.sh [serial|overlap]
#   serial (default) = P3 schedule, 28 cycles; overlap = P4 schedule, 22 cycles.
#   Both knobs (RTL plus-arg and ISS environment) are set together here.
#   The final-register dump does not depend on the schedule, so one golden
#   file serves both modes.
# Pass: prints "P256 MIXED TEST PASS for program p256_mixed_test"

fail() {
    echo >&2 "P256 MIXED TEST FAILURE: $*"
    exit 1
}

set -o pipefail
set -e

SCRIPT_DIR="$(dirname "$(readlink -e "${BASH_SOURCE[0]}")")"
ROOT_DIR="$(readlink -e "$SCRIPT_DIR/../../../../../..")" || \
  fail "Can't find OpenTitan root dir"

source "$ROOT_DIR/util/build_consts.sh"

NAME="p256_mixed_test"

P256_MODE="${1:-serial}"
case "$P256_MODE" in
  serial)  P256_EXTRA="";               unset OTBN_P256_SERIAL ;;
  overlap) P256_EXTRA="+p256_serial=0"; export OTBN_P256_SERIAL=0 ;;
  *) fail "unknown mode '$P256_MODE' (expected serial|overlap)" ;;
esac
echo "P-256 schedule mode: $P256_MODE"
BIN_DIR_OTBN="$BIN_DIR/otbn/$NAME"
mkdir -p "$BIN_DIR_OTBN"

OTBN_UTIL="$ROOT_DIR/hw/ip/otbn/util"

"$OTBN_UTIL/otbn_as.py" -o "$BIN_DIR_OTBN/$NAME.o" "$SCRIPT_DIR/$NAME.s" || \
    fail "Failed to assemble $NAME.s"
"$OTBN_UTIL/otbn_ld.py" -o "$BIN_DIR_OTBN/$NAME.elf" "$BIN_DIR_OTBN/$NAME.o" || \
    fail "Failed to link $NAME.o"

SIM="$ROOT_DIR/build/lowrisc_ip_otbn_top_sim_0.1/sim-verilator/Votbn_top_sim"
if [ ! -x "$SIM" ]; then
  (cd "$ROOT_DIR";
   fusesoc --cores-root=. run --target=sim --setup --build \
      --mapping=lowrisc:prim_generic:all:0.1 lowrisc:ip:otbn_top_sim \
      --make_options="-j$(nproc)" || fail "HW sim build failed")
fi

RUN_LOG=$(mktemp)
readonly RUN_LOG
# shellcheck disable=SC2064 # The RUN_LOG tempfile path should not change
trap "rm -rf $RUN_LOG" EXIT

timeout 60s "$SIM" --load-elf="$BIN_DIR_OTBN/$NAME.elf" $P256_EXTRA -t | tee "$RUN_LOG"

if [ $? -eq 124 ]; then
  fail "Simulation timeout"
fi
if [ $? -ne 0 ]; then
  fail "Simulator run failed (a RTL/ISS mismatch aborts the simulation)"
fi

# Same extraction as run_p256_fold.sh: from "Call Stack:" up to (but not
# including) the "Simulation statistics" banner.
DUMP="$RUN_LOG.dump"
sed -n '/^Call Stack:/,/^Simulation statistics/p' "$RUN_LOG" | sed '$d' > "$DUMP"

# ── ① 自检：err（w29）必须为 0 ──
ERR_LINE="$(grep -E '^w29 \|' "$DUMP" || true)"
[ -n "$ERR_LINE" ] || fail "dump has no w29 line (expected the error accumulator)"
ZERO256="0x00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000"
case "$ERR_LINE" in
  *"$ZERO256"*) echo "  err(w29) = 0  ->  all ref-vs-mixed comparisons pass" ;;
  *) fail "err(w29) != 0 -- a mixed sequence differs from its reference: $ERR_LINE" ;;
esac

# ── ② golden 比对（缺失则生成一次，请复核后提交；两种调度共用同一份） ──
EXPECTED="$SCRIPT_DIR/$NAME.expected.txt"
if [ ! -f "$EXPECTED" ]; then
  cp "$DUMP" "$EXPECTED"
  echo "  generated golden: $EXPECTED"
  echo "  -> review it (w29 must be 0) and commit; re-run this script to get the diff check"
  exit 0
fi

had_diff=0
diff -U3 "$EXPECTED" "$DUMP" || had_diff=1
if [ $had_diff == 0 ]; then
  echo "P256 MIXED TEST PASS for program $NAME"
else
  fail "Simulator output does not match expected output for program $NAME"
fi
