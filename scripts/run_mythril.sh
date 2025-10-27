#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

BASE_OUT_DIR="results/shipmentsegmentacceptanceresults"
VR_DIR="$BASE_OUT_DIR/vuln_reports"
mkdir -p "$VR_DIR"

TS=$(date -u +%Y%m%dT%H%M%SZ)

BASE_OUT="${VR_DIR}/mythril_baseline_${TS}.json"
IMPR_OUT="${VR_DIR}/mythril_improved_${TS}.json"

echo "Running Mythril on baseline (ShipmentSegmentAcceptance)..."
myth analyze contracts/ShipmentSegmentAcceptance.sol -o json > "$BASE_OUT"
echo "Mythril baseline report: $BASE_OUT"

echo "Running Mythril on improved (ShipmentSegmentAcceptanceImproved)..."
myth analyze contracts/ShipmentSegmentAcceptanceImproved.sol -o json > "$IMPR_OUT"
echo "Mythril improved report: $IMPR_OUT"
