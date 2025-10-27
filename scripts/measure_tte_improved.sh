#!/usr/bin/env bash
set -euo pipefail

# Measure TTE-like timings for the improved invariant that should PASS.
# Usage: bash scripts/measure_tte_improved.sh [TRIALS]

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

TRIALS="${1:-3}"

BASE_OUT="results/shipmentsegmentacceptanceresults"
CSV_DIR="$BASE_OUT/csv"
LOG_DIR="$BASE_OUT/logs"
mkdir -p "$CSV_DIR" "$LOG_DIR"

TS=$(date -u +%Y%m%dT%H%M%SZ)
CSV_FILE="${CSV_DIR}/forge_tte_improved_results_${TS}.csv"

echo "timestamp,mode,trial,duration,status,logpath" > "$CSV_FILE"

total=0
count=0

for i in $(seq 1 "$TRIALS"); do
  START_TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  LOG="${LOG_DIR}/log_improved_${i}.txt"

  EXIT_CODE=0
  DURATION=""
  set +e
  if command -v /usr/bin/time >/dev/null 2>&1; then
    DURATION=$( /usr/bin/time -f '%e' bash -c "forge test --match-contract SegmentInvariants --match-test invariant_Improved_Blocks_Attacker_Update -vv > '$LOG' 2>&1" 2>&1 )
    EXIT_CODE=$?
  else
    SECONDS=0
    forge test --match-contract SegmentInvariants --match-test invariant_Improved_Blocks_Attacker_Update -vv > "$LOG" 2>&1
    EXIT_CODE=$?
    DURATION=$SECONDS
  fi
  set -e

  STATUS="PASS"
  if [[ $EXIT_CODE -ne 0 ]]; then STATUS="FAIL"; fi

  # Accumulate average from numeric durations only (no python dependency)
  if [[ $DURATION =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    total=$(awk -v a="$total" -v b="$DURATION" 'BEGIN{printf "%.6f", a + b}')
    count=$((count+1))
  fi

  echo "Run ${i}/${TRIALS}: ${STATUS} in ${DURATION}s (log: $LOG)"
  echo "${START_TS},improved,${i},${DURATION},${STATUS},${LOG}" >> "$CSV_FILE"
done

if [[ $count -gt 0 ]]; then
  avg=$(awk -v a="$total" -v c="$count" 'BEGIN{ if (c>0) printf "%.3f", a/c; else print "0" }')
  echo "Average duration over ${count} runs: ${avg}s"
else
  echo "Average duration unavailable (no numeric durations)."
fi

echo "CSV written: $CSV_FILE"
