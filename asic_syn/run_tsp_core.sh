#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:?usage: $0 <workspace> <clock-period-ns>}"
PERIOD="${2:?usage: $0 <workspace> <clock-period-ns>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

export RTL_ROOT="$ROOT/rtl/core"
export LIB_DB="$ROOT/db/ics55_LLSC_H9CR_typ_tt_1p2_25_nldm.db"
export CLOCK_PERIOD="$PERIOD"
export OUT_DIR="$ROOT/asic_syn/output/TSP_Core_${PERIOD}ns"

mkdir -p "$OUT_DIR"
dc_shell -f "$SCRIPT_DIR/dc_tsp_core.tcl" | tee "$OUT_DIR/dc_shell.log"
