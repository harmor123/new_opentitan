#!/bin/bash
# KMAC-KDF SHAKE256 OTBN RTL+ISS co-simulation (ver0 pure software)
set -euo pipefail
rm -rf build/lowrisc_ip_otbn_top_sim_0.1
SCRIPT_DIR="$(dirname "$(readlink -e "${BASH_SOURCE[0]}")")"
ROOT_DIR="$(readlink -e "$SCRIPT_DIR/../../..")"
fail() { echo >&2 "FAIL: $*"; exit 1; }
echo "=== KMAC-KDF OTBN co-sim (ver0 software SHAKE256) ==="
BAZEL_TARGET="//test_hybrid_kem_otbn_prompt_ver0/otbn/hkdf:kmac_kdf"
ELF="$ROOT_DIR/bazel-bin/test_hybrid_kem_otbn_prompt_ver0/otbn/hkdf/kmac_kdf.elf"
VOTBN="$ROOT_DIR/build/lowrisc_ip_otbn_top_sim_0.1/sim-verilator/Votbn_top_sim"
(cd "$ROOT_DIR" && ./bazelisk.sh build "$BAZEL_TARGET") || fail "bazel build"
if [ ! -x "$VOTBN" ]; then
  (cd "$ROOT_DIR" && fusesoc --cores-root=. run --target=sim --setup --build \
    --mapping=lowrisc:prim_generic:all:0.1 lowrisc:ip:otbn_top_sim \
    --make_options="-j$(nproc)") || fail "Verilator build"
fi
RUN_LOG=$(mktemp)
trap "rm -f $RUN_LOG" EXIT
timeout 120s "$VOTBN" --load-elf="$ELF" 2>&1 | tee "$RUN_LOG" || true
if grep -q "Mismatch\|%Error" "$RUN_LOG"; then
  grep "Mismatch\|RTL wrote\|ISS wrote" "$RUN_LOG" | head -10
  fail "KMAC-KDF RTL-ISS mismatch"
fi
echo "PASS"
