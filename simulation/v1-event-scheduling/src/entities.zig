const std = @import("std");

const Heap = @import("heap").Heap;
const dist = @import("distributions");

const Categorical = dist.Categorical;

const config = @import("config.zig");

const Order = std.math.Order;
const ArrayList = std.ArrayList;

const Precision = config.Precision;

pub const Index: type = u32;
/// User of the simulation
pub const User = struct {
    id: Index,
    following: []Index,
    followers: []Index,
    timeline: Heap(TimelineEvent, void, compareTimelineEvent),
    posts: []Index,
    historic: ArrayList(*Post) = .empty,
    seen_posts_ids: ArrayList(Index) = .empty,
    policy: Categorical(Precision, Action),
};

// Post of the simulation
pub const Post = struct {
    id: Index,
    time: f64,
    author: Index,
    content: []const u8 = "",
};


/// all the actions performable in the simulaiton by a user
//const Action = enum { nothing, like, repost, reply, quote };
pub const Action = enum { nothing, like, repost };

/// Simulation Event 
pub const Event = struct {
    time: f64,          // when will the action be due
    type: Action,       // what will the user do
    user_id: Index,    // user id
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
    time: f64,
    post_id: Index,
};


pub fn compareTimelineEvent(context: void, a: TimelineEvent, b: TimelineEvent) Order {
    _ = context;
    return std.math.order(a.time, b.time);
}

pub const Graph = struct {
    users: []User,
    posts: []Post,
};

