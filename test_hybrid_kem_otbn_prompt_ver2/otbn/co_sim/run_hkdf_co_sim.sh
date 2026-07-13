#!/bin/bash
# HKDF-SHA3-256 OTBN RTL + ISS co-simulation
# Bypasses Ibex, loads ELF directly into standalone OTBN Verilator sim.
set -euo pipefail
rm -rf build/lowrisc_ip_otbn_top_sim_0.1
SCRIPT_DIR="$(dirname "$(readlink -e "${BASH_SOURCE[0]}")")"
ROOT_DIR="$(readlink -e "$SCRIPT_DIR/../../..")"

fail() { echo >&2 "FAIL: $*"; exit 1; }

echo "=== HKDF-SHA3-256 OTBN co-sim (RTL vs ISS) ==="

BAZEL_TARGET="//test_hybrid_kem_otbn_prompt_ver2/otbn/hkdf:hkdf_sha3_256"
ELF="$ROOT_DIR/bazel-bin/test_hybrid_kem_otbn_prompt_ver2/otbn/hkdf/hkdf_sha3_256.elf"
VOTBN="$ROOT_DIR/build/lowrisc_ip_otbn_top_sim_0.1/sim-verilator/Votbn_top_sim"

# Build ELF
(cd "$ROOT_DIR" && ./bazelisk.sh build "$BAZEL_TARGET") || fail "bazel build"

# OTBN_EN_MASKING env var aligned with ISS: 1=SCA masked, 0=DV plain
EN_MASKING=${OTBN_EN_MASKING:-0}
if [ ! -x "$VOTBN" ]; then
  echo "Building Verilator simulation..."
  (cd $ROOT_DIR &&
   fusesoc --cores-root=. run --target=sim --setup --build \
     --mapping=lowrisc:prim_generic:all:0.1 lowrisc:ip:otbn_top_sim \
     --EnMaskingOtnb="$EN_MASKING" \
     --make_options="-j$(nproc)" || fail "HW Sim build failed")
fi

RUN_LOG=$(mktemp)
trap "rm -f $RUN_LOG" EXIT

echo "Running Votbn_top_sim --load-elf..."
timeout 120s "$VOTBN" --load-elf="$ELF" 2>&1 | tee "$RUN_LOG" || true

if grep -q "Mismatch\|%Error" "$RUN_LOG"; then
  echo "=== MISMATCHES ==="
  grep "Mismatch\|RTL wrote\|ISS wrote" "$RUN_LOG" | head -20
  fail "HKDF RTL-ISS mismatch"
fi

echo "PASS: HKDF-SHA3-256 RTL matches ISS"
