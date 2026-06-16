import json
import os
import random
import struct
import igraph as ig
from pathlib import Path

def generate_random_color():
    """Generates a random vivid HSL color string."""
    h = random.randint(0, 360)
    s = random.randint(70, 100)
    l = random.randint(40, 60)
    return f"hsl({h}, {s}%, {l}%)"

def load_graph(sn_data_path):
    """Load a social network graph from a JSON or binary (.bin) file.
    
    JSON format: {"users": [{"id": ...}, ...], "followers": [{"follower_id": ..., "followed_id": ...}, ...]}
    Binary format: u32 num_users, u32 user_ids[num_users], u32 num_edges, u32 edges[num_edges*2]
    """
    path = Path(sn_data_path)
    
    if path.suffix == '.bin':
        return _load_graph_from_bin(path)
    else:
        return _load_graph_from_json(path)

def _load_graph_from_json(path):
    print(f"Loading graph from {path}...")
    with open(path, 'r') as f:
        data = json.load(f)
    
    G = ig.Graph(directed=True)
    users = data.get('users', [])
    G.add_vertices(len(users))
    
    # igraph vertices are 0-indexed, we need a mapping if user ids aren't perfectly contiguous 0..N
    id_to_idx = {}
    for i, user in enumerate(users):
        user_id = user['id']
        id_to_idx[user_id] = i
        G.vs[i]['id'] = user_id
        
    edges = []
    for edge in data.get('followers', []):
        edges.append((id_to_idx[edge['follower_id']], id_to_idx[edge['followed_id']]))
        
    G.add_edges(edges)
    print(f"  Loaded {G.vcount()} nodes, {G.ecount()} edges")
    return G

def _load_graph_from_bin(path):
    """Load from monotonous binary format (sequential 0-indexed user IDs)."""
    print(f"Loading graph from {path} (binary)...")
    with open(path, 'rb') as f:
        num_users = struct.unpack('<I', f.read(4))[0]
        # Skip user_ids (they are sequential 0..N-1 in monotonous format)
        f.seek(4 + 4 * num_users)
        num_edges = struct.unpack('<I', f.read(4))[0]
        raw = f.read()
    
    # Unpack edges efficiently using array module
    import array
    edges = array.array('I')
    edges.frombytes(raw)
    
    G = ig.Graph(directed=True)
    G.add_vertices(num_users)
    for i in range(num_users):
        G.vs[i]['id'] = i
    
    # Add edges in chunks to avoid memory spikes
    CHUNK = 500000
    for start in range(0, len(edges), CHUNK * 2):
        end = min(start + CHUNK * 2, len(edges))
        G.add_edges([(edges[i], edges[i+1]) for i in range(start, end, 2)])
    
    print(f"  Loaded {G.vcount()} nodes, {G.ecount()} edges")
    return G

def calculate_layout(G):
    print(f"Calculating network layout for {G.vcount()} nodes, {G.ecount()} edges...")
    # GraphOpt is a fast force-directed layout suitable for large graphs (10K+ nodes, 1M+ edges).
    # niter=50 gives good results in ~30-60s for a 10K/3M graph.
    pos = G.layout_graphopt(niter=50, node_charge=0.01, spring_length=50)
    
    nodes_data = {}
    for i, p in enumerate(pos):
        nodes_data[G.vs[i]['id']] = {"x": float(p[0]), "y": float(p[1])}
    
    edges_data = [{"source": int(G.vs[e.source]['id']), "target": int(G.vs[e.target]['id'])} for e in G.es]
    
    return {"nodes": nodes_data, "edges": edges_data}

def compile_traces(traces_dir, output_dir):
    traces_dir = Path(traces_dir)
    events = []
    post_colors = {}
    
    print("Parsing create_trace.jsonl...")
    create_trace_path = traces_dir / 'create_trace.jsonl'
    if create_trace_path.exists():
        with open(create_trace_path, 'r') as f:
            for line in f:
                if not line.strip(): continue
                record = json.loads(line)
                post_id = record['post_id']
                if post_id not in post_colors:
                    post_colors[post_id] = generate_random_color()
                
                events.append({
                    "time": record['time'],
                    "type": "create",
                    "user_id": record['user_id'],
                    "post_id": post_id,
                    "color": post_colors[post_id]
                })

    print("Parsing action_trace.jsonl...")
    action_trace_path = traces_dir / 'action_trace.jsonl'
    if action_trace_path.exists():
        with open(action_trace_path, 'r') as f:
            for line in f:
                if not line.strip(): continue
                record = json.loads(line)
                # We only care about reposts for the visualization cascade
                if record.get('type') == 'repost':
                    post_id = record['post_id']
                    if post_id not in post_colors:
                        post_colors[post_id] = generate_random_color()
                        
                    events.append({
                        "time": record['time'],
                        "type": "repost",
                        "user_id": record['user_id'],
                        "post_id": post_id,
                        "color": post_colors[post_id]
                    })

    print("Parsing session_trace.jsonl...")
    session_trace_path = traces_dir / 'session_trace.jsonl'
    if session_trace_path.exists():
        with open(session_trace_path, 'r') as f:
            for line in f:
                if not line.strip(): continue
                record = json.loads(line)
                events.append({
                    "time": record['time'],
                    "type": record['type'], # 'start' or 'end'
                    "user_id": record['user_id']
                })
                
    print("Sorting events chronologically...")
    events.sort(key=lambda x: x['time'])
    
    return events

def run_compiler(sn_data_path, traces_dir, output_dir):
    os.makedirs(output_dir, exist_ok=True)
    
    G = load_graph(sn_data_path)
    graph_data = calculate_layout(G)
    
    graph_out = os.path.join(output_dir, 'graph.json')
    with open(graph_out, 'w') as f:
        json.dump(graph_data, f)
    print(f"Graph data saved to {graph_out}")
    
    events = compile_traces(traces_dir, output_dir)
    
    events_out = os.path.join(output_dir, 'events.json')
    with open(events_out, 'w') as f:
        json.dump(events, f)
    print(f"Events data saved to {events_out}")
    print(f"Total events compiled: {len(events)}")

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Compile simulation data for frontend.")
    parser.add_argument("--network", required=True, help="Path to sn_data.json or monotonous .bin network file")
    parser.add_argument("--traces", required=True, help="Directory containing trace JSONL files")
    parser.add_argument("--output", required=True, help="Output directory for compiled JSONs")
    
    args = parser.parse_args()
    run_compiler(args.network, args.traces, args.output)
