const std = @import("std");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Random = std.Random;
const Io = std.Io;
const Order = std.math.Order;

const Heap = @import("heap").Heap;

const dist = @import("distributions");

const config = @import("config.zig");
const entities = @import("entities.zig");
const gn = @import("graph_network.zig");

const SimResults = config.SimResults;
const SimConfig = config.SimConfig;

const Precision = config.Precision;

const Event = entities.Event;
const Action = entities.Action;
const User = entities.User;
const Post = entities.Post;
const TracePost = entities.TracePost;
const TimelineEvent = entities.TimelineEvent;
const compareTimelineEvent = entities.compareTimelineEvent;
const Index = entities.Index;

fn CreateRandomEvent(user_id: Index, event_id: u64, t_clock: f64, simconf: SimConfig, rng: Random) !Event {
    const action: Action = simconf.user_policy.sample(rng);
    const event_time = simconf.user_inter_action.sample(rng);
    const interaction_delay = simconf.interaction_delay.sample(rng);
    const event = Event{ 
        .time = t_clock + event_time + interaction_delay, 
        .type = action, 
        .user_id = user_id, 
        .id = event_id, 
    };
    
    return event;
}

pub fn v1(gpa: Allocator, rng: Random, simconf: SimConfig, graph: *gn.StaticNetworkGraph, trace: *Io.Writer) !SimResults {

    const EventQueue: type = Heap(Event, void, entities.compareEvent);

    var processed_events: u64 = 0;
    var t_clock: f64 = 0.0;
    
    var impressions: u64 = 0;
    var interactions: u64 = 0;
    var ignored: u64 = 0;
   
    var starting_events = try gpa.alloc(Event, graph.users.len);
    //defer gpa.free(starting_events); <- NO!! fromOwnedSlice takes ownership of this

    // add a first event per every user
    for (0..graph.users.len) |i| { // users are in odrder, that i is the user id
        const event = try CreateRandomEvent(@intCast(i), processed_events, 0, simconf, rng);
        starting_events[i] = event;
        processed_events += 1;
    }
    
    var queue = EventQueue.fromOwnedSlice(starting_events, {});
    defer queue.deinit(gpa);
    
    while (t_clock <= simconf.horizon and queue.items.len > 0) : (processed_events += 1) {
        const current_event = queue.remove();
        t_clock = current_event.time;
        
        const current_user_id: Index = current_event.user_id; 
        const event = try CreateRandomEvent(current_user_id, processed_events, t_clock, simconf, rng);

        try queue.add(gpa, event);
        
        // pop seen post from the user associated with the event
        const poped_post: ?TimelineEvent = graph.timelines[current_user_id].removeOrNull();

        
        // if a user has no remaing posts in the timeline (eg simulation is very long it could run out of posts)
        // we CANT stop generating actions, due to potential reply, repor or quotes that could fill the timeline again
        const current_post = poped_post orelse continue;

        // add the post reference to the historic of the current user
        const post_id: Index = current_post.post_id;
        // Use the DynamicBitMap
        graph.user_seen_post.set(current_user_id * graph.posts.len + post_id);
        impressions += 1;
        
        const trace_event = TracePost{
            .time = t_clock,
            .type = current_event.type,
            .event_id = processed_events,
            .user_id = current_user_id,
            .post_id = post_id,
        };
        // this might be very slow, it could be better to use the lower json api
        try std.json.Stringify.value(trace_event, .{}, trace);
        try trace.writeAll("\n");

        switch (current_event.type) {
            .repost => {
                    
                const follower_start = graph.users.items(.follower_start)[current_user_id];
                const follower_count = graph.users.items(.follower_count)[current_user_id];
                
                for (graph.followers[follower_start..follower_start+follower_count]) |follower_id| {
                    //check that user_ptr has not seen this post already...
                    const p_id: Index = current_post.post_id;
                    const matrix_index = follower_id * graph.posts.len + p_id; 
                    if (!graph.user_seen_post.isSet(matrix_index)) {
                        const propagation_delay = simconf.propagation_delay.sample(rng);
                        const propagated_event = TimelineEvent{
                            .time = t_clock + propagation_delay, 
                            .post_id = p_id,
                        };

                        try graph.timelines[follower_id].add(gpa, propagated_event);

                    } // else the post was seen_posts to do not add it
                }

                interactions += 1;
            },
            .like => interactions += 1,
            .ignore => ignored += 1,
            else => {}, // other options from v2
        }
    }
    
    try trace.flush();
    
    var timeline_backlog: usize = 0;
    for (graph.timelines) |*timeline| {
        timeline_backlog += timeline.items.len;
    }

    const result = SimResults {
        .processed_events = processed_events,
        .duration = t_clock,
        .total_impressions = impressions,
        .total_ignored = ignored,
        .total_interactions = interactions,
        .avg_impressions_per_user = @as(f64, @floatFromInt(impressions)) / @as(f64, @floatFromInt(graph.users.len)),
        .engagement_rate = @as(f64, @floatFromInt(interactions)) / @as(f64, @floatFromInt(impressions)),
        .avg_timeline_backlog = @as(f64, @floatFromInt(timeline_backlog)) / @as(f64, @floatFromInt(graph.users.len)),
    };
    
    return result;
}


