#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

BASE_OUT="results/registrationregistryresults"
VR_DIR="$BASE_OUT/vuln_reports"
mkdir -p "$VR_DIR"

TS=$(date -u +%Y%m%dT%H%M%SZ)
OUT="${VR_DIR}/echidna_${TS}.json"

echo "Running Echidna property-based testing..."

if command -v echidna-test >/dev/null 2>&1; then
  echidna-test . --contract Invariants --config echidna.yaml --json > "$OUT"
  echo "Echidna report: $OUT"
  exit 0
fi

echo "Local echidna-test not found; using Docker image 'trailofbits/echidna'"
if ! command -v docker >/dev/null 2>&1; then
  echo "[error] Docker is not installed or not on PATH. Install Docker Desktop and retry." >&2
  exit 1
fi

# Run Echidna in Docker container, mounting the project into /project
docker run --rm -v "$PWD":/project -w /project trailofbits/echidna \
  echidna-test . --contract Invariants --config echidna.yaml --json > "$OUT"
echo "Echidna report: $OUT"
