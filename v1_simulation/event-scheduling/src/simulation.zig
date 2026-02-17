const std = @import("std");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Random = std.Random;
const Io = std.Io;

const heap = @import("structheap.zig");
const structs = @import("config.zig");

const Distribution = structs.Distribution;
const SimResults = structs.SimResults;
const SimConfig = structs.SimConfig;

const Action = enum { nothing, like, reply, repost, quote };

pub const Event = struct {
    time: f64,          // when will the action be due
    type: Action,       // what will the user do
    user_ptr: *User,    // user id
    id: u64,            // which action is it
};

pub const TracePost = struct {
    time: f64,
    type: Action,
    event_id: u64,
    user_id: u64,
    post_id: u64,
};

pub const TimelineEvent = struct {
    time: f64,
    post: *Post,
};


pub const User = struct {
    id: u64,
    following: []*User,
    followers: []*User,
    timeline: heap.Heap(TimelineEvent),
    posts: []*Post,
    historic: ArrayList(*Post) = .empty,
    policy: Distribution,
};


pub const Post = struct {
    id: u64,
    time: f64,
    author: u64,
    content: []const u8 = "",
};

fn CreateRandomEvent(user: *User, event_id: u64, t_clock: f64, config: SimConfig, rng: Random) !Event {
    const float_index: f64 = try config.user_policy.sample(rng);
    const index: usize = @as(usize, @intFromFloat(float_index));
    const action: Action = @enumFromInt(index);
    const event_time = try config.user_inter_action.sample(rng);
    const event = Event{ .time = t_clock + event_time, .type = action, .user_ptr = user, .id = event_id };
    
    return event;
}

pub fn v1(gpa: Allocator, rng: Random, config: SimConfig, users: []User, trace: ?*Io.Writer) !SimResults {
     
    var hp = heap.Heap(Event).init();
    defer hp.deinit(gpa);

    var processed_events: u64 = 0;
    var t_clock: f64 = 0.0;
    
    var impressions: u64 = 0;
    var interactions: u64 = 0;
    var ignored: u64 = 0;

    // add a first event per every user
    for (users) |*user| {
        const event = try CreateRandomEvent(user, processed_events, 0, config, rng);
        try hp.push(gpa, event);
        processed_events += 1;
    }

    if (trace) |writer| {
        try writer.writeAll("[\n");
    }
    
    while (t_clock <= config.horizon and hp.len() > 0) : (processed_events += 1) {
        const current_event = hp.pop().?; // we use ? because we are absolutely sure there will be an element
        t_clock = current_event.time;
        
        const current_user_ptr = current_event.user_ptr;
       
        // generate another event
        const event = try CreateRandomEvent(current_user_ptr, processed_events, t_clock, config, rng);

        try hp.push(gpa, event);
        
        // pop seen post from the user associated with the event
        const poped_post: ?TimelineEvent = current_user_ptr.*.timeline.pop();
        // if a user has no remaing posts in the timeline (eg simulation is very long it could run out of posts)
        // we CANT stop generating actions, due to potential reply, repor or quotes that could fill the timeline again
        if (poped_post) |current_post| {
            // add the post reference to the historic of the current user
            try current_user_ptr.*.historic.append(gpa, current_post.post);
            impressions += 1;
            
            if (trace) |writer| {
                const trace_event = TracePost{
                    .time = t_clock,
                    .type = current_event.type,
                    .event_id = processed_events,
                    .user_id = current_user_ptr.id,
                    .post_id = current_post.post.*.id,
                };
                // this might be very slow, it could be better to use the lower json api
                try std.json.Stringify.value(trace_event, .{}, writer);
                try writer.writeAll("\n");
            }
        } 

        
        switch (current_event.type) {
            .reply, .repost, .quote => {
                // if the user had no posts to see, there is nothing to update
                if (poped_post) |current_post| { 
                    const propagated_event = TimelineEvent{
                        .time = t_clock, 
                        .post = current_post.post,
                    };
                    
                    for (current_user_ptr.*.followers) |follower_ptr| {
                        try follower_ptr.*.timeline.push(gpa, propagated_event);
                    }

                    interactions += 1;
                }
            },
            .like => interactions += 1,
            .nothing => ignored += 1,
        } 
    }
    
    if (trace) |writer| {
        try writer.writeAll("]");
        try writer.flush();
    }
    
    var timeline_backlog: usize = 0;
    for (users) |*user| {
        timeline_backlog += user.*.timeline.len();
    }

    const result = SimResults {
        .processed_events = processed_events,
        .duration = t_clock,
        .total_impressions = impressions,
        .total_ignored = ignored,
        .total_interactions = interactions,
        .avg_impressions_per_user = @as(f64, @floatFromInt(impressions)) / @as(f64, @floatFromInt(users.len)),
        .engagement_rate = @as(f64, @floatFromInt(interactions)) / @as(f64, @floatFromInt(impressions)),
        .avg_timeline_backlog = @as(f64, @floatFromInt(timeline_backlog)) / @as(f64, @floatFromInt(users.len)),
    };

    return result;
}


