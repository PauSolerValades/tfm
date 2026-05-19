#!/usr/bin/env python3
"""trace-metrics.py — Orchestrator for all evaluation metrics.

Loads simulation traces, delegates to per-metric modules, outputs plots + JSON summary.

Usage:
    python trace-metrics.py --dir ../simulation/dynamic-posts/results/ --graph data/sn_topo_100_3_0.6.json
"""

import argparse
import json
import os
import sys
from pathlib import Path

import polars as pl

import metrics.reposts_powerlaw as reposts_powerlaw
import metrics.post_lifetimes as post_lifetimes
import metrics.gini as gini
import metrics.structural_virality as structural_virality


def main():
    parser = argparse.ArgumentParser(
        description="Compute all evaluation metrics from simulation traces."
    )

    parser.add_argument("graph", type=str, help="Path to follower graph JSON.")
    parser.add_argument(
        "dir",
        type=str,
        help="Directory with the four trace JSONL files.",
    )
    parser.add_argument(
        "--output-dir", type=str, default="img", help="Directory for plots."
    )
    parser.add_argument(
        "--data-dir", type=str, default="data", help="Directory for JSON output."
    )

    args = parser.parse_args()

    trace_dir = Path(args.dir)
    if not trace_dir.is_dir():
        print(f"Error: 'dir' must be a directory, got: {trace_dir}")
        sys.exit(1)

    graph_path = Path(args.graph)
    if not graph_path.is_file():
        print(f"Error: 'graph' must be a file, got: {graph_path}")
        sys.exit(1)

    create_path = trace_dir / "create_trace.jsonl"
    action_path = trace_dir / "action_trace.jsonl"
    propagate_path = trace_dir / "propagate_trace.jsonl"

    for p, name in [
        (create_path, "create"),
        (action_path, "action"),
        (propagate_path, "propagate"),
    ]:
        if not p.is_file():
            print(f"Error: {name} trace not found at {p}")
            sys.exit(1)

    # ── Tag outputs with graph name so different runs don't overwrite ──
    graph_tag = graph_path.stem  # e.g. "sn_topo_100_3_0.6"

    # ── Load traces ──
    print(f"Loading traces from {trace_dir} …")
    create_df = pl.read_ndjson(create_path)
    action_df = pl.read_ndjson(action_path)
    propagate_df = pl.read_ndjson(propagate_path)
    # propagate_trace uses 'type' as post_id
    propagate_df = propagate_df.rename({"type": "post_id"})

    print(f"  create:     {create_df.height:,} events")
    print(f"  action:     {action_df.height:,} events")
    print(f"  propagate:  {propagate_df.height:,} events")

    all_results = {}

    # ── 1. Reposts Power-law ──
    print("\n" + "─" * 60)
    print("1. REPOSTS POWER-LAW")
    rp, _ = reposts_powerlaw.compute(
        action_df, output_dir=args.output_dir, tag=graph_tag
    )
    if rp:
        all_results["reposts_powerlaw"] = rp

    # ── 2. Post Lifetimes ──
    print("\n" + "─" * 60)
    print("2. POST LIFETIMES")
    lt = post_lifetimes.compute(
        action_df, create_df, output_dir=args.output_dir, tag=graph_tag
    )
    if lt:
        all_results["lifetimes"] = lt

    # ── 3. Gini ──
    print("\n" + "─" * 60)
    print("3. GINI COEFFICIENT")
    g = gini.compute(propagate_df, action_df, output_dir=args.output_dir, tag=graph_tag)
    all_results["gini"] = g

    # ── 4. Structural Virality ──
    print("\n" + "─" * 60)
    print("4. STRUCTURAL VIRALITY")
    structural_virality.compute(
        str(create_path),
        str(action_path),
        str(graph_path),
        output_dir=args.output_dir,
        data_dir=args.data_dir,
        tag=graph_tag,
    )

    # ── Summary JSON ──
    summary_path = Path(args.data_dir) / f"metrics_summary_{graph_tag}.json"
    summary_path.parent.mkdir(parents=True, exist_ok=True)
    with open(summary_path, "w") as f:
        json.dump(all_results, f, indent=2)
    print(f"\nSummary  →  {summary_path}")
    print("Done!")


if __name__ == "__main__":
    main()
