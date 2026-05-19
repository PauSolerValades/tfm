"""Post Lifetimes — first-repost to last-repost span per post.

Usage as module:
    from metrics.post_lifetimes import compute
    results = compute(action_df, create_df, output_dir="img")

Returns dict with summary stats. Produces histograms + CCDF plots.
"""

from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import polars as pl
from scipy import stats


def compute(action_df: pl.DataFrame, create_df: pl.DataFrame, output_dir: str | Path = "img", tag: str = ""):
    """Compute post lifetimes and generate plots."""
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    prefix = f"{tag}_" if tag else ""

    # Repost boundaries per post
    repost_times = (
        action_df
        .filter(pl.col("type") == "repost")
        .group_by("post_id")
        .agg([
            pl.col("time").min().alias("first_repost"),
            pl.col("time").max().alias("last_repost"),
        ])
    )

    creation_times = create_df.select([
        "post_id",
        pl.col("time").alias("creation_time"),
    ])

    lifetimes = repost_times.join(creation_times, on="post_id", how="left")
    lifetimes = lifetimes.with_columns([
        (pl.col("last_repost") - pl.col("first_repost")).alias("lifetime_repost"),
        (pl.col("last_repost") - pl.col("creation_time")).alias("lifetime_total"),
    ])

    lt = lifetimes["lifetime_repost"].drop_nulls().to_numpy()
    lt_total = lifetimes["lifetime_total"].drop_nulls().to_numpy()

    all_ids = set(create_df["post_id"].to_list())
    reposted_ids = set(repost_times["post_id"].to_list())
    never_reposted = len(all_ids) - len(reposted_ids)
    pct_never = 100 * never_reposted / len(all_ids) if all_ids else 0

    print(f"[post_lifetimes] {len(all_ids)} posts, {never_reposted} never reposted ({pct_never:.1f}%)")

    if len(lt) == 0:
        print("[post_lifetimes] No reposted posts — skipping.")
        return {"never_reposted": never_reposted, "pct_never_reposted": round(pct_never, 2)}

    print(f"  repost span  — min: {lt.min():.1f}  median: {np.median(lt):.1f}  "
          f"mean: {lt.mean():.1f}  p90: {np.percentile(lt, 90):.1f}  max: {lt.max():.1f}")
    print(f"  creation→end — min: {lt_total.min():.1f}  median: {np.median(lt_total):.1f}  "
          f"mean: {lt_total.mean():.1f}  p90: {np.percentile(lt_total, 90):.1f}  max: {lt_total.max():.1f}")

    # Optional power-law fit on positive lifetimes
    lt_pos = lt[lt > 0]
    gamma_lt = None
    if len(lt_pos) > 5:
        shape, _, _ = stats.pareto.fit(lt_pos, floc=0)
        gamma_lt = float(shape)

    # Plots
    fig, axes = plt.subplots(2, 2, figsize=(14, 10))

    axes[0, 0].hist(lt, bins=60, color='#1DA1F2', edgecolor='black', alpha=0.8, log=True)
    axes[0, 0].set_xlabel("Lifetime (repost span)")
    axes[0, 0].set_ylabel("Count (log)")
    axes[0, 0].set_title("Post Lifetime (repost span)")

    axes[0, 1].hist(lt_total, bins=60, color='#FF7F50', edgecolor='black', alpha=0.8, log=True)
    axes[0, 1].set_xlabel("Lifetime (creation → last repost)")
    axes[0, 1].set_ylabel("Count (log)")
    axes[0, 1].set_title("Post Lifetime (creation → last)")

    for i, data in enumerate([lt, lt_total]):
        sd = np.sort(data)
        ccdf = 1.0 - np.arange(1, len(sd) + 1) / len(sd)
        ax = axes[1, i]
        ax.loglog(sd, ccdf, 'o', markersize=3, alpha=0.7,
                  color=['#1DA1F2', '#FF7F50'][i])
        ax.set_xlabel(["Lifetime (repost span)", "Lifetime (creation → last)"][i])
        ax.set_ylabel("P(X ≥ x)")
        ax.set_title(["CCDF (repost span)", "CCDF (creation → last)"][i])
        ax.grid(True, alpha=0.3)

    plt.tight_layout()
    path = output_dir / f"{prefix}post_lifetimes.png"
    fig.savefig(path, dpi=150)
    plt.close(fig)
    print(f"[post_lifetimes]  →  {path}")

    results = {
        "never_reposted": never_reposted,
        "pct_never_reposted": round(pct_never, 2),
        "lifetime_repost_median": float(np.median(lt)),
        "lifetime_repost_mean": float(lt.mean()),
        "lifetime_repost_p90": float(np.percentile(lt, 90)),
        "lifetime_repost_max": float(lt.max()),
        "lifetime_total_median": float(np.median(lt_total)),
        "lifetime_total_mean": float(lt_total.mean()),
        "lifetime_total_p90": float(np.percentile(lt_total, 90)),
    }
    if gamma_lt is not None:
        results["lifetime_powerlaw_gamma"] = round(gamma_lt, 4)

    return results


if __name__ == "__main__":
    import sys
    if len(sys.argv) < 3:
        print("Usage: python post_lifetimes.py <action_trace.jsonl> <create_trace.jsonl>")
        sys.exit(1)
    compute(pl.read_ndjson(sys.argv[1]), pl.read_ndjson(sys.argv[2]))