const Unif = dist.Uniform(Precision);

pub fn v2(gpa: Allocator, rng: Random, simconf: SimConfig, graph: *gn.StaticNetworkGraph, trace: *Io.Writer) !SimResults {

    const EventQueue: type = Heap(Event, void, entities.compareEvent);

    var processed_events: u64 = 0;
    var t_clock: f64 = 0.0;
    
    var impressions: u64 = 0;
    var interactions: u64 = 0;
    var ignored: u64 = 0;
   
    var starting_events = try gpa.alloc(Event, graph.users.len);
    //defer gpa.free(starting_events); <- NO!! fromOwnedSlice takes ownership of this
    
    var is_user_online: []bool = try gpa.alloc(bool, graph.users.len); // true: is online 
    defer gpa.free(is_user_online);

    const unif: Unif = .init(0, 1, dist.Interval.cc);
    
    // add a first event per every user
    for (0..graph.users.len) |i| {
        const event = blk: {
            const r = unif.sample(rng); 
            if (r < simconf.init_vacation_ratio) {
                // this user is going in vacation. We schedule a wake up and we set them as inactive
                is_user_online[i] = false;
                const wake_up_time = simconf.user_inter_session.sample(rng);
                break :blk Event{ .time = wake_up_time, .type = .start_session, .user_id = @intCast(i), .id = processed_events }; 
            } else {
                // No vacation, start_time = t_clock = 0
                is_user_online[i] = true;
                break :blk try CreateRandomEvent(@intCast(i), processed_events, 0, simconf, rng);
            }
        };
        
        starting_events[i] = event;
        processed_events += 1;
    }
    
    var queue = EventQueue.fromOwnedSlice(starting_events, {});
    defer queue.deinit(gpa);
    
    while (t_clock <= simconf.horizon and queue.items.len > 0) : (processed_events += 1) {
        const current_event = queue.remove();
        t_clock = current_event.time;
        
        const current_user_id: Index = current_event.user_id;
        const event = try CreateRandomEvent(current_user_id, processed_events, t_clock, simconf, rng);

        try queue.add(gpa, event);
        
        // pop seen post from the user associated with the event
        const poped_post: ?TimelineEvent = graph.timelines[current_user_id].removeOrNull();

        // if a user has no remaing posts in the timeline (eg simulation is very long it could run out of posts)
        // we CANT stop generating actions, due to potential reply, repor or quotes that could fill the timeline again
        const current_post = poped_post orelse continue;

        // add the post reference to the historic of the current user
        const post_id: Index = current_post.post_id;
        // Use the DynamicBitMap
        graph.user_seen_post.set(current_user_id * graph.posts.len + post_id);
        impressions += 1;
        
        const trace_event = TracePost{
            .time = t_clock,
            .type = current_event.type,
            .event_id = processed_events,
            .user_id = current_user_id,
            .post_id = post_id,
        };
        // this might be very slow, it could be better to use the lower json api
        try std.json.Stringify.value(trace_event, .{}, trace);
        try trace.writeAll("\n");

        switch (current_event.type) {
            .repost => {
                    
                const follower_start = graph.users.items(.follower_start)[current_user_id];
                const follower_count = graph.users.items(.follower_count)[current_user_id];
                
                for (graph.followers[follower_start..follower_start+follower_count]) |follower_id| {
                    //check that user_ptr has not seen this post already...
                    const p_id: Index = current_post.post_id;
                    const matrix_index = follower_id * graph.posts.len + p_id; 
                    if (!graph.user_seen_post.isSet(matrix_index)) {
                        const propagation_delay = simconf.propagation_delay.sample(rng);
                        const propagated_event = TimelineEvent{
                            .time = t_clock + propagation_delay, 
                            .post_id = p_id,
                        };

                        try graph.timelines[follower_id].add(gpa, propagated_event);

                    } // else the post was seen_posts to do not add it
                }

                interactions += 1;
            },
            .like => interactions += 1,
            .ignore => ignored += 1,
            .start_session => is_user_online[current_user_id] = true,
            .end_session => {
                // schedule users wake up time
                is_user_online[current_user_id] = false;
                const offline_duration = simconf.user_inter_session.sample(rng);
                const e = Event{ .time = t_clock + offline_duration, .type = .start_session, .user_id = current_user_id, .id = processed_events }; 
                try queue.add(gpa, e);
            },        
        }
    }
    
    try trace.flush();
    
    var timeline_backlog: usize = 0;
    for (graph.timelines) |*timeline| {
        timeline_backlog += timeline.items.len;
    }

    const result = SimResults {
        .processed_events = processed_events,
        .duration = t_clock,
        .total_impressions = impressions,
        .total_ignored = ignored,
        .total_interactions = interactions,
        .avg_impressions_per_user = @as(f64, @floatFromInt(impressions)) / @as(f64, @floatFromInt(graph.users.len)),
        .engagement_rate = @as(f64, @floatFromInt(interactions)) / @as(f64, @floatFromInt(impressions)),
        .avg_timeline_backlog = @as(f64, @floatFromInt(timeline_backlog)) / @as(f64, @floatFromInt(graph.users.len)),
    };
    
    return result;
}


