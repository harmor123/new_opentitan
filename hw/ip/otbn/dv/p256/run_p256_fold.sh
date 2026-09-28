#!/bin/bash
# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Runs the P-256 fused multiply test (BN.P256MUL, P3 of the fold-unit work):
# builds the software, runs it on the OTBN standalone simulation (which also
# co-simulates the RTL against the Python ISS) and compares the final register
# state against the expected output.
#
# Usage: bash hw/ip/otbn/dv/p256/run_p256_fold.sh
# Pass:  prints "P256 FOLD TEST PASS for program p256_fold_test"

fail() {
    echo >&2 "P256 FOLD TEST FAILURE: $*"
    exit 1
}

set -o pipefail
set -e

SCRIPT_DIR="$(dirname "$(readlink -e "${BASH_SOURCE[0]}")")"
ROOT_DIR="$(readlink -e "$SCRIPT_DIR/../../../../..")" || \
  fail "Can't find OpenTitan root dir"

source "$ROOT_DIR/util/build_consts.sh"

NAME="p256_fold_test"
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

timeout 60s "$SIM" --load-elf="$BIN_DIR_OTBN/$NAME.elf" -t | tee "$RUN_LOG"

if [ $? -eq 124 ]; then
  fail "Simulation timeout"
fi

if [ $? -ne 0 ]; then
  fail "Simulator run failed (a RTL/ISS mismatch aborts the simulation)"
fi

# The expected file is the tracer's final dump: from "Call Stack:" up to (but
# not including) the "Simulation statistics" banner. Extracting it the same way
# here and when the golden file is generated keeps the two sides consistent.
EXPECTED="$SCRIPT_DIR/$NAME.expected.txt"
DUMP="$RUN_LOG.dump"
sed -n '/^Call Stack:/,/^Simulation statistics/p' "$RUN_LOG" | sed '$d' > "$DUMP"

had_diff=0
diff -U3 "$EXPECTED" "$DUMP" || had_diff=1

if [ $had_diff == 0 ]; then
  echo "P256 FOLD TEST PASS for program $NAME"
else
  fail "Simulator output does not match expected output for program $NAME"
fi
