#!/usr/bin/env python3
"""
Compute Security Scores from Slither, Mythril, and Echidna JSON reports.

Inputs (latest under results/vuln_reports/):
 - slither_*.json
 - mythril_*.json (baseline/improved)
 - echidna_*.json

Normalization schema for issues CSV:
 timestamp,tool,contract,issue_type,severity,description

Security Score per contract:
 score = 100 − (wC*Critical + wH*High + wM*Medium)
Weights loaded from tables/security_weights.json (default 5/3/1).

Also prints comparison table with Median TTE and Coverage read from
results/metrics_summary.csv, if available.
"""

from __future__ import annotations

import csv
import glob
import json
import os
import re
import sys
from datetime import datetime, timezone

try:
    import pandas as pd
except Exception as e:
    print("[error] pandas is required. Install with: pip install pandas", file=sys.stderr)
    raise


ROOT = os.path.dirname(os.path.dirname(__file__))
BASE_OUT = os.path.join(ROOT, "results", "shipmentsegmentacceptanceresults")
RESULTS_DIR = BASE_OUT
VULN_DIR = os.path.join(BASE_OUT, "vuln_reports")
WEIGHTS_PATH = os.path.join(ROOT, "tables", "security_weights.json")


def now_utc() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def load_weights() -> dict:
    default = {"Critical": 5, "High": 3, "Medium": 1}
    try:
        with open(WEIGHTS_PATH, encoding="utf-8") as f:
            data = json.load(f)
            default.update({k: int(v) for k, v in data.items()})
    except FileNotFoundError:
        pass
    return default


def list_latest(pattern: str) -> list[str]:
    return sorted(glob.glob(os.path.join(VULN_DIR, pattern)))


def norm_sev(s: str | None) -> str:
    if not s:
        return "Unknown"
    s = s.strip().lower()
    if s in ("critical", "very high"):
        return "Critical"
    if s in ("high",):
        return "High"
    if s in ("medium",):
        return "Medium"
    if s in ("low", "info", "informational", "warning"):
        return s.capitalize()
    return s.capitalize()


def extract_contract_from_path(path: str) -> str:
    base = os.path.basename(path)
    name, _ = os.path.splitext(base)
    return name


def parse_slither(path: str) -> pd.DataFrame:
    # Slither JSON schema: top-level 'success': true, 'error': [], 'results': { 'detectors': [ { 'check', 'impact', 'description', 'elements': [...] } ] }
    rows = []
    ts = now_utc()
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
    except Exception:
        return pd.DataFrame(columns=["timestamp", "tool", "contract", "issue_type", "severity", "description"])

    detectors = (data.get("results") or {}).get("detectors") or []
    for d in detectors:
        issue = d.get("check") or d.get("title") or "Slither finding"
        sev = d.get("impact") or d.get("severity") or "Unknown"
        desc = d.get("description") or ""
        elements = d.get("elements") or []
        if elements:
            for e in elements:
                # Try get contract name from source mapping or element fields
                contract = (
                    (e.get("source_mapping") or {}).get("contract")
                    or e.get("contract")
                    or extract_contract_from_path((e.get("source_mapping") or {}).get("filename", ""))
                    or "Unknown"
                )
                rows.append([ts, "slither", contract, issue, norm_sev(sev), desc])
        else:
            rows.append([ts, "slither", "Unknown", issue, norm_sev(sev), desc])

    return pd.DataFrame(rows, columns=["timestamp", "tool", "contract", "issue_type", "severity", "description"])


def parse_mythril(path: str) -> pd.DataFrame:
    # Mythril JSON: { "issues": [ {"title","description","severity","contract"?} ] }
    rows = []
    ts = now_utc()
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
    except Exception:
        return pd.DataFrame(columns=["timestamp", "tool", "contract", "issue_type", "severity", "description"])

    for i in data.get("issues", []) or []:
        issue = i.get("title") or i.get("swc-id") or "Mythril issue"
        sev = i.get("severity") or "Unknown"
        desc = i.get("description") or ""
        contract = i.get("contract") or i.get("filename") or "Unknown"
        contract = extract_contract_from_path(contract)
        rows.append([ts, "mythril", contract, issue, norm_sev(sev), desc])

    return pd.DataFrame(rows, columns=["timestamp", "tool", "contract", "issue_type", "severity", "description"])


