import json
import os
import random
import igraph as ig
from pathlib import Path

def generate_random_color():
    """Generates a random vivid HSL color string."""
    h = random.randint(0, 360)
    s = random.randint(70, 100)
    l = random.randint(40, 60)
    return f"hsl({h}, {s}%, {l}%)"

def load_graph(sn_data_path):
    print(f"Loading graph from {sn_data_path}...")
    with open(sn_data_path, 'r') as f:
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
    return G

def calculate_layout(G):
    print(f"Calculating network layout for {G.vcount()} nodes (using fast DrL algorithm)...")
    # DrL (Distributed Recursive Layout) is specifically designed to be extremely fast for large scale graphs
    pos = G.layout_drl()
    
    nodes_data = {}
    for i, p in enumerate(pos):
        nodes_data[G.vs[i]['id']] = {"x": float(p[0]), "y": float(p[1])}
        
    edges_data = [{"source": G.vs[e.source]['id'], "target": G.vs[e.target]['id']} for e in G.es]
    
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
    parser.add_argument("--network", required=True, help="Path to sn_data.json")
    parser.add_argument("--traces", required=True, help="Directory containing trace JSONL files")
    parser.add_argument("--output", required=True, help="Output directory for compiled JSONs")
    
    args = parser.parse_args()
    run_compiler(args.network, args.traces, args.output)
