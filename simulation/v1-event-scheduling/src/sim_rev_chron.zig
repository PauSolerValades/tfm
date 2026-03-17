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
const Session = entities.Session;
const User = entities.User;
const Post = entities.Post;
const TraceAction = entities.TraceAction;
const TimelineEvent = entities.TimelineEvent;
const compareTimelineEvent = entities.compareTimelineEvent;
const Index = entities.Index;

fn CreateRandomEvent(user_id: Index, user_session_gen: u64, event_id: u64, t_clock: f64, simconf: SimConfig, rng: Random) !Event {
    const action: Action = simconf.user_policy.sample(rng);
    const event_time = simconf.user_inter_action.sample(rng);
    const interaction_delay = simconf.interaction_delay.sample(rng);
    const event = Event{ 
        .time = t_clock + event_time + interaction_delay, 
        .type = .{ .action = action }, 
        .user_id = user_id, 
        .id = event_id, 
        .session_gen = user_session_gen,
    };
    
    return event;
}

const Unif = dist.Uniform(Precision);

pub fn staticOnePostScheduled(gpa: Allocator, rng: Random, simconf: SimConfig, graph: *gn.StaticNetworkGraph, trace: *Io.Writer, trace2: *Io.Writer) !SimResults {
    _ = gpa;
    _ = rng;
    _ = simconf;
    _ = graph;
    _ = trace;
    _ = trace2;

    const result = SimResults {
        .processed_events = 0,
        .duration = 0,
        .total_impressions = 0,
        .total_ignored = 0,
        .total_interactions = 0,
        .avg_impressions_per_user = 0, 
        .engagement_rate = 0,
        .avg_timeline_backlog = 0, 
        .total_sessions = 0 ,         // number of sessions for all the users
        .avg_session_length = 0,     // mean length of sessionsa
        .avg_post_per_session = 0,  // mean posts per sessions
        .timeline_drain_ratio = 0,
 
    };


    return result;
}
// pub fn staticOnePostScheduled(gpa: Allocator, rng: Random, simconf: SimConfig, graph: *gn.StaticNetworkGraph, trace: *Io.Writer) !SimResults {
//
//     const EventQueue: type = Heap(Event, void, entities.compareEvent);
//
//     var processed_events: u64 = 0;
//     var t_clock: f64 = 0.0;
//
//     var impressions: u64 = 0;
//     var interactions: u64 = 0;
//     var ignored: u64 = 0;
//
//     var starting_events = try gpa.alloc(Event, graph.users.len);
//     //defer gpa.free(starting_events); <- NO!! fromOwnedSlice takes ownership of this
//
//     var is_user_online: []bool = try gpa.alloc(bool, graph.users.len); // true: is online 
//     defer gpa.free(is_user_online);
//
//     const unif: Unif = .init(0, 1, dist.Interval.cc);
//
//     // add a first event per every user
//     for (0..graph.users.len) |i| {
//         const event = blk: {
//             const r = unif.sample(rng); 
//             if (r < simconf.init_vacation_ratio) {
//                 // this user is going in vacation. We schedule a wake up and we set them as inactive
//                 is_user_online[i] = false;
//                 const wake_up_time = simconf.user_inter_session.sample(rng);
//                 const e = Event{ 
//                     .time = wake_up_time, 
//                     .type = .start_session, 
//                     .user_id = @intCast(i), 
//                     .id = processed_events,
//                     .session_gen = 
//                 }; 
//                 break :blk 
//             } else {
//                 // No vacation, start_time = t_clock = 0
//                 is_user_online[i] = true;
//                 break :blk try CreateRandomEvent(@intCast(i), processed_events, 0, simconf, rng);
//             }
//         };
//
//         starting_events[i] = event;
//         processed_events += 1;
//     }
//
//     var queue = EventQueue.fromOwnedSlice(starting_events, {});
//     defer queue.deinit(gpa);
//
//     while (t_clock <= simconf.horizon and queue.items.len > 0) : (processed_events += 1) {
//         const current_event = queue.remove();
//         t_clock = current_event.time;
//
//         const current_user_id: Index = current_event.user_id;
//         const event = try CreateRandomEvent(current_user_id, processed_events, t_clock, simconf, rng);
//
//         try queue.add(gpa, event);
//
//         // pop seen post from the user associated with the event
//         const poped_post: ?TimelineEvent = graph.timelines[current_user_id].removeOrNull();
//
//         // if a user has no remaing posts in the timeline (eg simulation is very long it could run out of posts)
//         // we CANT stop generating actions, due to potential reply, repor or quotes that could fill the timeline again
//         // if no new posts are available, we should schedule an end of the session.
//         const current_post = poped_post orelse continue;
//
//         // TODO: IF NOT NULL GO OFFLINE AND LET YOUR TIMELINE FILL IN
//
//         // add the post reference to the historic of the current user
//         const post_id: Index = current_post.post_id;
//         // Use the DynamicBitMap
//         graph.user_seen_post.set(current_user_id * graph.posts.len + post_id);
//         impressions += 1;
//
//         const trace_event = TracePost{
//             .time = t_clock,
//             .type = current_event.type,
//             .event_id = processed_events,
//             .user_id = current_user_id,
//             .post_id = post_id,
//         };
//         // this might be very slow, it could be better to use the lower json api
//         try std.json.Stringify.value(trace_event, .{}, trace);
//         try trace.writeAll("\n");
//
//         switch (current_event.type) {
//             .repost => {
//
//                 const follower_start = graph.users.items(.follower_start)[current_user_id];
//                 const follower_count = graph.users.items(.follower_count)[current_user_id];
//
//                 for (graph.followers[follower_start..follower_start+follower_count]) |follower_id| {
//                     //check that user_ptr has not seen this post already...
//                     const p_id: Index = current_post.post_id;
//                     const matrix_index = follower_id * graph.posts.len + p_id; 
//                     if (!graph.user_seen_post.isSet(matrix_index)) {
//                         const propagation_delay = simconf.propagation_delay.sample(rng);
//                         const propagated_event = TimelineEvent{
//                             .time = t_clock + propagation_delay, 
//                             .post_id = p_id,
//                         };
//
//                         try graph.timelines[follower_id].add(gpa, propagated_event);
//
//                     } // else the post was seen_posts to do not add it
//                 }
//
//                 interactions += 1;
//             },
//             .like => interactions += 1,
//             .ignore => ignored += 1,
//             .start_session => is_user_online[current_user_id] = true,
//             .end_session => { 
//                 // TODO: QUESTION: should the timeline empty out when the user goes offline?¿ like, we can assumer 
//                 // there won't look at posts they've already looked at?? If they could the heap is already a bad choice as they
//                 // get poped xd
//
//                 // schedule users wake up time
//                 is_user_online[current_user_id] = false;
//                 const offline_duration = simconf.user_inter_session.sample(rng);
//                 const e = Event{ .time = t_clock + offline_duration, .type = .start_session, .user_id = current_user_id, .id = processed_events }; 
//                 try queue.add(gpa, e);
//             },
//             else => {},
//         }
//     }
//
//     try trace.flush();
//
//     var timeline_backlog: usize = 0;
//     for (graph.timelines) |*timeline| {
//         timeline_backlog += timeline.items.len;
//     }
//
//     const result = SimResults {
//         .processed_events = processed_events,
//         .duration = t_clock,
//         .total_impressions = impressions,
//         .total_ignored = ignored,
//         .total_interactions = interactions,
//         .avg_impressions_per_user = @as(f64, @floatFromInt(impressions)) / @as(f64, @floatFromInt(graph.users.len)),
//         .engagement_rate = @as(f64, @floatFromInt(interactions)) / @as(f64, @floatFromInt(impressions)),
//         .avg_timeline_backlog = @as(f64, @floatFromInt(timeline_backlog)) / @as(f64, @floatFromInt(graph.users.len)),
//     };
//
//     return result;
// }

