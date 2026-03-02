const std = @import("std");

const Allocator = std.mem.Allocator;
const Io = std.Io;
const json = std.json;

const Heap = @import("heap").Heap;
const dist = @import("distributions");

const DiscDist = dist.DiscreteDistribution;

const Categorical = dist.Categorical;

const structs = @import("config.zig");
const entities = @import("entities.zig");
const Precision = structs.Precision;

const User = entities.User;
const Post = entities.Post;
const TimelineEvent = entities.TimelineEvent;

const compareTimelineEvent = entities.compareTimelineEvent;

pub const SimData = struct {
    posts: []ParsedPost,
    users: []ParsedUser,
};

// this two structs are exatly what the JSON contains
const ParsedUser = struct {
    id: entities.Index,
    following: []entities.Index,
    followers: []entities.Index,
    authored_post_ids: []entities.Index,
    policy: [3]Precision,
};

const ParsedPost = struct {
    id: entities.Index,
    time: f64,
};


pub fn loadJson(gpa: Allocator, io: Io, path: []const u8, comptime T: type) !json.Parsed(T) {
    const content = try std.Io.Dir.cwd().readFileAlloc(io, path, gpa, .unlimited);
    defer gpa.free(content);
    // We use .ignore_unknown_fields = true so comments or extra metadata in JSON don't crash it
    const options = std.json.ParseOptions{ .ignore_unknown_fields = true };
    
    // parsed_result holds the data AND the arena allocator used for strings/slices in the JSON
    const parsed_result = try std.json.parseFromSlice(T, gpa, content, options);
    
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
pub fn wireSimulation(gpa: Allocator, parsed_data: SimData) !entities.Graph {
    const global_users = try gpa.alloc(User, parsed_data.users.len);
    const global_posts = try gpa.alloc(Post, parsed_data.posts.len);

    const data: [3]entities.Action = .{ .nothing, .like, .repost };
    // load users into the array
    for (parsed_data.users, 0..) |parsed_user, i| {
        const timeline: Heap(TimelineEvent, void, compareTimelineEvent) = .empty;
        const user_policy: Categorical(Precision, entities.Action) = try .init(gpa, &parsed_user.policy, &data);
        global_users[i] = User{
            .id = parsed_user.id,
            .policy = user_policy,
            // .policy = parsed_user.policy,
            .following = try gpa.alloc(entities.Index, parsed_user.following.len), // this just reserves the slice
            .followers = try gpa.alloc(entities.Index, parsed_user.followers.len),
            .posts = try gpa.alloc(entities.Index, parsed_user.authored_post_ids.len),
            .timeline = timeline,
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
            current_user.following[j] = target_id;
        }
        
        // followers
        for (parsed_user.followers, 0..) |target_id, j| {
            current_user.followers[j] = target_id;
        }
    
        // authored posts
        for (parsed_user.authored_post_ids, 0..) |post_id, j| {
            current_user.posts[j] = post_id;
        }

        // For every user we follow, grab their posts and push them to our heap.
        for (parsed_user.following) |target_id| {
            const followed_user_parsed = parsed_data.users[target_id];
            
            for (followed_user_parsed.authored_post_ids) |post_id| {
                try current_user.timeline.add(gpa, TimelineEvent{
                    .time = global_posts[post_id].time,
                    .post_id = post_id,
                });
            }
        }
    }

    // We return the slice of fully wired simulation users!
    return entities.Graph{ .users = global_users, .posts = global_posts };
}
