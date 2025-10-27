#!/usr/bin/env bash
set -euo pipefail

# Measures Time-to-Exposure (TTE) for the baseline invariant by running
# the Invariants contract (which intentionally fails on attacker update)
# and recording wall-clock time until forge exits with failure.

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

RUNS="${1:-1}"

BASE_OUT="results/shipmentsegmentacceptanceresults"
CSV_DIR="$BASE_OUT/csv"
mkdir -p "$CSV_DIR"

TS=$(date -u +%Y%m%dT%H%M%SZ)
CSV_FILE="${CSV_DIR}/forge_tte_results_${TS}.csv"
TEST_NAME='SegmentInvariants::invariant_Baseline_Fails_On_Attacker_Update'

echo "timestamp,test_name,elapsed_seconds,status,run_count" > "$CSV_FILE"

for i in $(seq 1 "$RUNS"); do
  echo "Run ${i}/${RUNS}: executing invariants..."
  START_TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  EXIT_CODE=0
  ELAPSED=""
  set +e
  if command -v /usr/bin/time >/dev/null 2>&1; then
    ELAPSED=$( /usr/bin/time -f '%e' bash -c "forge test --match-contract SegmentInvariants --match-test invariant_Baseline_Fails_On_Attacker_Update -vv > /dev/null 2>&1" 2>&1 )
    EXIT_CODE=$?
  else
    SECONDS=0
    forge test --match-contract SegmentInvariants --match-test invariant_Baseline_Fails_On_Attacker_Update -vv > /dev/null 2>&1
    EXIT_CODE=$?
    ELAPSED=$SECONDS
  fi
  set -e

  STATUS="PASS"
  if [[ $EXIT_CODE -ne 0 ]]; then STATUS="FAIL"; fi

  echo "TTE seconds: ${ELAPSED} | Status: ${STATUS}"
  echo "${START_TS},${TEST_NAME},${ELAPSED},${STATUS},${i}" >> "$CSV_FILE"
done

echo "CSV written: $CSV_FILE"
