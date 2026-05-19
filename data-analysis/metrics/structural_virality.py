"""Structural Virality — cascade tree virality scores (Goel et al. 2016).

Uses the Wiener index: average distance between all pairs of nodes in the
cascade tree, computed in O(N) via subtree moments.

Usage as module:
    from metrics.structural_virality import compute
    results = compute(create_path, action_path, graph_path, output_dir="img")
"""

import json
from collections import defaultdict
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np


class _CascadeNode:
    __slots__ = ['user_id', 'time', 'children']

    def __init__(self, user_id, time):
        self.user_id = user_id
        self.time = time
        self.children = []


def _subtree_moments(node):
    if not node.children:
        return 1, 1, 1
    size, sum_sizes, sum_sizes_sqr = 1, 0, 0
    for child in node.children:
        cs, css, cssq = _subtree_moments(child)
        size += cs
        sum_sizes += css
        sum_sizes_sqr += cssq
    sum_sizes += size
    sum_sizes_sqr += (size ** 2)
    return size, sum_sizes, sum_sizes_sqr


def _virality(n, sum_sizes, sum_sizes_sqr):
    if n <= 1:
        return 0.0
    return (2 * n / (n - 1)) * (sum_sizes / n - sum_sizes_sqr / (n ** 2))


def _build_trees(create_trace_path, action_trace_path, graph_path):
    """Build cascade trees from traces + graph."""
    following = defaultdict(set)
    with open(graph_path, 'r') as f:
        for edge in json.load(f).get('followers', []):
            following[edge['follower_id']].add(edge['followed_id'])

    roots = defaultdict(list)
    adopted = defaultdict(dict)

    # Create events → root nodes
    with open(create_trace_path, 'r') as f:
        for line in f:
            if not line.strip():
                continue
            ev = json.loads(line)
            root = _CascadeNode(ev['user_id'], ev['time'])
            roots[ev['post_id']].append(root)
            adopted[ev['post_id']][ev['user_id']] = root

    # Repost events → attach to most recent followed adopter
    reposts = []
    with open(action_trace_path, 'r') as f:
        for line in f:
            if not line.strip():
                continue
            ev = json.loads(line)
            if ev['type'] == 'repost':
                reposts.append(ev)
    reposts.sort(key=lambda e: e['time'])

    for ev in reposts:
        uid, pid, t = ev['user_id'], ev['post_id'], ev['time']
        node = _CascadeNode(uid, t)
        best_parent, best_time = None, -1
        for friend in following.get(uid, set()):
            fn = adopted[pid].get(friend)
            if fn and fn.time > best_time and fn.time < t:
                best_time = fn.time
                best_parent = fn
        if best_parent:
            best_parent.children.append(node)
        else:
            roots[pid].append(node)
        adopted[pid][uid] = node

    return roots


def _score_trees(roots):
    """Compute virality scores for all trees."""
    results = []
    for pid, root_list in roots.items():
        for root in root_list:
            n, ss, ssq = _subtree_moments(root)
            results.append({
                'post_id': pid,
                'cascade_size': n,
                'structural_virality': round(_virality(n, ss, ssq), 4),
            })
    results.sort(key=lambda x: x['cascade_size'], reverse=True)
    return results


def compute(create_trace_path: str, action_trace_path: str, graph_path: str,
            output_dir: str | Path = "img", data_dir: str | Path = "data", tag: str = ""):
    """Compute structural virality, dump JSON, and produce ranking plots."""
    output_dir = Path(output_dir)
    data_dir = Path(data_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    data_dir.mkdir(parents=True, exist_ok=True)
    prefix = f"{tag}_" if tag else ""

    print("[structural_virality] Building cascade trees ...")
    roots = _build_trees(create_trace_path, action_trace_path, graph_path)
    results = _score_trees(roots)

    if not results:
        print("[structural_virality] No cascades found.")
        return results

    sizes = [r['cascade_size'] for r in results]
    v_vals = [r['structural_virality'] for r in results]

    print(f"[structural_virality] {len(results)} cascades  "
          f"size: [{min(sizes)}, {max(sizes)}]  μ={sum(sizes)/len(sizes):.1f}  "
          f"ν: [{min(v_vals):.3f}, {max(v_vals):.3f}]  μ={sum(v_vals)/len(v_vals):.3f}")

    # JSON
    json_path = data_dir / f"{prefix}cascade_analytics.json"
    with open(json_path, 'w') as f:
        json.dump(results, f, indent=2)
    print(f"[structural_virality] JSON  →  {json_path}")

    # Virality ranking plot
    sorted_by_v = sorted(results, key=lambda r: r['structural_virality'], reverse=True)

    fig, (ax0, ax1) = plt.subplots(2, 1, figsize=(14, 10))

    n_show = min(50, len(sorted_by_v))
    labels = [f"P{r['post_id']}" for r in sorted_by_v[:n_show]]
    v_top = [r['structural_virality'] for r in sorted_by_v[:n_show]]
    colors = plt.cm.viridis(np.linspace(0.2, 0.9, n_show))
    ax0.bar(labels, v_top, color=colors, edgecolor='black', alpha=0.85)
    ax0.set_xlabel("Post ID")
    ax0.set_ylabel("Structural Virality ν(T)")
    ax0.set_title(f"Top {n_show} Posts by Structural Virality")
    ax0.tick_params(axis='x', rotation=90, labelsize=7)

    ax1.scatter(sizes, v_vals, alpha=0.6, c='#1DA1F2',
                edgecolors='black', linewidth=0.3)
    ax1.set_xlabel("Cascade Size (n)")
    ax1.set_ylabel("Structural Virality ν(T)")
    ax1.set_title("Cascade Size vs Structural Virality")
    ax1.grid(True, alpha=0.3)

    plt.tight_layout()
    plot_path = output_dir / f"{prefix}structural_virality.png"
    fig.savefig(plot_path, dpi=150)
    plt.close(fig)
    print(f"[structural_virality] Plot  →  {plot_path}")

    return results


if __name__ == "__main__":
    import sys
    if len(sys.argv) < 4:
        print("Usage: python structural_virality.py <create.jsonl> <action.jsonl> <graph.json>")
        sys.exit(1)
    compute(sys.argv[1], sys.argv[2], sys.argv[3])
