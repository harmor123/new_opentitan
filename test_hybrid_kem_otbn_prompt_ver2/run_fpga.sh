#!/bin/bash
# ================================================================
# Hybrid KEM FPGA test — follows otbn_mlkem_test.c pattern.
#
# Requires: CW310 FPGA board with BNMULV ver2 bitstream loaded.
# ================================================================
set -e

echo "=== Build Hybrid KEM test firmware ==="
bazel build //test_hybrid_kem_otbn_prompt_ver2:hybrid_kem_test

echo "=== Run on FPGA ==="
opentitantool --interface=cw310 --exec=console \
    --firmware=bazel-bin/test_hybrid_kem_otbn_prompt_ver2/hybrid_kem_test.elf \
    --exec="console" \
    --exit-success="All checks passed" \
    --exit-failure="CHECK-fail"

echo "=== Done ==="