const TraceSession = entities.TraceSession;

pub fn staticAllPostsScheduled(gpa: Allocator, rng: Random, simconf: SimConfig, graph: *gn.StaticNetworkGraph, action_trace: *Io.Writer, session_trace: *Io.Writer) !SimResults {

    const EventQueue: type = Heap(Event, void, entities.compareEvent);

    var processed_events: u64 = 0;
    var t_clock: f64 = 0.0;
    var is_warmed_up: bool = false;
    
    var impressions: u64 = 0;
    var interactions: u64 = 0;
    var ignored: u64 = 0;
   
    var total_sessions: u64 = 0;
    var total_online_time: f64 = 0.0;
    var empty_timeline_ends: u64 = 0;
    var max_duration_ends: u64 = 0;

    // Track when a user's session started to calculate duration later
    var session_start_times: []f64 = try gpa.alloc(f64, graph.users.len);
    @memset(session_start_times, 0.0); // Zero-initialize
    defer gpa.free(session_start_times);
   
    var is_user_online: []bool = try gpa.alloc(bool, graph.users.len);
    defer gpa.free(is_user_online);

    var user_session_gen: []u64 = try gpa.alloc(u64, graph.users.len);
    @memset(user_session_gen, 0);
    defer gpa.free(user_session_gen);

    // START: Generate all posts
    // as all the posts must be pregenerated, they all have to start before the warmup.
    var total_initial_events: usize = graph.users.len; // Space for the initial wakeups/sleeps
    for (0..graph.users.len) |user_id| {
        const post_count = graph.user_post_list[user_id].len;
        const follower_count = graph.users.items(.follower_count)[user_id];
        total_initial_events += post_count * follower_count; // Space for every single post delivery
    }

    var starting_events = try gpa.alloc(Event, total_initial_events);
    //defer gpa.free(starting_events); <- NO!! fromOwnedSlice takes ownership of this
    var event_idx: usize = 0;

    for (0..graph.users.len) |user_id| { 
        for (graph.user_post_list[user_id]) |post_id| {
            const follower_start = graph.users.items(.follower_start)[user_id];
            const follower_count = graph.users.items(.follower_count)[user_id];
            
            for (graph.followers[follower_start..follower_start+follower_count]) |follower_id| {
                const propagation_delay = simconf.propagation_delay.sample(rng);
                const t_post = simconf.post_time_creation.sample(rng);
                
                // Route to the main queue, NOT the timeline!
                starting_events[event_idx] = Event{ 
                    .time = t_post + propagation_delay, 
                    .type = .{ .receive_post = post_id }, 
                    .user_id = follower_id, 
                    .id = processed_events, 
                    .session_gen = 0 
                };
                event_idx += 1;
                processed_events += 1;
            }
        }
    }
    // END: generate initial events.
    
    // START: schedule sessions: which users start online, and when the offline ones will wake up
    const unif: Unif = .init(0, 1, dist.Interval.cc);

    for (0..graph.users.len) |i| {
        const r = unif.sample(rng); 
        if (r < simconf.init_offline_ratio) { // user starts offline
            is_user_online[i] = false;
            
            // when will the user go online 
            starting_events[event_idx] = Event{ 
                .time = simconf.user_inter_session.sample(rng), 
                .type = .{ .session = .start }, 
                .user_id = @intCast(i), 
                .id = processed_events, 
                .session_gen = 0 
            }; 
        } else { // users starts online
            is_user_online[i] = true;
            session_start_times[i] = 0.0;
            total_sessions += 1;
            
            // when will the user go offline
            starting_events[event_idx] = Event{ 
                .time = simconf.session_duration.sample(rng), 
                .type = .{ .session = .end }, 
                .user_id = @intCast(i), 
                .id = processed_events, 
                .session_gen = 0 
            }; 
        }
        event_idx += 1;
        processed_events += 1;
    }
    // END: schedule sessions
    
    var queue = EventQueue.fromOwnedSlice(starting_events, {});
    defer queue.deinit(gpa);

    // set online users first action
    for (0..graph.users.len) |i| {
        if (is_user_online[i]) {
            const first_action = try CreateRandomEvent(@intCast(i), 0, processed_events, 0, simconf, rng);
            try queue.add(gpa, first_action);
            processed_events += 1;
        }
    }

    const t_end = @min(simconf.warmup_time + simconf.duration, simconf.horizon);
    while (t_clock <= t_end and queue.items.len > 0) : (processed_events += 1) {
        const current_event = queue.remove();
        const current_user_id: Index = current_event.user_id;
        t_clock = current_event.time;

        // warmup reset 
        if (!is_warmed_up and t_clock >= simconf.warmup_time) {
            is_warmed_up = true;
            // reset all metrics
            impressions = 0; interactions = 0; ignored = 0;
            total_sessions = 0; total_online_time = 0.0;
            empty_timeline_ends = 0; max_duration_ends = 0;
            
            for (0..graph.users.len) |i| {
                if (is_user_online[i]) session_start_times[i] = t_clock;
                total_sessions += 1;
            }
        }
        
        switch (current_event.type) {
            .receive_post => |pid| {
                const pe = TimelineEvent{
                    .post_id = pid,
                    .time = t_clock,
                };
                try graph.timelines[current_user_id].add(gpa, pe);
            },

            .session => |ssn| {
                // this is to avoid the intrusive heap for the overlaping session
                // This is a stale event from a previous session. Ignore it!
                if (ssn == .end and (!is_user_online[current_user_id] or current_event.session_gen != user_session_gen[current_user_id])) {
                    continue; 
                }
       
                if (simconf.trace_to_file) {
                     const trace_event = TraceSession {
                        .time = t_clock,
                        .type = ssn,
                        .event_id = processed_events,
                        .user_id = current_user_id,
                    };

                    // this might be very slow, it could be better to use the lower json api
                    try std.json.Stringify.value(trace_event, .{}, session_trace);
                    try session_trace.writeAll("\n");
                }

                switch (ssn) {
                    .start => {
                        is_user_online[current_user_id] = true;
                        user_session_gen[current_user_id] += 1; // which session is the user on

                        session_start_times[current_user_id] = t_clock; // Record start time
                        total_sessions += 1;

                        const max_duration = simconf.session_duration.sample(rng);
                        const e = Event{ 
                            .time = t_clock + max_duration, 
                            .type = .{ .session = .end }, 
                            .user_id = current_user_id, 
                            .id = processed_events,
                            .session_gen = user_session_gen[current_user_id] // every event must be stamped 
                        }; 
                        try queue.add(gpa, e);

                        const first_action = try CreateRandomEvent(current_user_id, user_session_gen[current_user_id], processed_events, t_clock, simconf, rng);
                        try queue.add(gpa, first_action);
                    },
                    .end => {
                        // schedule users wake up time
                        is_user_online[current_user_id] = false;
                        // metrics 
                        total_online_time += (t_clock - session_start_times[current_user_id]);
                        max_duration_ends += 1;

                        const offline_duration = simconf.user_inter_session.sample(rng);
                        const e = Event{ 
                            .time = t_clock + offline_duration, 
                            .type = .{ .session = .start }, 
                            .user_id = current_user_id, 
                            .id = processed_events,
                            .session_gen = user_session_gen[current_user_id],
                        }; 
                        try queue.add(gpa, e);

                        // post non seen when session finished will get nuked
                        graph.timelines[current_user_id].clearRetainingCapacity();
                    }
                }
            },
            .action => |act| {
                // Guardrail against different session
                if (!is_user_online[current_user_id]) {
                    continue;
                }

                if (graph.timelines[current_user_id].removeOrNull()) |current_post| {
                    const post_id: Index = current_post.post_id;
                    const matrix_index = current_user_id * graph.posts.len + post_id;
                    
                    // user CANNOT see previous posts. Shouldn't happen here anyway. this is a _safeguard_
                    if (graph.user_seen_post.isSet(matrix_index)) {
                        const next_action = try CreateRandomEvent(current_user_id, user_session_gen[current_user_id], processed_events, t_clock, simconf, rng);
                        try queue.add(gpa, next_action);
                        continue; 
                    }

                    if (simconf.trace_to_file) {
                        const trace_event = TraceAction{
                            .time = t_clock,
                            .type = act,
                            .event_id = processed_events,
                            .user_id = current_user_id,
                            .post_id = post_id,
                        };

                        // this might be very slow, it could be better to use the lower json api
                        try std.json.Stringify.value(trace_event, .{}, action_trace);
                        try action_trace.writeAll("\n");
                    } 

                    graph.user_seen_post.set(matrix_index);
                    impressions += 1;
           
                    switch (act) {
                        .repost => {

                            const follower_start = graph.users.items(.follower_start)[current_user_id];
                            const follower_count = graph.users.items(.follower_count)[current_user_id];

                            const p_id: Index = current_post.post_id;

                            for (graph.followers[follower_start..follower_start+follower_count]) |follower_id| {
                                //check that user_ptr has not seen this post already...
                                const follower_matrix_index = follower_id * graph.posts.len + p_id; 

                                if (!graph.user_seen_post.isSet(follower_matrix_index)) {
                                    const propagation_delay = simconf.propagation_delay.sample(rng);
                                    const e = Event{ 
                                        .time = t_clock + propagation_delay, 
                                        .type = .{ .receive_post = p_id }, 
                                        .user_id = follower_id, 
                                        .id = processed_events, 
                                        .session_gen = 0 
                                    };
                                    try queue.add(gpa, e);
                                    processed_events += 1;
                                } // else the post was seen_posts to do not add it
                            }

                            interactions += 1;
                        },
                        .like => interactions += 1,
                        .ignore => ignored += 1,
                        else => unreachable,
                    }

                    const event = try CreateRandomEvent(current_user_id, user_session_gen[current_user_id], processed_events, t_clock, simconf, rng);
                    try queue.add(gpa, event);
   
                } else {
                    is_user_online[current_user_id] = false;
        
                    total_online_time += (t_clock - session_start_times[current_user_id]);
                    empty_timeline_ends += 1;

                    const offline_duration = simconf.user_inter_session.sample(rng);
                    const e = Event{ .time = t_clock + offline_duration, .type = .{ .session = .start }, .user_id = current_user_id, .id = processed_events, .session_gen = user_session_gen[current_user_id] }; 
                    try queue.add(gpa, e);
                    // no need to nuke the timeline, it's already empty
                }
            }
        }
    } 
   
    try action_trace.flush();
    try session_trace.flush();

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
        .total_sessions = total_sessions,
        .avg_session_length = total_online_time / @as(f64, @floatFromInt(total_sessions)),
        .avg_post_per_session = @as(f64, @floatFromInt(impressions)) / @as(f64, @floatFromInt(total_sessions)),
        .timeline_drain_ratio = @as(f64, @floatFromInt(empty_timeline_ends)) / @as(f64, @floatFromInt(total_sessions)),
    };
    
    return result;
}


