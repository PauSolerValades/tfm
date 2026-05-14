#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DYNAMIC_DIR="$SCRIPT_DIR/../dynamic-posts"
SIM_BIN="$DYNAMIC_DIR/zig-out/bin/bskysim-v3"
CONFIG="$DYNAMIC_DIR/simconfs/all1.json"
DATAFILE="$SCRIPT_DIR/data/sn_topo_500_3_0.6.json"
RESULTS="$DYNAMIC_DIR/results"
VALIDATOR="$SCRIPT_DIR/validate_trace.py"

# Ensure results dir exists
mkdir -p "$RESULTS"

COUNT=0
while true; do
    COUNT=$((COUNT + 1))

    # Clean previous results
    rm -f "$RESULTS"/*.bin "$RESULTS"/*.jsonl

    # Run simulation from the dynamic-posts directory
    echo "[run $COUNT] Running simulation..."
    (cd "$DYNAMIC_DIR" && "$SIM_BIN" "$CONFIG" "$DATAFILE") > /dev/null 2>&1
    echo "[run $COUNT] Simulation done."

    # Run validator
    echo "[run $COUNT] Running validator..."
    if uv run "$VALIDATOR" \
        "$CONFIG" \
        "$DATAFILE" \
        "$RESULTS/create_trace.jsonl" \
        "$RESULTS/action_trace.jsonl" \
        "$RESULTS/session_trace.jsonl" \
        "$RESULTS/propagate_trace.jsonl"; then
        echo "[run $COUNT] ✓ Passed"
    else
        echo ""
        echo "==========================================="
        echo "  VALIDATION FAILED on run $COUNT!"
        echo "  Trace files preserved in $RESULTS/"
        echo "==========================================="
        exit 1
    fi
done
