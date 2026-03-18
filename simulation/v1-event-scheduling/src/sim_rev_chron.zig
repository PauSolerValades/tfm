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
const Trace = entities.Trace;
const TimelineEvent = entities.TimelineEvent;
const compareTimelineEvent = entities.compareTimelineEvent;
const Index = entities.Index;

fn CreateRandomAction(user_id: Index, user_session_gen: u64, event_id: u64, t_clock: f64, simconf: SimConfig, rng: Random) !Event {
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

const TraceSession = entities.TraceSession;


pub fn stagedSimulation(gpa: Allocator, rng: Random, simconf: SimConfig, graph: *gn.StaticNetworkGraph, action_trace: *Io.Writer, session_trace: *Io.Writer) !SimResults {

    const EventQueue: type = Heap(Event, void, entities.compareEvent);

    var processed_events: u64 = 0;
    var t_clock: f64 = 0.0;
    
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
    @memset(is_user_online, false);
    defer gpa.free(is_user_online);

    var num_posts_per_user: []u32 = try gpa.alloc(u32, graph.users.len);
    @memset(num_posts_per_user, 0);
    defer gpa.free(num_posts_per_user);
    
    // allows us to end a user session early without looking up the Event Session.end for that specific user.
    var user_session_gen: []u64 = try gpa.alloc(u64, graph.users.len);
    @memset(user_session_gen, 0);
    defer gpa.free(user_session_gen);

  
    var queue: EventQueue = .empty;
    defer queue.deinit(gpa);
    
    // STAGE 1: only post generation
   
    var post_count: u32 = 0;

    // set up ONE Event.type = create to kickstart the sim
    for (0..graph.users.len) |uid| {
        // No need to check if max_posts is surpassed 
        const new_post_time = simconf.warmup_post_inter_creation.sample(rng);
        const create_post = Event{
            .time = new_post_time,
            .type = .{ .create = post_count },
            .user_id = @intCast(uid),
            .id = processed_events,
            .session_gen = 0,
        };

        graph.user_seen_post.set(uid * simconf.max_post_per_user + post_count);
    
        try queue.add(gpa, create_post); 
        
        num_posts_per_user[uid] += 1;
        post_count += 1;
    }

    // STAGE 1 loop:
    while (t_clock <= simconf.warmup_time and queue.items.len > 0) {
        const current_event = queue.remove();
        t_clock = current_event.time;

        const current_uid = current_event.user_id;

        switch (current_event.type) {
            .create => |pid| {

                if (num_posts_per_user[current_uid] > simconf.max_post_per_user) continue;
                
                // Logic of post propagations to the followers
                // the created post should appear to other timelines
                const follower_start = graph.users.items(.follower_start)[current_uid];
                const follower_count = graph.users.items(.follower_count)[current_uid];
                
                for (graph.followers[follower_start..follower_start+follower_count]) |fid| {
                    //check that user_ptr has not seen this post already...
                    const matrix_index = fid * simconf.max_post_per_user + pid; 
                    if (!graph.user_seen_post.isSet(matrix_index)) {
                        const propagation_delay = simconf.propagation_delay.sample(rng);
                        const propagated_event = TimelineEvent{
                            .time = t_clock + propagation_delay, 
                            .post_id = pid,
                        };

                        try graph.timelines[fid].add(gpa, propagated_event);
                    } // else the post was seen_posts to do not add it
                }

                // schedule next event
                post_count += 1;
                
                const new_post_time = simconf.warmup_post_inter_creation.sample(rng);
                const new_post = Event{
                    .time = t_clock + new_post_time,
                    .type = .{ .create = post_count },
                    .user_id = current_uid,
                    .id = processed_events,
                    .session_gen = user_session_gen[current_uid],
                };
                
                try queue.add(gpa, new_post);
            },
            else => unreachable,
        }
    }


    // START: schedule sessions: which users start online, and when the offline ones will wake up
    const unif: Unif = .init(0, 1, dist.Interval.cc);

    for (0..graph.users.len) |i| {
        const r = unif.sample(rng); 
        if (r < simconf.offline_startup_ratio) { // user starts offline
            is_user_online[i] = false;
           
            const offline_duration = simconf.user_inter_session.sample(rng);
            // when will the user go online 
            const event_start = Event{ 
                .time = t_clock + offline_duration, 
                .type = .{ .session = .start }, 
                .user_id = @intCast(i), 
                .id = processed_events, 
                .session_gen = 0 
            }; 


            try queue.add(gpa, event_start);

            
        } else { // users starts online
            is_user_online[i] = true;
            session_start_times[i] = 0.0;
            total_sessions += 1;
            
            // when will the user go offline
            const event_end = Event{ 
                .time = t_clock + simconf.session_duration.sample(rng), 
                .type = .{ .session = .end }, 
                .user_id = @intCast(i), 
                .id = processed_events, 
                .session_gen = 0 
            }; 
            
            try queue.add(gpa, event_end);

            if (simconf.trace_to_file) {
                const trace_event = TraceSession {
                    .time = t_clock,
                    .type = .start,
                    .event_id = processed_events,
                    .user_id = @intCast(i),
                };
                try std.json.Stringify.value(trace_event, .{}, session_trace);
                try session_trace.writeAll("\n");
            }
        }
        processed_events += 1;
    }
    // END: schedule sessions
    

    // set online users first action
    for (0..graph.users.len) |i| {
        if (is_user_online[i]) {
            const first_action = try CreateRandomAction(@intCast(i), 0, processed_events, t_clock, simconf, rng);
            try queue.add(gpa, first_action);
            processed_events += 1;
        }
    }

    const t_end = @min(simconf.warmup_time + simconf.duration, simconf.horizon);
    while (t_clock <= t_end and queue.items.len > 0) : (processed_events += 1) {
        const current_event = queue.remove();
        const current_uid: Index = current_event.user_id;
        t_clock = current_event.time;

        switch (current_event.type) {
            .create => |to_propagate_pid| {
               
                const is_event_stale: bool = current_event.session_gen != user_session_gen[current_uid];
                const max_posts_reached = num_posts_per_user[current_uid] > simconf.max_post_per_user;

                if (is_event_stale or max_posts_reached) continue;

                if (is_user_online[current_uid]) {
                    graph.user_seen_post.set(current_uid * simconf.max_post_per_user + to_propagate_pid);
                
                    const follower_start = graph.users.items(.follower_start)[current_uid];
                    const follower_count = graph.users.items(.follower_count)[current_uid];
                    
                    for (graph.followers[follower_start..follower_start+follower_count]) |fid| {
                        //check that user_ptr has not seen this post already...
                        
                        // as it's a new post there is no need to check if it has been seen before
                        // on graph.user_seen_post
                        const propagation_delay = simconf.propagation_delay.sample(rng);
                        const propagated_event = TimelineEvent{
                            .time = t_clock + propagation_delay, 
                            .post_id = to_propagate_pid,
                        };

                        try graph.timelines[fid].add(gpa, propagated_event);
                    }
                    
                    if (simconf.trace_to_file) {
                        const trace_event = Trace {
                            .time = t_clock,
                            .event_id = processed_events,
                            .type = .{ .create = to_propagate_pid },
                            .user_id = current_uid,
                        };
                        
                        try std.json.Stringify.value(trace_event, .{}, action_trace);
                        try action_trace.writeAll("\n");
                    }
                }
            
                // schedule new creation
                const new_post_time = simconf.post_inter_creation.sample(rng);
                const new_post = Event{
                    .time = t_clock + new_post_time,
                    .type = .{ .create = post_count },
                    .user_id = current_uid,
                    .id = processed_events,
                    .session_gen = user_session_gen[current_uid],
                };
                
                try queue.add(gpa, new_post);
                post_count += 1;
            },

            .session => |ssn| {
                // this is to avoid the intrusive heap for the overlaping session
                const is_event_stale: bool = current_event.session_gen != user_session_gen[current_uid];
                if (ssn == .end and (!is_user_online[current_uid] or is_event_stale)) {
                    continue; 
                }
       
                if (simconf.trace_to_file) {
                     const trace_event = TraceSession {
                        .time = t_clock,
                        .type = ssn,
                        .event_id = processed_events,
                        .user_id = current_uid,
                    };

                    // this might be very slow, it could be better to use the lower json api
                    try std.json.Stringify.value(trace_event, .{}, session_trace);
                    try session_trace.writeAll("\n");
                }

                switch (ssn) {
                    .start => {
                        is_user_online[current_uid] = true;
                        user_session_gen[current_uid] += 1; // which session is the user on

                        session_start_times[current_uid] = t_clock; // Record start time
                        total_sessions += 1;

                        const max_duration = simconf.session_duration.sample(rng);
                        const e = Event{ 
                            .time = t_clock + max_duration, 
                            .type = .{ .session = .end }, 
                            .user_id = current_uid, 
                            .id = processed_events,
                            .session_gen = user_session_gen[current_uid] // every event must be stamped 
                        }; 
                        try queue.add(gpa, e);

                        const first_action = try CreateRandomAction(current_uid, user_session_gen[current_uid], processed_events, t_clock, simconf, rng);
                        try queue.add(gpa, first_action);
                 
                        const new_post_time = simconf.post_inter_creation.sample(rng);
                        const new_post = Event{
                            .time = t_clock + new_post_time,
                            .type = .{ .create = post_count },
                            .user_id = current_uid,
                            .id = processed_events,
                            .session_gen = user_session_gen[current_uid],
                        };
                        try queue.add(gpa, new_post);
                        
                        post_count += 1;
                    },
                    .end => {
                        // schedule users wake up time
                        is_user_online[current_uid] = false;
                        // metrics 
                        total_online_time += (t_clock - session_start_times[current_uid]);
                        max_duration_ends += 1;

                        const offline_duration = simconf.user_inter_session.sample(rng);
                        const e = Event{ 
                            .time = t_clock + offline_duration, 
                            .type = .{ .session = .start }, 
                            .user_id = current_uid, 
                            .id = processed_events,
                            .session_gen = user_session_gen[current_uid],
                        }; 
                        try queue.add(gpa, e);

                        // post non seen when session finished will get nuked
                        graph.timelines[current_uid].clearRetainingCapacity();
                    }
                }
            },
            .action => |act| {
                const is_event_stale: bool = current_event.session_gen != user_session_gen[current_uid];
                if (is_event_stale) continue;

                if (!is_user_online[current_uid]) {
                    continue;
                }
    
                if (graph.timelines[current_uid].removeOrNull()) |current_post| {
                    const post_id: Index = current_post.post_id;
                    const matrix_index = current_uid * simconf.max_post_per_user + post_id;
                    
                    // user CANNOT see previous posts. Shouldn't happen here anyway. this is a _safeguard_
                    if (graph.user_seen_post.isSet(matrix_index)) {
                        const next_action = try CreateRandomAction(current_uid, user_session_gen[current_uid], processed_events, t_clock, simconf, rng);
                        try queue.add(gpa, next_action);
                        continue; 
                    }

                    if (simconf.trace_to_file) {
                        const trace_event = Trace{
                            .time = t_clock,
                            .type = .{ .action = act },
                            .event_id = processed_events,
                            .user_id = current_uid,
                        };

                        // this might be very slow, it could be better to use the lower json api
                        try std.json.Stringify.value(trace_event, .{}, action_trace);
                        try action_trace.writeAll("\n");
                    } 

                    graph.user_seen_post.set(matrix_index);
                    impressions += 1;
           
                    switch (act) {
                        .repost => {

                            const follower_start = graph.users.items(.follower_start)[current_uid];
                            const follower_count = graph.users.items(.follower_count)[current_uid];

                            const p_id: Index = current_post.post_id;

                            for (graph.followers[follower_start..follower_start+follower_count]) |follower_id| {
                                //check that user_ptr has not seen this post already...
                                const follower_matrix_index = follower_id * simconf.max_post_per_user + p_id; 

                                if (!graph.user_seen_post.isSet(follower_matrix_index)) {
                                    const propagation_delay = simconf.propagation_delay.sample(rng);
                                    
                                    const propagated_event = TimelineEvent{
                                        .time = t_clock + propagation_delay, 
                                        .post_id = p_id,
                                    };
                                    try graph.timelines[follower_id].add(gpa, propagated_event);
                                   
                                    processed_events += 1;
                                } // else the post was seen_posts to do not add it
                            }

                            interactions += 1;
                        },
                        .like => interactions += 1,
                        .ignore => ignored += 1,
                    }

                    const event = try CreateRandomAction(current_uid, user_session_gen[current_uid], processed_events, t_clock, simconf, rng);
                    try queue.add(gpa, event);
   
                } else {
                    is_user_online[current_uid] = false;
        
                    total_online_time += (t_clock - session_start_times[current_uid]);
                    empty_timeline_ends += 1;
                    user_session_gen[current_uid] += 1;
                    
                    if (simconf.trace_to_file) {
                        const trace_event = TraceSession {
                            .time = t_clock,
                            .type = .end,
                            .event_id = processed_events,
                            .user_id = current_uid,
                        };
                        try std.json.Stringify.value(trace_event, .{}, session_trace);
                        try session_trace.writeAll("\n");
                    }

                    const offline_duration = simconf.user_inter_session.sample(rng);
                    const e = Event{ 
                        .time = t_clock + offline_duration, 
                        .type = .{ .session = .start }, 
                        .user_id = current_uid, 
                        .id = processed_events, 
                        .session_gen = user_session_gen[current_uid] 
                    }; 
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


