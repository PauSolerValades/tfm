import json
from collections import defaultdict

original = "./data/sim_data_mid.json"
trace = "../v1-event-scheduling/results/trace.txt"

class Node:
    """Represents a user's adoption of a specific post."""
    def __init__(self, user_id, time):
        self.user_id = user_id
        self.time = time
        self.children = []

# --- 1. Load the Follower Graph ---
# We store 'following' as a set for O(1) membership lookups.
following_map = {}
with open(original, 'r') as f:
    graph_data = json.load(f)
    for user in graph_data['users']:
        following_map[user['id']] = set(user['following'])

# --- 2. Process the Chronological Event Trace ---
# post_trees stores the root node(s) for each post_id.
# A single post can have multiple roots if introduced independently.
post_trees = defaultdict(list)

# latest_adoption tracks the most recent Node for a given user and post.
# Format: latest_adoption[post_id][user_id] = Node
latest_adoption = defaultdict(dict)

with open(trace, 'r') as f:
    for line in f:
        event = json.loads(line)
        
        # We only care about events that spread the content to new timelines [cite: 153] (Accessed 2026-01-09).
        if event['type'] != 'repost':
            continue
            
        u_id = event['user_id']
        p_id = event['post_id']
        t = event['time']
        
        new_node = Node(u_id, t)
        
        # Find the parent: The friend who reposted most recently before this user [cite: 144] (Accessed 2026-01-09).
        friends = following_map.get(u_id, set())
        best_parent = None
        best_time = -1
        
        for friend in friends:
            if friend in latest_adoption[p_id]:
                friend_node = latest_adoption[p_id][friend]
                if friend_node.time > best_time:
                    best_time = friend_node.time
                    best_parent = friend_node
                    
        if best_parent:
            best_parent.children.append(new_node)
        else:
            # If no friend previously posted it, this is an independent introduction [cite: 143] (Accessed 2026-01-09).
            post_trees[p_id].append(new_node)
            
        # Update the latest adoption record for this user/post combo
        latest_adoption[p_id][u_id] = new_node

# --- 3. Compute Structural Virality (Linear Time Algorithm) ---
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

def calculate_structural_virality(root):
    if not root.children:
        return 0.0 
        
    n, sum_sizes, sum_sizes_sqr = compute_subtree_moments(root)
    term1 = sum_sizes / n
    term2 = sum_sizes_sqr / (n ** 2)
    return (2 * n / (n - 1)) * (term1 - term2)

analytics = []

for p_id, roots in post_trees.items():
    for root in roots:
        # We need the tree size. The moments function already computes this.
        n, _, _ = compute_subtree_moments(root)
        
        # [cite_start]Filter for large, successful cascades (e.g., n >= 100) [cite: 156] (Accessed 2026-01-09).
        if n >= 100:
            virality = calculate_structural_virality(root)
            analytics.append({
                'post_id': p_id,
                'cascade_size': n,
                'structural_virality': round(virality, 4)
            })

# Sort by size to make standard analytics easier
analytics.sort(key=lambda x: x['cascade_size'], reverse=True)

# Write the sorted analytics list to a JSON file
output_filename = 'data/cascade_analytics.json'
with open(output_filename, 'w') as f:
    json.dump(analytics, f, indent=4)
