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


"""
{
  "posts": [
    { "id": "0_0", "time": 6.56 },
    { "id": "0_1", "time": 12.86 }
  ],
  "users": [
    {
      "id": 0,
      "policy": [0.2, 0.2, 0.2, 0.2, 0.2],
      "following": [84, 65, 80],
      "followers": [1, 7, 9],
      "authored_post_ids": ["0_0", "0_1"]
    },
    {
      "id": 1,
      "policy": [0.1, 0.9, 0.0, 0.0, 0.0],
      "following": [0],
      "followers": [],
      "authored_post_ids": []
    }
  ]
}
"""

def generate_simulation_data(filename="sim_data.json"):
    # The two normalized "tables"
    global_posts = []
    global_users = []
    
    # Global counter for post IDs
    post_id_counter = 0

    # 1. Initialize Users
    for user_id in range(NUM_USERS):
        global_users.append({
            "id": user_id,
            "policy": [0.2, 0.2, 0.2, 0.2, 0.2],
            "following": [],
            "followers": [], 
            "authored_post_ids": [] # Will store integers now
        })

    # 2. Generate Graph (Random k-Out Strategy)
    all_user_ids = list(range(NUM_USERS))
    
    for user in global_users:
        # User cannot follow themselves
        candidates = [uid for uid in all_user_ids if uid != user["id"]]
        
        # Pick random number of followees
        # Use gauss to get a bell curve around AVG_FOLLOWING, clamped to valid range
        num_following = int(random.gauss(AVG_FOLLOWING, 2))
        num_following = max(1, min(num_following, len(candidates)))
        
        # Randomly select who they follow
        targets = random.sample(candidates, num_following)
        user["following"] = targets

    # 3. Populate 'Followers' (The Reverse Graph)
    for user in global_users:
        for target_id in user["following"]:
            global_users[target_id]["followers"].append(user["id"])

    # 4. Generate Posts
    for user in global_users:
        num_posts = random.randint(MIN_POSTS, MAX_POSTS)
        
        # Generate random timestamps
        timestamps = [random.uniform(0, SIMULATION_DURATION) for _ in range(num_posts)]
        timestamps.sort()  # CRITICAL: Must be chronological
        
        for t in timestamps:
            current_post_id = post_id_counter
            post_id_counter += 1
            
            # 1. Add the post object to the global list
            global_posts.append({
                "id": current_post_id, 
                "time": round(t, 2),          
            })
            
            # 2. Add the integer ID reference to the user
            user["authored_post_ids"].append(current_post_id)

    # 5. Construct the final normalized JSON wrapper
    output_data = {
        "posts": global_posts,
        "users": global_users
    }

    # 6. Save to File
    with open(filename, "w") as f:
        json.dump(output_data, f, indent=2)
    
    print(f"Generated {NUM_USERS} users and {len(global_posts)} total posts in '{filename}'")

if __name__ == "__main__":
    generate_simulation_data()
