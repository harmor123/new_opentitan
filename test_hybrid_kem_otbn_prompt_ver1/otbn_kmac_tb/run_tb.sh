#!/bin/bash
# run_tb.sh — otbn_kmac standalone testbench
#   OTBN_EN_MASKING=0 (default) → DV mode  (25cy/keccak, mask=0)
#   OTBN_EN_MASKING=1            → SCA mode (97cy/keccak, DOM+URND)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RTL="$HOME/pqc/opentitan/hw/ip"
cd "$SCRIPT_DIR"

ENMASK="${OTBN_EN_MASKING:-0}"
TB_FILE="tb_dv.sv"
[ "$ENMASK" = "1" ] && TB_FILE="tb_sca.sv"
echo "=== EnMasking=$ENMASK ($TB_FILE) ==="

python3 gen_kat.py

verilator --binary -CFLAGS -O3 \
  -Wno-fatal -Wno-UNUSED -Wno-WIDTH -Wno-COMBDLY -Wno-STMTDLY \
  -I"$RTL/prim/rtl" -I"$RTL/otbn/rtl" -I"$RTL/kmac/rtl" \
  -I"$RTL/lc_ctrl/rtl" -I"$RTL/otp_ctrl/rtl" -I"$RTL/prim_generic/rtl" \
  --top-module tb \
  "$RTL/prim/rtl/prim_assert.sv" \
  "$RTL/prim/rtl/prim_util_pkg.sv" \
  "$RTL/lc_ctrl/rtl/lc_ctrl_state_pkg.sv" \
  "$RTL/lc_ctrl/rtl/lc_ctrl_reg_pkg.sv" \
  "$RTL/prim/rtl/prim_mubi_pkg.sv" \
  "$RTL/lc_ctrl/rtl/lc_ctrl_pkg.sv" \
  "$RTL/prim/rtl/prim_trivium_pkg.sv" \
  "$RTL/prim/rtl/prim_trivium.sv" \
  "$RTL/otp_ctrl/rtl/otp_ctrl_pkg.sv" \
  "$RTL/prim/rtl/prim_secded_pkg.sv" \
  "$RTL/prim/rtl/prim_secded_inv_39_32_enc.sv" \
  "$RTL/otbn/rtl/otbn_pkg.sv" \
  "$RTL/kmac/rtl/sha3_pkg.sv" \
  "$RTL/kmac/rtl/kmac_pkg.sv" \
  "$RTL/prim/rtl/prim_count_pkg.sv" \
  "$RTL/prim_generic/rtl/prim_flop.sv" \
  "$RTL/prim_generic/rtl/prim_buf.sv" \
  "$RTL/prim/rtl/prim_count.sv" \
  "$RTL/prim/rtl/prim_sec_anchor_buf.sv" \
  "$RTL/prim/rtl/prim_dom_and_2share.sv" \
  "$RTL/kmac/rtl/keccak_2share.sv" \
  "$RTL/kmac/rtl/keccak_round.sv" \
  "$RTL/otbn/rtl/otbn_kmac.sv" \
  "$TB_FILE" \
  --Mdir build 

build/Vtb 
