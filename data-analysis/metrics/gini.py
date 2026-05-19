"""Gini Coefficient — inequality of information inflow and reposts generated.

Usage as module:
    from metrics.gini import compute
    results = compute(propagate_df, action_df, output_dir="img")

Returns dict with gini_information_inflow and gini_reposts_generated.
Produces Lorenz curve plots.
"""

from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import polars as pl


def _gini(values: np.ndarray) -> float:
    """Compute the Gini coefficient."""
    if len(values) == 0:
        return 0.0
    sorted_vals = np.sort(values)
    n = len(sorted_vals)
    return (2 * np.sum(np.arange(1, n + 1) * sorted_vals)
            - (n + 1) * np.sum(sorted_vals)) / (n * np.sum(sorted_vals))


def _lorenz(values: np.ndarray):
    """Return (x, y) for Lorenz curve."""
    sv = np.sort(values)
    n = len(sv)
    cs = np.cumsum(sv)
    x = np.arange(0, n + 1) / n
    y = np.concatenate([[0], cs / cs[-1]])
    return x, y


def compute(propagate_df: pl.DataFrame, action_df: pl.DataFrame,
            output_dir: str | Path = "img", tag: str = ""):
    """Compute Gini for inflow and reposts, plot Lorenz curves."""
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    prefix = f"{tag}_" if tag else ""

    # Inflow: posts received (from propagate)
    inflow = (
        propagate_df
        .group_by("user_id")
        .len(name="posts_received")
        .sort("posts_received")
    )
    inflow_vals = inflow["posts_received"].to_numpy()

    # Reposts generated
    reposts = (
        action_df
        .filter(pl.col("type") == "repost")
        .group_by("user_id")
        .len(name="repots_made")
        .sort("repots_made")
    )
    repost_vals = reposts["repots_made"].to_numpy()

    gini_inflow = _gini(inflow_vals)
    gini_reposts = _gini(repost_vals)

    print(f"[gini] Information inflow  Gini = {gini_inflow:.4f}")
    print(f"[gini] Reposts generated   Gini = {gini_reposts:.4f}")

    # Plot
    fig, (ax0, ax1) = plt.subplots(1, 2, figsize=(12, 5.5))

    for ax, vals, label, color in [
        (ax0, inflow_vals, "Information Inflow", '#1DA1F2'),
        (ax1, repost_vals, "Reposts Generated", '#FF7F50'),
    ]:
        x, y = _lorenz(vals)
        ax.fill_between(x, x, y, alpha=0.3, color=color)
        ax.plot(x, y, '-', linewidth=2, color=color)
        ax.plot([0, 1], [0, 1], '--', color='gray', alpha=0.7)
        ax.set_xlabel("Cumulative fraction of users")
        ax.set_ylabel("Cumulative fraction")
        ax.set_title(f"{label}\nGini = {_gini(vals):.4f}")

    plt.tight_layout()
    path = output_dir / f"{prefix}gini_lorenz.png"
    fig.savefig(path, dpi=150)
    plt.close(fig)
    print(f"[gini]  →  {path}")

    return {
        "gini_information_inflow": round(float(gini_inflow), 4),
        "gini_reposts_generated": round(float(gini_reposts), 4),
    }


if __name__ == "__main__":
    import sys
    if len(sys.argv) < 3:
        print("Usage: python gini.py <propagate_trace.jsonl> <action_trace.jsonl>")
        sys.exit(1)
    compute(pl.read_ndjson(sys.argv[1]), pl.read_ndjson(sys.argv[2]))
