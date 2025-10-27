#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

BASE_OUT="results/shipmentsegmentacceptanceresults"
COV_DIR="$BASE_OUT/coverage"
mkdir -p "$COV_DIR"

TS=$(date -u +%Y%m%dT%H%M%SZ)
SUMMARY_FILE="${COV_DIR}/coverage_${TS}.txt"
LCOV_FILE="${COV_DIR}/coverage_${TS}.lcov"

# Coverage summary
forge coverage --report summary | tee "$SUMMARY_FILE" >/dev/null

# LCOV output
forge coverage --report lcov > "$LCOV_FILE"

echo "Coverage summary: $SUMMARY_FILE"
echo "Coverage LCOV:   $LCOV_FILE"
