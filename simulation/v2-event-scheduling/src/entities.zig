const std = @import("std");
const Heap = @import("heap").Heap;
const Order = std.math.Order;
const ArrayList = std.ArrayList;
const config = @import("config.zig");

const Distribution = config.Distribution;
const Precision = config.Precision;

/// User of the simulation
pub const User = struct {
    id: u64,
    following: []*User,
    followers: []*User,
    timeline: Heap(TimelineEvent, void, compareTimelineEvent),
    posts: []*Post,
    historic: ArrayList(*Post) = .empty,
    policy: Distribution(Precision),
};

// Post of the simulation
pub const Post = struct {
    id: u64,
    time: f64,
    author: u64,
    content: []const u8 = "",
};


/// all the actions performable in the simulaiton by a user
//const Action = enum { nothing, like, repost, reply, quote };
pub const Action = enum { nothing, like, repost, go_online, go_offline};

/// Simulation Event 
pub const Event = struct {
    time: f64,          // when will the action be due
    type: Action,       // what will the user do
    user_ptr: *User,    // user id
    id: u64,            // which action is it
};

pub fn compareEvent(context: void, a: Event, b: Event) Order {
    _ = context;
    return std.math.order(a.time, b.time);
}

/// Auxiliar struct for trace writing. Contains all 
/// the entities that need to be written on the trace
pub const TracePost = struct {
    time: f64,
    type: Action,
    event_id: u64,
    user_id: u64,
    post_id: u64,
};

/// Auxiliar object to contain into the timeline Heap
/// for easy access to the data.
pub const TimelineEvent = struct {
    heap_index: usize = 0,
    time: f64,
    post: *Post,
};


/// This is for th timelines, it will output from bigger to smaller
pub fn compareTimelineEvent(context: void, a: TimelineEvent, b: TimelineEvent) Order {
    _ = context;
    return std.math.order(b.time, a.time);
}


