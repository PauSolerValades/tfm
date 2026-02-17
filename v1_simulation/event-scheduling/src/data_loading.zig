const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const json = std.json;

const simulation = @import("simulation.zig");
const structs = @import("config.zig");
const heap = @import("structheap.zig");


const Distribution = structs.Distribution;
const Precision = structs.Precision;

const User = simulation.User;
const Post = simulation.Post;
const TimelineEvent = simulation.TimelineEvent;

pub const SimData = struct {
    posts: []ParsedPost,
    users: []ParsedUser,
};

// this two structs are exatly what the JSON contains
const ParsedUser = struct {
    id: u64,
    following: []u64,
    followers: []u64,
    authored_post_ids: []u64,
    policy: [5]Precision,
};

const ParsedPost = struct {
    id: u64,
    time: f64,
};



pub fn loadJson(allocator: Allocator, io: Io, path: []const u8, comptime T: type) !json.Parsed(T) {
    const content = try std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .unlimited);

    // We use .ignore_unknown_fields = true so comments or extra metadata in JSON don't crash it
    const options = std.json.ParseOptions{ .ignore_unknown_fields = true };
    
    // parsed_result holds the data AND the arena allocator used for strings/slices in the JSON
    const parsed_result = try std.json.parseFromSlice(T, allocator, content, options);
    
    return parsed_result;
}


/// first version of this has the following json:
/// ```
/// {
///     "posts": [1,2,3,...],
///     "users": [
///         {
///             "id": 0,
///             "policy": [0.2, 0.2, 0.2, 0.2, 0.2],
///             "following": [1,2,3],
///             "followers": [1,7,9],
///             "authored_post_ids": [1,2]
///         } 
///         ...
///     ]
/// }
/// ```
///
/// The following funciton parses this into an slice of users to be used by the simulation
pub fn wireSimulation(allocator: Allocator, parsed_data: SimData) !struct{ users: []User, posts: []Post }{
    const global_users = try allocator.alloc(User, parsed_data.users.len);
    const global_posts = try allocator.alloc(Post, parsed_data.posts.len);

    // load users into the array
    for (parsed_data.users, 0..) |parsed_user, i| {
        global_users[i] = User{
            .id = parsed_user.id,
            .policy = Distribution(Precision){ .weighted = &parsed_user.policy },
            // .policy = parsed_user.policy,
            .following = try allocator.alloc(*User, parsed_user.following.len), // this just reserves the slice
            .followers = try allocator.alloc(*User, parsed_user.followers.len),
            .posts = try allocator.alloc(*Post, parsed_user.authored_post_ids.len),
            .timeline = heap.Heap(TimelineEvent).init(),  // init empty heap
        };
    }
    
    // this is slow as heck but its needed to have the author on the post
    for (parsed_data.posts, 0..) |parsed_post, i| {
        for (parsed_data.users) |parsed_user| {
            for (parsed_user.authored_post_ids) |pid| {
                if (pid == parsed_post.id) {
                    global_posts[i] = Post{
                        .id = parsed_post.id,
                        .time = parsed_post.time,
                        .author = pid,
                    };
                     
                    break;
                }
            }
        }
    }
    
    // append the pointers of followers and following into here 
    for (parsed_data.users, 0..) |parsed_user, i| {
        const current_user = &global_users[i];

        // following
        for (parsed_user.following, 0..) |target_id, j| {
            current_user.following[j] = &global_users[target_id];
        }
        
        // followers
        for (parsed_user.followers, 0..) |target_id, j| {
            current_user.followers[j] = &global_users[target_id];
        }
    
        // authored posts
        for (parsed_user.authored_post_ids, 0..) |post_id, j| {
            current_user.posts[j] = &global_posts[post_id];
        }

        // For every user we follow, grab their posts and push them to our heap.
        for (parsed_user.following) |target_id| {
            const followed_user_parsed = parsed_data.users[target_id];
            
            for (followed_user_parsed.authored_post_ids) |post_id| {
                const post_ptr = &global_posts[post_id];
                
                try current_user.timeline.push(allocator, TimelineEvent{
                    .time = post_ptr.time,
                    .post = post_ptr,
                });
            }
        }
    }

    // We return the slice of fully wired simulation users!
    return .{ .users = global_users, .posts = global_posts };
}
