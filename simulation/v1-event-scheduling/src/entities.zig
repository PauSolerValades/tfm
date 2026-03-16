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
    follower_start: Index,
    follower_count: Index, 
    policy: Categorical(Precision, Action),
    last_published_post: Index = 0,
};

// Post of the simulation
pub const Post = struct {
    id: Index,
//    time: f64,
    author: Index,
};


/// all the actions performable in the simulaiton by a user
//const Action = enum { nothing, like, repost, reply, quote };
pub const Action = enum { ignore, like, repost, start_session, end_session, create };

/// Simulation Event 
const EventChron = struct {
    time: f64,          // when will the action be due
    type: Action,       // what will the user do
    user_id: Index,     // user id
    id: u64,            // which action is it
};

const EventRevChron = struct {
    time: f64,          // when will the action be due
    type: Action,       // what will the user do
    user_id: Index,     // user id
    id: u64,            // which action is it
    session_gen: u64    // in which session from the user_id does this event belong
};

const is_v1 = std.mem.eql(u8, "v1", @import("build").build);
pub const Event = if (is_v1) EventChron else EventRevChron;

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
    user_id: Index,
    post_id: Index,
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


pub fn compareTimelineEventOposite(context: void, a: TimelineEvent, b: TimelineEvent) Order {
    _ = context;
    return std.math.order(b.time, a.time);
}

