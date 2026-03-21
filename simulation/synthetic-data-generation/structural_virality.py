import os
import json
import argparse
from collections import defaultdict

class Node:
    """Represents a user's adoption of a specific post."""
    # Optimization: __slots__ significantly reduces memory overhead for millions of nodes
    __slots__ = ['user_id', 'time', 'children'] 
    
    def __init__(self, user_id, time):
        self.user_id = user_id
        self.time = time
        self.children = []

def compute_subtree_moments(node):
    """Recursively calculates subtree sizes to compute the Wiener index in O(N)."""
    if not node.children:
        return 1, 1, 1  # size, sum_sizes, sum_sizes_sqr
    
    size, sum_sizes, sum_sizes_sqr = 1, 0, 0
    
    for child in node.children:
        c_size, c_sum_sizes, c_sum_sizes_sqr = compute_subtree_moments(child)
        size += c_size
        sum_sizes += c_sum_sizes
        sum_sizes_sqr += c_sum_sizes_sqr
        
    sum_sizes += size
    sum_sizes_sqr += (size ** 2)
    return size, sum_sizes, sum_sizes_sqr

def calculate_virality_math(n, sum_sizes, sum_sizes_sqr):
    """Calculates final virality score using pre-computed moments to avoid double-recursion."""
    if n <= 1:
        return 0.0 
        
    term1 = sum_sizes / n
    term2 = sum_sizes_sqr / (n ** 2)
    return (2 * n / (n - 1)) * (term1 - term2)

def main(original_graph, trace_file, output_filename):
    # --- 1. Load the Follower Graph (ADAPTED FOR EDGE LIST) ---
    print("Loading follower graph...")
    following_map = defaultdict(set)
    with open(original_graph, 'r') as f:
        graph_data = json.load(f)
        # Parse the 'followers' edge list instead of the 'users' array
        for edge in graph_data.get('followers', []):
            follower = edge['follower_id']
            followed = edge['followed_id']
            following_map[follower].add(followed)

    # --- 2. Process the Chronological Event Trace ---
    print("Processing event trace...")
    post_trees = defaultdict(list)
    latest_adoption = defaultdict(dict)

    with open(trace_file, 'r') as f:
        for line in f:
            event = json.loads(line)
            
            # We only care about events that spread the content to new timelines (Accessed 2026-03-20).
            # Inside the event trace loop:
            if event['type'] == 'create': # (Replace 'create' with your actual event string)
                u_id = event['user_id']
                p_id = event['post_id']
                t = event['time']
                
                new_node = Node(u_id, t)
                
                # This is the true root of the cascade
                post_trees[p_id].append(new_node)
                latest_adoption[p_id][u_id] = new_node

            elif event['type'] == 'repost':
                u_id = event['user_id']
                p_id = event['post_id']
                t = event['time']
                
                new_node = Node(u_id, t)
    
            u_id = event['user_id']
            p_id = event['post_id']
            t = event['time']
            
            new_node = Node(u_id, t)
            
            # Find the parent: The friend who reposted most recently before this user (Accessed 2026-03-20).
            friends = following_map.get(u_id, set())
            best_parent = None
            best_time = -1
            
            # Optimization: Localize the post adoption dictionary to avoid repeated lookups
            post_adoptions = latest_adoption[p_id] 
            
            for friend in friends:
                if friend in post_adoptions:
                    friend_node = post_adoptions[friend]
                    if friend_node.time > best_time:
                        best_time = friend_node.time
                        best_parent = friend_node
                        
            if best_parent:
                best_parent.children.append(new_node)
            else:
                # If no friend previously posted it, this is an independent introduction (Accessed 2026-03-20).
                post_trees[p_id].append(new_node)
                
            # Update the latest adoption record for this user/post combo
            post_adoptions[u_id] = new_node

    # --- 3. Compute Structural Virality ---
    print("Computing structural virality...")
    analytics = []

    for p_id, roots in post_trees.items():
        for root in roots:
            # Calculate moments ONCE per root
            n, sum_sizes, sum_sizes_sqr = compute_subtree_moments(root)
            
            # Filter for large, successful cascades (e.g., n >= 100) (Accessed 2026-03-20).
            # Use the pre-computed moments to get the final score
            virality = calculate_virality_math(n, sum_sizes, sum_sizes_sqr)
            analytics.append({
                'post_id': p_id,
                'cascade_size': n,
                'structural_virality': round(virality, 4)
            })

    # Sort by size to make standard analytics easier
    analytics.sort(key=lambda x: x['cascade_size'], reverse=True)

    # Write the sorted analytics list to a JSON file
    print(f"Saving results to {output_filename}...")
    with open(output_filename, 'w') as f:
        json.dump(analytics, f, indent=4)
        
    print("Done!")

if __name__ == '__main__':
    
    parser = argparse.ArgumentParser(description="Calculate Structural Virality of Cascades.")
    parser.add_argument('trace', type=str, help="Path to the event trace JSONL file.")
    parser.add_argument('graph', type=str, help="Path to the original follower graph JSON file.")
    parser.add_argument('--output', type=str, default='data/cascade_analytics.json', help="Path for the output JSON file.")
    
    args = parser.parse_args()
    
    if (not os.path.exists(args.trace) or not os.path.exists(args.graph)):
        print("The file provided does not exist")
        sys.exit(0)


    main(args.graph, args.trace, args.output)
