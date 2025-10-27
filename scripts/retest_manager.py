#!/usr/bin/env python3
"""
SmartSec-Eval Retest Manager

Automatically classifies vulnerabilities from Slither/Mythril reports and re-runs
affected pipeline stages for a given contract's results folder.

Usage examples:
  python3 scripts/retest_manager.py --contract BatchRegistry
  python3 scripts/retest_manager.py --outdir results/batchregistryresults

Writes:
  results/<contract>/retest_plan_<timestamp>.json
  results/<contract>/retest_summary_<timestamp>.txt
"""

from __future__ import annotations

import argparse
import datetime as _dt
import glob
import json
import os
import re
import subprocess
import sys
from typing import Dict, List


ROOT = os.path.dirname(os.path.dirname(__file__))
RESULTS_ROOT = os.path.join(ROOT, "results")
TS = _dt.datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")

CONTRACT_TO_DIR = {
    "BatchRegistry": "batchregistryresults",
    "RegistrationRegistry": "registrationregistryresults",
    "ProductRegistry": "productregistryresults",
    "ShipmentRegistry": "shipmentregistryresults",
    "ShipmentSegmentAcceptance": "shipmentsegmentacceptanceresults",
}


def classify_issue(msg: str) -> str:
    s = msg.lower()
    if any(k in s for k in ["reentrancy", "access control", "authorization", "authoriz", "overflow", "underflow", "auth bypass", "ownership", "unauthorized"]):
        return "CRITICAL"
    if any(k in s for k in ["timestamp", "equality", "pragma", "version", "block.timestamp", "== 0", "!= 0"]):
        return "MEDIUM"
    return "MINOR"


def resolve_results_dir(contract: str | None, outdir: str | None) -> str:
    if outdir:
        # Accept absolute or relative path; ensure under results/
        path = outdir
        if not os.path.isabs(path):
            path = os.path.join(ROOT, path)
        return path
    if not contract:
        # Default to BatchRegistry
        contract = "BatchRegistry"
    folder = CONTRACT_TO_DIR.get(contract, contract)
    if os.path.isabs(folder):
        return folder
    return os.path.join(RESULTS_ROOT, folder)


def analyze_reports(results_dir: str) -> Dict[str, List[str]]:
    vr_dir = os.path.join(results_dir, "vuln_reports")
    paths = glob.glob(os.path.join(vr_dir, "*.json"))
    summary = {"CRITICAL": [], "MEDIUM": [], "MINOR": []}
    for p in paths:
        try:
            with open(p, encoding="utf-8") as f:
                data = json.load(f)
            content = json.dumps(data)
            sev = classify_issue(content)
            summary[sev].append(os.path.basename(p))
        except Exception:
            # If parsing fails, treat as MINOR and still include filename
            summary["MINOR"].append(os.path.basename(p))
    return summary


def write_retest_plan(results_dir: str, summary: Dict[str, List[str]]) -> str:
    plan = {
        "timestamp": TS,
        "results_dir": results_dir,
        "severity_counts": {k: len(v) for k, v in summary.items()},
        "files": summary,
        "recommended_actions": [],
    }

    if summary["CRITICAL"]:
        plan["recommended_actions"] = [
            "run_slither",
            "run_mythril",
            "forge_test",
            "measure_tte",
            "measure_tte_improved",
            "aggregate_metrics",
            "plot_metrics",
        ]
    elif summary["MEDIUM"]:
        plan["recommended_actions"] = [
            "run_slither",
            "run_mythril",
            "aggregate_metrics",
        ]
    else:
        plan["recommended_actions"] = []

    out = os.path.join(results_dir, f"retest_plan_{TS}.json")
    os.makedirs(results_dir, exist_ok=True)
    with open(out, "w", encoding="utf-8") as f:
        json.dump(plan, f, indent=2)
    return out


def run_cmd(cmd: str) -> int:
    print(f"▶ {cmd}")
    try:
        return subprocess.run(cmd, shell=True, check=False).returncode
    except Exception as e:
        print(f"[warn] Failed: {cmd}: {e}", file=sys.stderr)
        return 1


def write_summary(results_dir: str, contract_label: str, summary: Dict[str, List[str]], cmds: List[str], rcodes: List[int]) -> str:
    out = os.path.join(results_dir, f"retest_summary_{TS}.txt")
    with open(out, "w", encoding="utf-8") as f:
        f.write(f"Retest Summary for {contract_label} @ {TS}\n")
        f.write("=" * 48 + "\n\n")
        for k in ("CRITICAL", "MEDIUM", "MINOR"):
            f.write(f"{k} Issues: {len(summary[k])}\n")
            for r in summary[k]:
                f.write(f"  - {r}\n")
            f.write("\n")

        if summary["CRITICAL"]:
            f.write("🔴 CRITICAL issues → full pipeline retest.\n\n")
        elif summary["MEDIUM"]:
            f.write("🟠 MEDIUM issues → analysis-only rerun.\n\n")
        else:
            f.write("🟢 MINOR or none → no rerun executed.\n\n")

        for c, rc in zip(cmds, rcodes):
            icon = "✔" if rc == 0 else "✖"
            f.write(f"{icon} Executed: {c} (rc={rc})\n")
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description="SmartSec-Eval Retest Manager")
    ap.add_argument("--contract", help="Contract name (e.g., BatchRegistry)", default="BatchRegistry")
    ap.add_argument("--outdir", help="Explicit results folder (e.g., results/batchregistryresults)")
    args = ap.parse_args()

    results_dir = resolve_results_dir(args.contract, args.outdir)
    contract_label = args.contract or os.path.basename(results_dir)

    summary = analyze_reports(results_dir)
    plan_path = write_retest_plan(results_dir, summary)
    print(f"Retest plan written: {plan_path}")

    cmds: List[str] = []
    if summary["CRITICAL"]:
        cmds = [
            "bash scripts/run_slither.sh",
            "bash scripts/run_mythril.sh",
            "forge test",
            "bash scripts/measure_tte.sh 3",
            "bash scripts/measure_tte_improved.sh 3",
            "python3 scripts/aggregate_metrics.py",
            "python3 scripts/plot_metrics.py",
        ]
    elif summary["MEDIUM"]:
        cmds = [
            "bash scripts/run_slither.sh",
            "bash scripts/run_mythril.sh",
            "python3 scripts/aggregate_metrics.py",
        ]
    else:
        cmds = []

    rcodes: List[int] = []
    for c in cmds:
        rcodes.append(run_cmd(c))

    summ_path = write_summary(results_dir, contract_label, summary, cmds, rcodes)
    print(f"✅ Retest summary saved → {summ_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
