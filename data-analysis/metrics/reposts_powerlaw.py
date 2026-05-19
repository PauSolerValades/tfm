"""Reposts Power-law — fit power-law to repost counts per post (CTIC model).

Usage as module:
    from metrics.reposts_powerlaw import compute
    gamma, fig = compute(action_df, output_dir="img")

Produces: rank-frequency log-log plot + CCDF with MLE Pareto fit.
"""

from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import polars as pl
from scipy import stats


def compute(action_df: pl.DataFrame, output_dir: str | Path = "img", tag: str = ""):
    """Fit power-law to repost counts and generate plots.

    Returns (gamma, repost_counts_df).
    """
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    prefix = f"{tag}_" if tag else ""

    repost_counts = (
        action_df
        .filter(pl.col("type") == "repost")
        .group_by("post_id")
        .len(name="reposts")
        .sort("reposts", descending=True)
    )

    counts = repost_counts["reposts"].to_numpy()
    if len(counts) == 0:
        print("[reposts_powerlaw] No reposts found.")
        return None, repost_counts

    # MLE fit to Pareto (loc=0 → pure power-law, shape = γ)
    shape, _, scale = stats.pareto.fit(counts, floc=0)
    gamma = float(shape)
    x_min = float(scale)

    sorted_counts = np.sort(counts)
    ccdf = 1.0 - np.arange(1, len(sorted_counts) + 1) / len(sorted_counts)

    x_fit = np.logspace(np.log10(x_min), np.log10(sorted_counts.max()), 200)
    ccdf_fit = np.clip((x_min / x_fit) ** gamma, 0, 1)

    # Plot
    fig, (ax0, ax1) = plt.subplots(1, 2, figsize=(14, 5.5))

    ranks = np.arange(1, len(counts) + 1)
    ax0.loglog(ranks, counts, 'o', markersize=3, alpha=0.7, color='#1DA1F2')
    ax0.set_xlabel("Rank")
    ax0.set_ylabel("Number of Reposts")
    ax0.set_title(f"Reposts per Post (rank-frequency)\nγ = {gamma:.3f} (MLE)")
    ax0.grid(True, alpha=0.3)

    ax1.loglog(sorted_counts, ccdf, 'o', markersize=3, alpha=0.7,
               label="Data", color='#1DA1F2')
    ax1.loglog(x_fit, ccdf_fit, '--', linewidth=2,
               label=f"Pareto fit (γ={gamma:.2f})", color='#FF7F50')
    ax1.set_xlabel("Reposts")
    ax1.set_ylabel("P(X ≥ x)")
    ax1.set_title("Reposts CCDF")
    ax1.legend()
    ax1.grid(True, alpha=0.3)

    plt.tight_layout()
    path = output_dir / f"{prefix}reposts_powerlaw.png"
    fig.savefig(path, dpi=150)
    plt.close(fig)

    print(f"[reposts_powerlaw] γ = {gamma:.3f} (x_min = {x_min:.1f})  →  {path}")
    return {"gamma": gamma, "x_min": x_min}, repost_counts


if __name__ == "__main__":
    import sys
    if len(sys.argv) < 2:
        print("Usage: python reposts_powerlaw.py <action_trace.jsonl>")
        sys.exit(1)
    df = pl.read_ndjson(sys.argv[1])
    compute(df)
