#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

BASE_OUT="results/registrationregistryresults"
VR_DIR="$BASE_OUT/vuln_reports"
mkdir -p "$VR_DIR"

TS=$(date -u +%Y%m%dT%H%M%SZ)
OUT="${VR_DIR}/slither_${TS}.json"

echo "Running Slither static analysis (ShipmentSegmentAcceptance only)..."
# SegmentAcceptance-only: analyze specific contracts, no project-wide scan
OUT_BASE="${VR_DIR}/slither_baseline_${TS}.json"
OUT_IMP="${VR_DIR}/slither_improved_${TS}.json"

# Analyze baseline
slither contracts/ShipmentSegmentAcceptance.sol --json "$OUT_BASE" || true
echo "Baseline Slither report: $OUT_BASE"

# Analyze improved
slither contracts/ShipmentSegmentAcceptanceImproved.sol --json "$OUT_IMP" || true
echo "Improved Slither report: $OUT_IMP"
