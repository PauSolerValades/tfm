"""
This file has been made by Gemini 3 Pro
"""

import json
import random

# --- CONFIGURATION ---
NUM_USERS = 100
MIN_POSTS = 10
MAX_POSTS = 50
SIMULATION_DURATION = 1000  # Time units (e.g., minutes)
AVG_FOLLOWING = 10  # On average, a user follows 10 people

def generate_simulation_data(filename="sim_data.json"):
    data = []
    
    # 1. Initialize Users
    # We use integers 0..N-1 as IDs for array-index speed
    for user_id in range(NUM_USERS):
        data.append({
            "id": user_id,
            "following": [],
            "followers": [], # We will fill this by reversing 'following'
            "posts": []
        })

    # 2. Generate Graph (Random k-Out Strategy)
    # Every user follows roughly 'AVG_FOLLOWING' random people
    all_user_ids = list(range(NUM_USERS))
    
    for user in data:
        # User cannot follow themselves
        candidates = [uid for uid in all_user_ids if uid != user["id"]]
        
        # Pick random number of followees (e.g., 5 to 15)
        num_following = max(1, int(random.gauss(AVG_FOLLOWING, 2)))
        num_following = min(num_following, len(candidates))
        
        # Randomly select who they follow
        targets = random.sample(candidates, num_following)
        user["following"] = targets

    # 3. Populate 'Followers' (The Reverse Graph)
    # This is critical for the "Repost Propagation" logic
    for user in data:
        for target_id in user["following"]:
            data[target_id]["followers"].append(user["id"])

    # 4. Generate Posts
    # Posts must be time-sorted for the MinHeap to work
    for user in data:
        num_posts = random.randint(MIN_POSTS, MAX_POSTS)
        
        # Generate random timestamps
        timestamps = [random.uniform(0, SIMULATION_DURATION) for _ in range(num_posts)]
        timestamps.sort()  # CRITICAL: Must be chronological
        
        for i, t in enumerate(timestamps):
            post_obj = {
                "id": f"{user['id']}_{i}", # Unique ID: UserID_Index
                "time": round(t, 2),          # Round for cleaner JSON
            }
            user["posts"].append(post_obj)

    # 5. Save to File
    with open(filename, "w") as f:
        json.dump(data, f, indent=2)
    
    print(f"Generated {NUM_USERS} users with graph and posts in '{filename}'")

if __name__ == "__main__":
    generate_simulation_data()

