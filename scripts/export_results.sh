#!/usr/bin/env bash
set -euo pipefail

# Export Forge test results to a CSV in the results/ folder.
# Runs all tests, captures verbose output, parses PASS/FAIL and gas per test.

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

# Stage 6: write into dedicated experiment folder
BASE_OUT="results/shipmentsegmentacceptanceresults"
LOG_DIR="$BASE_OUT/logs"
CSV_DIR="$BASE_OUT/csv"
mkdir -p "$LOG_DIR" "$CSV_DIR"

TS_LOG=$(date -u +%Y%m%dT%H%M%SZ)
RAW_FILE="${LOG_DIR}/forge-test-${TS_LOG}.log"
CSV_FILE="${CSV_DIR}/test_results_${TS_LOG}.csv"

# Run tests and capture raw output
forge test -vv | tee "$RAW_FILE"

RUN_TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Parse output into CSV
{
  echo "timestamp,suite,test,status,gas"
  awk -v ts="$RUN_TS" '
    BEGIN { suite = "" }
    
    /^Ran [0-9]+ tests for / {
      if (match($0, /Ran [0-9]+ tests for (.*)$/, m)) { suite = m[1] }
      next
    }

    /^\[(PASS|FAIL)\]/ {
      status = ""; test = ""; gas = ""
      if (match($0, /^\[(PASS|FAIL)\]/, s)) { status = s[1] }
      if (match($0, /^\[(PASS|FAIL)\] ([^ ]+)/, t)) { test = t[2] }
      if (match($0, /\(gas: *([0-9]+)\)/, g)) { gas = g[1] }
      # CSV: timestamp,suite,test,status,gas
      printf "%s,\"%s\",\"%s\",%s,%s\n", ts, suite, test, status, gas
      next
    }
  ' "$RAW_FILE"
} > "$CSV_FILE"

echo "CSV written: $CSV_FILE"
