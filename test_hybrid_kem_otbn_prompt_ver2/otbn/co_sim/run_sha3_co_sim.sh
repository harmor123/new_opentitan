#!/bin/bash
# SHA3/KMAC OTBN RTL+ISS co-simulation
set -euo pipefail
rm -rf build/lowrisc_ip_otbn_top_sim_0.1
SCRIPT_DIR="$(dirname "$(readlink -e "${BASH_SOURCE[0]}")")"
ROOT_DIR="$(readlink -e "$SCRIPT_DIR/../../..")"
fail() { echo >&2 "FAIL: $*"; exit 1; }
echo "=== SHA3/KMAC OTBN co-sim ==="
BAZEL_TARGET="//test_hybrid_kem_otbn_prompt_ver2/otbn/kmac:sha3_test_bin"
ELF="$ROOT_DIR/bazel-bin/test_hybrid_kem_otbn_prompt_ver2/otbn/kmac/sha3_test_bin.elf"
VOTBN="$ROOT_DIR/build/lowrisc_ip_otbn_top_sim_0.1/sim-verilator/Votbn_top_sim"
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
timeout 120s "$VOTBN" --load-elf="$ELF" 2>&1 | tee "$RUN_LOG" || true
if grep -q "Mismatch\|%Error" "$RUN_LOG"; then
  grep "Mismatch\|RTL wrote\|ISS wrote" "$RUN_LOG" | head -10
  fail "SHA3 RTL-ISS mismatch"
fi
echo "PASS"