def parse_echidna(path: str) -> pd.DataFrame:
    # Echidna JSON format varies; attempt to gather failed properties as issues.
    rows = []
    ts = now_utc()
    try:
        with open(path, encoding="utf-8") as f:
            content = f.read()
            # Echidna may emit JSON lines; try to parse last JSON object
            try:
                data = json.loads(content)
            except json.JSONDecodeError:
                # Try last non-empty line
                lines = [ln for ln in content.strip().splitlines() if ln.strip()]
                data = json.loads(lines[-1]) if lines else {}
    except Exception:
        return pd.DataFrame(columns=["timestamp", "tool", "contract", "issue_type", "severity", "description"])

    # Heuristic parsing
    failures = []
    if isinstance(data, dict):
        if "failedTests" in data:
            failures = list((data.get("failedTests") or {}).keys())
        elif "tests" in data and isinstance(data["tests"], dict):
            # echidna 2.x style
            for k, v in data["tests"].items():
                if isinstance(v, dict) and (v.get("status") == "FAIL" or v.get("foundCounterexample")):
                    failures.append(k)
    # Record failures as Medium severity by default
    for prop in failures:
        rows.append([ts, "echidna", "Invariants", prop, "Medium", "Property failed under fuzzing"])

    return pd.DataFrame(rows, columns=["timestamp", "tool", "contract", "issue_type", "severity", "description"])


def aggregate_scores(df: pd.DataFrame, weights: dict) -> pd.DataFrame:
    # Count severities of interest per contract
    sev_map = {k.capitalize(): int(v) for k, v in weights.items()}
    counts = (
        df[df["severity"].isin(sev_map.keys())]
          .groupby(["contract", "severity"]).size()
          .unstack(fill_value=0)
    )
    # Ensure columns
    for col in ["Critical", "High", "Medium"]:
        if col not in counts.columns:
            counts[col] = 0
    # Compute score
    def score_row(row):
        penalty = 0
        for sev, w in sev_map.items():
            penalty += int(row.get(sev, 0)) * int(w)
        return max(0, 100 - penalty)

    counts["SecurityScore"] = counts.apply(score_row, axis=1)
    counts = counts.reset_index()
    return counts[["contract", "Critical", "High", "Medium", "SecurityScore"]]


def read_metrics_summary() -> dict:
    path = os.path.join(BASE_OUT, "csv", "metrics_summary.csv")
    out = {}
    if not os.path.isfile(path):
        return out
    try:
        with open(path, newline="", encoding="utf-8") as f:
            r = csv.DictReader(f)
            for row in r:
                out[row.get("contract", "")] = {
                    "median_tte_s": row.get("median_tte_s"),
                    "coverage_pct": row.get("coverage_pct"),
                }
    except Exception:
        pass
    return out


