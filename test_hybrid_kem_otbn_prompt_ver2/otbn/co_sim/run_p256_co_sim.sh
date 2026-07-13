#!/bin/bash
# P-256 ECDH shared-key OTBN co-simulation (RTL vs ISS)
# Requires: bazel, fusesoc, Verilator
set -euo pipefail
rm -rf build/lowrisc_ip_otbn_top_sim_0.1
SCRIPT_DIR="$(dirname "$(readlink -e "${BASH_SOURCE[0]}")")"
ROOT_DIR="$(readlink -e "$SCRIPT_DIR/../../..")"
fail() { echo >&2 "FAIL: $*"; exit 1; }
echo "=== P-256 ECDH OTBN co-sim ==="

# 1. Build OTBN assembly ELF
BAZEL_TARGET="//test_hybrid_kem_otbn_prompt_ver2/otbn/p256:p256_ecdh_shared_key"
ELF="$ROOT_DIR/bazel-bin/test_hybrid_kem_otbn_prompt_ver2/otbn/p256/p256_ecdh_shared_key.elf"
echo "Building bazel target: $BAZEL_TARGET"
(cd "$ROOT_DIR" && ./bazelisk.sh build "$BAZEL_TARGET") || fail "bazel build"

# 2. Build Verilator simulation (with MODP256 + BNMULV_VER2 flags)
VOTBN="$ROOT_DIR/build/lowrisc_ip_otbn_top_sim_0.1/sim-verilator/Votbn_top_sim"
echo "Building Verilator sim (bnmulv_ver2 + modp256)..."
(cd "$ROOT_DIR" && fusesoc --cores-root=. run --target=sim --setup --build \
  --flag=bnmulv_ver2 --flag=modp256 \
  --mapping=lowrisc:prim_generic:all:0.1 lowrisc:ip:otbn_top_sim \
  --make_options="-j$(nproc)") || fail "Verilator build"

# 3. Clear Python cache (ensure ISS changes are picked up)
find "$ROOT_DIR/hw/ip/otbn/dv/otbnsim" -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true

# 4. Run RTL-ISS co-simulation
echo "Running co-simulation..."
RUN_LOG=$(mktemp)
trap "rm -f $RUN_LOG" EXIT
timeout 600s "$VOTBN" --load-elf="$ELF" -t 2>&1 | tee "$RUN_LOG" || true

# 5. Check results
if grep -q "Mismatch\|%Error\|FAIL" "$RUN_LOG"; then
  echo "=== ERRORS FOUND ==="
  grep -E "Mismatch|ERROR|FAIL|wrote" "$RUN_LOG" | head -30
  fail "P-256 RTL-ISS mismatch"
fi
echo "PASS: P-256 ECDH co-simulation"
