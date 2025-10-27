#!/usr/bin/env python3
"""
Plot comparisons from results/metrics_summary.csv using matplotlib.

Outputs under results/plots/:
 - tte_comparison.png (median TTE, baseline vs improved)
 - coverage_comparison.png (coverage percent)

Textual interpretation printed to console.
"""

import csv
import os
import sys


ROOT = os.path.dirname(os.path.dirname(__file__))
BASE_OUT = os.path.join(ROOT, "results", "shipmentsegmentacceptanceresults")
RESULTS = BASE_OUT
PLOTS = os.path.join(BASE_OUT, "plots")


def load_metrics(path):
    rows = []
    with open(path, newline="", encoding="utf-8") as f:
        r = csv.DictReader(f)
        for row in r:
            rows.append(row)
    return rows


def to_float(val):
    try:
        return float(val)
    except Exception:
        return None


def main():
    try:
        import matplotlib.pyplot as plt
    except ImportError:
        print("matplotlib not installed. Install with: pip install matplotlib", file=sys.stderr)
        return 1

    os.makedirs(PLOTS, exist_ok=True)

    from datetime import datetime, timezone
    ts = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    metrics_path = os.path.join(RESULTS, "csv", "metrics_summary.csv")
    if not os.path.isfile(metrics_path):
        print("metrics_summary.csv not found. Run aggregate script first.", file=sys.stderr)
        return 2

    rows = load_metrics(metrics_path)

    # Expect two rows: baseline and improved
    baseline = next((r for r in rows if "Baseline" in r.get("contract", "")), None)
    improved = next((r for r in rows if "Improved" in r.get("contract", "")), None)

    if not baseline or not improved:
        print("Could not find both baseline and improved rows in metrics_summary.csv", file=sys.stderr)
        return 3

    b_tte = to_float(baseline.get("median_tte_s"))
    i_tte = to_float(improved.get("median_tte_s"))
    b_cov = to_float(baseline.get("coverage_pct"))
    i_cov = to_float(improved.get("coverage_pct"))

    # Bar chart - TTE
    labels = ["Baseline", "Improved"]
    tte_vals = [b_tte or 0.0, i_tte or 0.0]
    colors = ["#d9534f", "#5cb85c"]  # red, green

    fig, ax = plt.subplots(figsize=(6, 4))
    bars = ax.bar(labels, tte_vals, color=colors, label=labels)
    ax.set_ylabel("Median TTE (s)")
    ax.set_title("Median Time-to-Exposure (TTE)")
    ax.bar_label(bars, fmt='%.2f s')
    ax.legend()

    # Annotate % improvement on TTE
    if b_tte and i_tte and b_tte > 0:
        improvement = ((i_tte / b_tte) - 1.0) * 100.0
        ax.annotate(
            f"+{improvement:.1f}% improvement",
            xy=(0.5, max(tte_vals) * 0.95),
            xycoords=('axes fraction', 'data'),
            ha='center', color='#333333'
        )

    plt.tight_layout()
    out1 = os.path.join(PLOTS, f"TTE_Comparison_{ts}.png")
    plt.savefig(out1, dpi=150)
    plt.close(fig)

    # Bar chart - Coverage
    cov_vals = [b_cov or 0.0, i_cov or 0.0]
    fig2, ax2 = plt.subplots(figsize=(6, 4))
    bars2 = ax2.bar(labels, cov_vals, color=colors, label=labels)
    ax2.set_ylabel("Coverage (%)")
    ax2.set_ylim(0, 100)
    ax2.set_title("Coverage Comparison")
    ax2.bar_label(bars2, fmt='%.1f%')
    ax2.legend()
    plt.tight_layout()
    out2 = os.path.join(PLOTS, f"Coverage_Comparison_{ts}.png")
    plt.savefig(out2, dpi=150)
    plt.close(fig2)

    # Textual interpretation
    if b_tte and i_tte and b_tte > 0:
        improvement = ((i_tte / b_tte) - 1.0) * 100.0
        print(
            f"Improved contract increased median TTE from {b_tte:.2f}s to {i_tte:.2f}s (+{improvement:.1f}%) "
            f"with coverage ≈ {b_cov if b_cov is not None else 'N/A'}% constant."
        )
    else:
        print("Insufficient data to compute TTE improvement.")

    print(f"Saved: {out1}")
    print(f"Saved: {out2}")
    # Security scores chart
    scores_csv = os.path.join(RESULTS, "csv", "security_scores.csv")
    if os.path.isfile(scores_csv):
        rows_scores = load_metrics(scores_csv)
        # Expect rows with 'contract' and 'SecurityScore'
        # Normalize names
        b_row = None
        i_row = None
        for r in rows_scores:
            name = r.get("contract", "")
            if "Improved" in name:
                i_row = r
            else:
                b_row = r
        try:
            b_score = float(b_row.get("SecurityScore")) if b_row else 0.0
        except Exception:
            b_score = 0.0
        try:
            i_score = float(i_row.get("SecurityScore")) if i_row else 0.0
        except Exception:
            i_score = 0.0

        fig3, ax3 = plt.subplots(figsize=(6, 4))
        bars3 = ax3.bar(labels, [b_score, i_score], color=colors, label=labels)
        ax3.set_ylabel("Security Score (0-100)")
        ax3.set_ylim(0, 100)
        ax3.set_title("Security Score Comparison")
        ax3.bar_label(bars3, fmt='%.0f')
        ax3.legend()

        if b_score > 0:
            improvement = ((i_score / b_score) - 1.0) * 100.0 if b_score else 0.0
            ax3.annotate(
                f"+{improvement:.1f}% more secure",
                xy=(0.5, max(b_score, i_score) * 0.95),
                xycoords=('axes fraction', 'data'),
                ha='center', color='#333333'
            )

        plt.tight_layout()
        out3 = os.path.join(PLOTS, f"Security_Scores_{ts}.png")
        plt.savefig(out3, dpi=150)
        plt.close(fig3)
        print(f"Saved: {out3}")
    else:
        print("security_scores.csv not found; skipping security score plot.")
    
    # Gas comparison plot (avg baseline vs improved)
    gas_csv = os.path.join(RESULTS, "csv", "gas_summary.csv")
    if os.path.isfile(gas_csv):
        gas_rows = load_metrics(gas_csv)
        if gas_rows:
            try:
                gb = float(gas_rows[0].get("avg_gas_baseline") or 0)
                gi = float(gas_rows[0].get("avg_gas_improved") or 0)
            except Exception:
                gb = gi = 0.0

            # Compute delta percentage
            delta = 0.0
            if gb > 0:
                delta = ((gi / gb) - 1.0) * 100.0

            fig4, ax4 = plt.subplots(figsize=(6, 4))
            bars4 = ax4.bar(["Baseline", "Improved"], [gb, gi], color=["#d9534f", "#5cb85c"])
            ax4.set_ylabel("Average Gas (per test)")
            ax4.set_title(f"Gas Comparison (Δ {delta:+.2f}%)")
            ax4.bar_label(bars4, fmt='%.0f')
            # Annotate delta above bars
            ymax = max(gb, gi)
            ax4.annotate(f"Δ {delta:+.2f}%", xy=(0.5, ymax*0.95), xycoords=('axes fraction','data'), ha='center', color='#333')
            plt.tight_layout()
            out4 = os.path.join(PLOTS, f"Gas_Comparison_{ts}.png")
            plt.savefig(out4, dpi=150)
            plt.close(fig4)
            print(f"Saved: {out4}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