def main() -> int:
    os.makedirs(VULN_DIR, exist_ok=True)
    weights = load_weights()

    # Collect and parse all reports
    frames = []
    for p in list_latest("slither_*.json"):
        frames.append(parse_slither(p))
    for p in list_latest("mythril_*.json"):
        frames.append(parse_mythril(p))
    for p in list_latest("echidna_*.json"):
        frames.append(parse_echidna(p))

    if frames:
        all_issues = pd.concat(frames, ignore_index=True)
    else:
        all_issues = pd.DataFrame(columns=["timestamp", "tool", "contract", "issue_type", "severity", "description"])

    # Write normalized CSV snapshot
    norm_path = os.path.join(VULN_DIR, f"normalized_{datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')}.csv")
    all_issues.to_csv(norm_path, index=False)

    # Aggregate scores per contract
    if len(all_issues) == 0:
        print("No issues found in reports; defaulting scores to 100 for both contracts.")
        scores = pd.DataFrame([
            {"contract": "ProductRegistry", "Critical": 0, "High": 0, "Medium": 0, "SecurityScore": 100},
            {"contract": "ProductRegistryImproved", "Critical": 0, "High": 0, "Medium": 0, "SecurityScore": 100},
        ])
    else:
        scores = aggregate_scores(all_issues, weights)

    # Save security scores CSV
    os.makedirs(os.path.join(BASE_OUT, "csv"), exist_ok=True)
    scores_path = os.path.join(BASE_OUT, "csv", "security_scores.csv")
    scores.to_csv(scores_path, index=False)

    # Comparison table using metrics summary if available
    metrics = read_metrics_summary()
    # Map names to be resilient
    def get_metric(name_frag):
        for k, v in metrics.items():
            if name_frag in k:
                return v
        return {"median_tte_s": "N/A", "coverage_pct": "N/A"}

    # Prepare display for baseline and improved
    def get_score(contract_name):
        row = scores[scores["contract"].str.contains(contract_name, case=False, regex=False)]
        if row.empty:
            return "N/A"
        return str(int(row.iloc[0]["SecurityScore"]))

    b_metrics = get_metric("ProductRegistry (Baseline)")
    i_metrics = get_metric("ProductRegistryImproved")

    b_score = get_score("ProductRegistry")
    i_score = get_score("ProductRegistryImproved")

    print("\nSecurity Summary")
    print("----------------")
    print("Contract | Median TTE (s) | Coverage (%) | Security Score")
    print("---------+-----------------+--------------+---------------")
    print(f"Baseline | {b_metrics.get('median_tte_s','N/A'):>15} | {b_metrics.get('coverage_pct','N/A'):>12} | {b_score:>13}")
    print(f"Improved | {i_metrics.get('median_tte_s','N/A'):>15} | {i_metrics.get('coverage_pct','N/A'):>12} | {i_score:>13}")

    print(f"\nNormalized issues CSV: {norm_path}")
    print(f"Security scores CSV:   {scores_path}")

    # Compute % Security Improvement from TTE medians if available
    def _to_float(v):
        try:
            return float(v)
        except Exception:
            return None
    _b_med = _to_float(b_metrics.get('median_tte_s'))
    _i_med = _to_float(i_metrics.get('median_tte_s'))
    _delta_pct = None
    if _b_med and _i_med and _b_med > 0:
        _delta_pct = ((_i_med / _b_med) - 1.0) * 100.0

    # Auto Retest metadata (Last Auto Retest, ReTest Count)
    retest_summaries = sorted(glob.glob(os.path.join(BASE_OUT, "retest_summary_*.txt")))
    retest_count = len(retest_summaries)
    last_retest_ts = "N/A"
    if retest_count > 0:
        import re as _re
        m = _re.search(r"retest_summary_(\d{8}T\d{6}Z)\.txt$", retest_summaries[-1])
        last_retest_ts = m.group(1) if m else "(unknown)"
    print(f"Last Auto Retest: {last_retest_ts} | ReTest Count: {retest_count}")

    # Write experiment README summary under BASE_OUT
    ts = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    readme_path = os.path.join(BASE_OUT, f"README_summary_{ts}.txt")
    try:
        with open(readme_path, 'w', encoding='utf-8') as fh:
            fh.write("SmartSec-Eval Summary\n")
            fh.write("====================\n")
            fh.write(f"Run: {now_utc()}\n\n")
            fh.write("Contract\n")
            fh.write("  ProductRegistry\n\n")
            fh.write("Auto Retest\n")
            fh.write(f"  Last:  {last_retest_ts}\n")
            fh.write(f"  Count: {retest_count}\n\n")
            fh.write("Median TTE (s)\n")
            fh.write(f"  Baseline: {b_metrics.get('median_tte_s','N/A')}\n")
            fh.write(f"  Improved: {i_metrics.get('median_tte_s','N/A')}\n\n")
            fh.write("Coverage (%)\n")
            fh.write(f"  Overall: {b_metrics.get('coverage_pct','N/A')}\n\n")
            fh.write("Security Scores\n")
            fh.write(f"  Baseline: {b_score}\n")
            fh.write(f"  Improved: {i_score}\n\n")
            if _delta_pct is not None:
                fh.write("% Security Improvement\n")
                fh.write(f"  +{_delta_pct:.2f}% (by TTE)\n\n")
            # Vulnerability findings summary by severity
            if not all_issues.empty:
                sev_counts = all_issues['severity'].value_counts().to_dict()
                fh.write("Vulnerability Findings\n")
                total_issues = len(all_issues)
                fh.write(f"  Total issues: {total_issues}\n")
                for k in sorted(sev_counts.keys()):
                    fh.write(f"  {k}: {sev_counts[k]}\n")
            else:
                fh.write("Vulnerability Findings\n  No issues found in reports.\n")
    except Exception as e:
        print(f"[warn] Failed to write README summary: {e}", file=sys.stderr)
        readme_path = "(failed)"

    print(f"README summary:        {readme_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
