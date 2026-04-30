import os
import json
import pytest
import tempfile
from compiler import run_compiler

def test_compiler():
    # Setup temporary directories
    with tempfile.TemporaryDirectory() as tmpdir:
        network_path = os.path.join(tmpdir, 'sn_data.json')
        traces_dir = os.path.join(tmpdir, 'traces')
        output_dir = os.path.join(tmpdir, 'output')
        os.makedirs(traces_dir)
        
        # 1. Create dummy sn_data.json
        sn_data = {
            "users": [{"id": 0}, {"id": 1}, {"id": 2}],
            "followers": [
                {"follower_id": 1, "followed_id": 0},
                {"follower_id": 2, "followed_id": 1}
            ]
        }
        with open(network_path, 'w') as f:
            json.dump(sn_data, f)
            
        # 2. Create dummy traces
        create_trace = [
            {"time": 1.0, "post_id": 100, "user_id": 0, "event_id": 1, "gen_id": 1}
        ]
        with open(os.path.join(traces_dir, 'create_trace.jsonl'), 'w') as f:
            for c in create_trace:
                f.write(json.dumps(c) + '\n')
                
        action_trace = [
            {"time": 2.0, "type": "repost", "user_id": 1, "post_id": 100, "event_id": 2, "gen_id": 2},
            {"time": 2.5, "type": "ignore", "user_id": 2, "post_id": 100, "event_id": 3, "gen_id": 3}
        ]
        with open(os.path.join(traces_dir, 'action_trace.jsonl'), 'w') as f:
            for a in action_trace:
                f.write(json.dumps(a) + '\n')
                
        session_trace = [
            {"time": 0.5, "type": "start", "user_id": 0, "event_id": 0, "gen_id": 0},
            {"time": 3.0, "type": "end", "user_id": 0, "event_id": 4, "gen_id": 4}
        ]
        with open(os.path.join(traces_dir, 'session_trace.jsonl'), 'w') as f:
            for s in session_trace:
                f.write(json.dumps(s) + '\n')
                
        # Run compiler
        run_compiler(network_path, traces_dir, output_dir)
        
        # Verify outputs
        assert os.path.exists(os.path.join(output_dir, 'graph.json'))
        assert os.path.exists(os.path.join(output_dir, 'events.json'))
        
        with open(os.path.join(output_dir, 'graph.json'), 'r') as f:
            graph_data = json.load(f)
            
        assert "nodes" in graph_data
        assert "edges" in graph_data
        assert len(graph_data["nodes"]) == 3
        assert len(graph_data["edges"]) == 2
        
        with open(os.path.join(output_dir, 'events.json'), 'r') as f:
            events_data = json.load(f)
            
        # We expect 4 events: start(0.5), create(1.0), repost(2.0), end(3.0)
        # ignore(2.5) is filtered out
        assert len(events_data) == 4
        assert events_data[0]["type"] == "start"
        assert events_data[1]["type"] == "create"
        assert events_data[2]["type"] == "repost"
        assert events_data[3]["type"] == "end"
        
        # Check colors match between create and repost
        assert events_data[1]["color"] == events_data[2]["color"]
