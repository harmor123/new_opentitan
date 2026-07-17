#!/bin/bash
# ============================================================
# run_kdf_co_sim.sh — KMAC-KDF OTBN RTL+ISS co-simulation (ver0 software)
# ============================================================
# KMAC-KDF (NIST SP 800-108r1):
#   OKM = SHAKE256(KDK || FixedInfo, L)
# Pure software implementation via sha3_shake.s Keccak-f primitives.
# ============================================================

set -e

rm -rf build/lowrisc_ip_otbn_top_sim_0.1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

echo "=============================================="
echo " OTBN co-sim: KMAC-KDF (ver0 software SHAKE256)"
echo "=============================================="

# Build the OTBN application
BAZEL_TARGET="//test_hybrid_kem_otbn_prompt_ver0/otbn/hkdf:kmac_kdf"
ELF="$ROOT_DIR/bazel-bin/test_hybrid_kem_otbn_prompt_ver0/otbn/hkdf/kmac_kdf.elf"

echo "[1/3] Building ELF: $BAZEL_TARGET"
cd "$ROOT_DIR"
./bazelisk.sh build "$BAZEL_TARGET"

# Build Verilator simulator if needed
VOTBN="$ROOT_DIR/build/lowrisc_ip_otbn_top_sim_0.1/default-verilator/Votbn_top_sim"
if [ ! -x "$VOTBN" ]; then
  echo "[2/3] Building Verilator simulator..."
  fusesoc --cores-root="$ROOT_DIR" run --target=sim --setup --build \
    lowrisc:ip:otbn_top_sim:0.1
fi

# Run co-simulation
echo "[3/3] Running co-sim..."
TIMEOUT=120
TMP_LOG=$(mktemp)
timeout $TIMEOUT "$VOTBN" --load-elf="$ELF" 2>&1 | tee "$TMP_LOG" || true

if grep -qE "Mismatch|%Error" "$TMP_LOG"; then
  echo ""
  echo "=============================================="
  echo " CO-SIM FAILED: RTL/ISS MISMATCH DETECTED"
  echo "=============================================="
  grep -nE "Mismatch|%Error" "$TMP_LOG"
  rm -f "$TMP_LOG"
  exit 1
fi

echo ""
echo "=============================================="
echo " CO-SIM PASSED"
echo "=============================================="
rm -f "$TMP_LOG"
