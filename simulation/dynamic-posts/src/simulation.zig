const std = @import("std");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Random = std.Random;
const Io = std.Io;
const Order = std.math.Order;

const Heap = @import("ds").Heap;

const dist = @import("distributions");

const config = @import("config.zig");
const entities = @import("entities.zig");
const gn = @import("graph_network.zig");

const SimResults = config.SimResults;
const SimConfig = config.SimConfig;
const Topology = gn.Topology;

const Precision = config.Precision;

const Event = entities.Event;
const Action = entities.Action;
const Session = entities.Session;
const User = entities.User;
const Post = entities.Post;
const TraceAction = entities.TraceAction;
const TraceSession = entities.TraceSession;
const TraceCreate = entities.TraceCreate;
const TimelineEvent = entities.TimelineEvent;
const compareTimelineEvent = entities.compareTimelineEvent;
const Index = entities.Index;


const EventQueue: type = Heap(Event, void, entities.compareEvent);


pub const SimMetrics = struct {
    processed_events: u64 = 0,
    generated_events: u64 = 0,
    dropped_events: u64 = 0,

    post_count: u32 = 0,
    
    impressions: u64 = 0,
    reposts: u64 = 0,
    likes: u64 = 0,
    ignored: u64 = 0,
    
    total_sessions: u64 = 0,
    total_online_time: f64 = 0.0,
    empty_timeline_ends: u64 = 0,
    max_duration_ends: u64 = 0,
};


fn CreateRandomAction(rng: Random, simconf: SimConfig, t_clock: f64, user_id: Index, user_session_gen: u64, event_id: u64) !Event {
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

fn propagatePost(
    gpa: Allocator, 
    rng: Random, 
    graph: *Topology, 
    simconf: SimConfig, 
    t_clock: f64, 
    user_id: Index, 
    post_id: Index
) !void {

    const follower_start = graph.users.items(.follower_start)[user_id];
    const follower_count = graph.users.items(.follower_count)[user_id];
    
    for (graph.followers[follower_start..follower_start+follower_count]) |fid| {
        //check that user_ptr has not seen this post already...
        if (!graph.user_seen_post.isSet(fid, post_id)) {
            const propagation_delay = simconf.propagation_delay.sample(rng);
            const propagated_event = TimelineEvent{
                .time = t_clock + propagation_delay, 
                .post_id = post_id,
            };

            try graph.timelines[fid].add(gpa, propagated_event);

        } // else the post was seen_posts to do not add it
    }
}


fn stageOne(
    gpa: Allocator, 
    rng: Random, 
    simconf: SimConfig, 
    graph: *Topology, 
    queue: *EventQueue,
    metrics: *SimMetrics,
    t_clock: *f64, 
    create_trace: *Io.Writer,
) !void {

    // there will be at least one post per user, so we ensure this capacity at the beginng 
    try graph.user_seen_post.ensureItemCapacity(gpa, graph.users.len);
    for (0..graph.users.len) |uid| {
        const creation_delay = simconf.creation_delay.sample(rng);
        const t_creation_decision = simconf.warmup_post_inter_creation.sample(rng);
        const create_post = Event{
            .time = t_creation_decision + creation_delay,
            .type = .{ .create = metrics.post_count },
            .user_id = @intCast(uid),
            .id = metrics.generated_events,
            .session_gen = 0,
        };

        graph.user_seen_post.set(uid, metrics.post_count);
        
        try queue.add(gpa, create_post); 
        metrics.generated_events += 1;
        
        graph.users.items(.num_posts)[uid] += 1;
        try graph.posts.append(gpa, .{ .id = metrics.post_count, .author = @intCast(uid) });
        
        metrics.processed_events += 1;
        metrics.post_count += 1;
        
    }

    while (t_clock.* <= simconf.warmup_time and queue.items.len > 0) {
        const current_event = queue.remove();
        t_clock.* = current_event.time;

        const current_uid = current_event.user_id;
        const gen_id = current_event.id;

        switch (current_event.type) {
            .create => |pid| {
                // Read from the dynamic user slice
                const max_posts_reached: bool = if (graph.users.items(.max_posts)[current_uid]) |max_posts_user|
                    max_posts_user <= graph.users.items(.num_posts)[current_uid]
                else false;

                if (max_posts_reached) {
                    metrics.dropped_events += 1;
                    continue;
                }
                
                try graph.posts.append(gpa, .{ .id = pid, .author = current_uid});
                try graph.user_seen_post.ensureItemCapacity(gpa, pid);
                try propagatePost(gpa, rng, graph, simconf, t_clock.*, current_uid, pid);
                
                if (simconf.trace_to_file) { 
                    const c = TraceCreate{ .time = t_clock.*, .user_id = current_uid, .post_id = pid, .event_id = metrics.processed_events, .gen_id = gen_id };
                    try writeToTrace(TraceCreate, create_trace, c);
                } 
                metrics.post_count += 1;
                
                // Schedule the next post creation for this user
                const creation_delay = simconf.creation_delay.sample(rng);
                const duration_between_creation = simconf.warmup_post_inter_creation.sample(rng);
                const new_post = Event{
                    .time = t_clock.* + duration_between_creation + creation_delay,
                    .type = .{ .create = metrics.post_count },
                    .user_id = current_uid,
                    .id = metrics.processed_events,
                    .session_gen = graph.users.items(.session_gen)[current_uid],
                };
                
                try queue.add(gpa, new_post);
                metrics.generated_events += 1;
            },
            else => unreachable,
        }
        metrics.processed_events += 1;  // an event is always processed, there is no continues
    }
}

pub fn initSessions(
    gpa: Allocator, 
    rng: Random, 
    simconf: SimConfig, 
    graph: *Topology, 
    queue: *EventQueue,
    metrics: *SimMetrics, 
    t_clock: f64,
) !void {
    const unif: Unif = .init(0, 1, dist.Interval.cc);

    for (0..graph.users.len) |uid| {
        const r = unif.sample(rng); 
        metrics.processed_events += 1;
        if (r < simconf.offline_startup_ratio) { // user starts offline
            graph.users.items(.is_online)[uid] = false;
        
            // when will the user go online 
            const offline_duration = simconf.user_inter_session.sample(rng);
            const event_start = Event{ 
                .time = t_clock + offline_duration, 
                .type = .{ .session = .start }, 
                .user_id = @intCast(uid), 
                .id = metrics.generated_events, 
                .session_gen = 0 
            }; 

            try queue.add(gpa, event_start);
            metrics.generated_events += 1;
            
        } else { // users starts online
            graph.users.items(.is_online)[uid] = true;
            graph.users.items(.session_start_time)[uid] = 0.0;
            metrics.total_sessions += 1;
 
            // when will the user go offline
            const duration = simconf.session_duration.sample(rng);
            const event_end = Event{ 
                .time = t_clock + duration, 
                .type = .{ .session = .end }, 
                .user_id = @intCast(uid), 
                .id = metrics.generated_events, 
                .session_gen = 0 
            }; 
            
            try queue.add(gpa, event_end);
            metrics.generated_events += 1;
        }
        //metrics.processed_events += 1; // not a single event has been processed
    }
}

pub fn simulate(gpa: Allocator, rng: Random, simconf: SimConfig, graph: *Topology, action_trace: *Io.Writer, session_trace: *Io.Writer, create_trace: *Io.Writer) !SimResults {

    var t_clock: f64 = 0.0;
    
    var metrics = SimMetrics{};

    var queue: EventQueue = .empty;
    defer queue.deinit(gpa);
    
    // Post generation on init 
    try stageOne(gpa, rng, simconf, graph, &queue, &metrics, &t_clock, create_trace);
    
    // decide which users start online or not
    try initSessions(gpa, rng, simconf, graph, &queue, &metrics, t_clock);

    // set online users first action
    for (0..graph.users.len) |uid| {
        if (graph.users.items(.is_online)[uid]) {
            const first_action = try CreateRandomAction(
                rng,
                simconf,
                t_clock,
                @intCast(uid), 
                0, 
                metrics.generated_events,
            );
            try queue.add(gpa, first_action);
            metrics.generated_events += 1;

            const creation_delay = simconf.creation_delay.sample(rng);
            const duration_between_creation = simconf.warmup_post_inter_creation.sample(rng);
            const new_post = Event{
                .time = t_clock + creation_delay + duration_between_creation,
                .type = .{ .create = 0 },
                .user_id = @intCast(uid),
                .id = metrics.generated_events,
                .session_gen = graph.users.items(.session_gen)[uid],
            };
            
            try queue.add(gpa, new_post);
            metrics.generated_events += 1;
        }
    }

    const t_end = @min(simconf.warmup_time + simconf.duration, simconf.horizon);
    while (t_clock <= t_end and queue.items.len > 0) {
        const current_event = queue.remove();
        const current_uid: Index = current_event.user_id;
        const gen_id = current_event.id;
        std.debug.assert(current_event.time >= t_clock);
        t_clock = current_event.time;

        switch (current_event.type) {
            .create => {
                const is_event_stale: bool = current_event.session_gen != graph.users.items(.session_gen)[current_uid];
                const is_user_online: bool = graph.users.items(.is_online)[current_uid];
                // check if user can have max post
                const max_posts_reached = if (graph.users.items(.max_posts)[current_uid]) |max_post_user| 
                    max_post_user <= graph.users.items(.num_posts)[current_uid]
                else
                    false;
               
                // Note: if an event is stale the user cannot be online. it's just a double check
                if (is_event_stale or max_posts_reached or !is_user_online) {
                    metrics.dropped_events += 1;
                    continue;
                }
                const new_post_id = metrics.post_count;
                   
                graph.users.items(.num_posts)[current_uid] += 1;
                try graph.user_seen_post.ensureItemCapacity(gpa, new_post_id);
                graph.user_seen_post.set(current_uid, new_post_id); // post is marked as created

                try propagatePost(gpa, rng, graph, simconf, t_clock, current_uid, new_post_id);
                
                if (simconf.trace_to_file) { 
                    const c = TraceCreate{ .time = t_clock, .user_id = current_uid, .post_id = new_post_id, .event_id = metrics.processed_events, .gen_id = gen_id };
                    try writeToTrace(TraceCreate, create_trace, c);
                } 
                metrics.post_count += 1;
                metrics.processed_events += 1; 
                
                // schedule new creation
                const creation_delay = simconf.creation_delay.sample(rng);
                const duration_between_creation = simconf.warmup_post_inter_creation.sample(rng);
                const new_post = Event{
                    .time = t_clock + creation_delay + duration_between_creation,
                    .type = .{ .create = 0 }, // dummy posts for now, will get assigned on creation
                    .user_id = current_uid,
                    .session_gen = graph.users.items(.session_gen)[current_uid],
                    .id = metrics.generated_events,
                };
                
                try queue.add(gpa, new_post);
                metrics.generated_events += 1;
            },

            .session => |ssn| {
                // a session can be stale due to the catch up mechanic. 
                const is_event_stale: bool = current_event.session_gen != graph.users.items(.session_gen)[current_uid];
                if (ssn == .end and (!graph.users.items(.is_online)[current_uid] or is_event_stale)) {
                    metrics.dropped_events += 1;
                    continue;
                } 
                
                if (simconf.trace_to_file) { 
                    const s = TraceSession{ .time = t_clock, .type = ssn, .user_id = current_uid, .event_id = metrics.processed_events, .gen_id = gen_id };
                    try writeToTrace(TraceSession, session_trace, s);
                }
                
                switch (ssn) {
                    .start => {
                        graph.users.items(.is_online)[current_uid] = true;
                        graph.users.items(.session_gen)[current_uid] += 1;

                        graph.users.items(.session_start_time)[current_uid] = t_clock; // Record start time
                        metrics.total_sessions += 1;

                        const max_duration = simconf.session_duration.sample(rng);
                        const e = Event{ 
                            .time = t_clock + max_duration, 
                            .type = .{ .session = .end }, 
                            .user_id = current_uid, 
                            .id = metrics.generated_events,
                            .session_gen = graph.users.items(.session_gen)[current_uid] // every event must be stamped 
                        }; 
                        try queue.add(gpa, e);
                        metrics.generated_events += 1;

                        const first_action = try CreateRandomAction(
                            rng,
                            simconf,
                            t_clock,
                            current_uid,
                            graph.users.items(.session_gen)[current_uid], 
                            metrics.generated_events, 
                        );
                        try queue.add(gpa, first_action);
                        metrics.generated_events += 1;
                        
                        const new_post_time = simconf.post_inter_creation.sample(rng);
                        const new_post = Event{
                            .time = t_clock + new_post_time,
                            .type = .{ .create = 0 },
                            .user_id = current_uid,
                            .id = metrics.generated_events,
                            .session_gen = graph.users.items(.session_gen)[current_uid],
                        };
                        try queue.add(gpa, new_post);
                        metrics.generated_events += 1;

                    },
                    .end => {
                        // schedule users wake up time
                        graph.users.items(.is_online)[current_uid] = false;
                        // metrics 
                        metrics.total_online_time += (t_clock - graph.users.items(.session_start_time)[current_uid]);
                        metrics.max_duration_ends += 1;

                        const offline_duration = simconf.user_inter_session.sample(rng);
                        const e = Event{ 
                            .time = t_clock + offline_duration, 
                            .type = .{ .session = .start }, 
                            .user_id = current_uid, 
                            .id = metrics.processed_events + 1,
                            .session_gen = graph.users.items(.session_gen)[current_uid],
                        }; 
                        try queue.add(gpa, e);
                        metrics.generated_events += 1;

                        // post non seen when session finished will get nuked
                        graph.timelines[current_uid].clearRetainingCapacity();
                    }
                }
                metrics.processed_events += 1; // both .end and .start do not skip the loop, so its okay to put it here:
            },
            .action => |act| {
                const is_event_stale: bool = current_event.session_gen != graph.users.items(.session_gen)[current_uid];
                const is_user_online: bool = graph.users.items(.is_online)[current_uid];
                if (is_event_stale or !is_user_online) {
                    metrics.dropped_events += 1;
                    continue;
                }
                const has_post_arrived = if (graph.timelines[current_uid].peek()) |post| post.time <= t_clock else false;

                if (has_post_arrived) {
                    // now it's safe to pop it and use it
                    const current_post = graph.timelines[current_uid].remove();
                    const post_id: Index = current_post.post_id;
                    
                    // user CANNOT see previous posts. Shouldn't happen here anyway. this is a _safeguard_
                    if (graph.user_seen_post.isSet(current_uid, post_id)) {
                        const next_action = try CreateRandomAction(
                            rng,
                            simconf,
                            t_clock,
                            current_uid, 
                            graph.users.items(.session_gen)[current_uid], 
                            metrics.generated_events, 
                        );
                        try queue.add(gpa, next_action);
                        metrics.generated_events += 1;
                        continue; 
                    }
 
                    if (simconf.trace_to_file) { 
                        const a = TraceAction{ .time = t_clock, .type = act, .user_id = current_uid, .post_id = post_id, .event_id = metrics.processed_events, .gen_id = gen_id };
                        try writeToTrace(TraceAction, action_trace, a);
                    }
                
                    graph.user_seen_post.set(current_uid, post_id);
                    metrics.impressions += 1;
           
                    switch (act) {
                        .repost => {
                            try propagatePost(gpa, rng, graph, simconf, t_clock, current_uid, post_id);
                            metrics.reposts += 1;
                        },
                        .like => metrics.likes += 1,
                        .ignore => metrics.ignored += 1,
                    }
                    metrics.processed_events += 1;

                    const event = try CreateRandomAction(
                        rng,
                        simconf,
                        t_clock,
                        current_uid, 
                        graph.users.items(.session_gen)[current_uid], 
                        metrics.processed_events
                    );
                    try queue.add(gpa, event);
                    metrics.generated_events += 1;
   
                } else {
                    graph.users.items(.is_online)[current_uid] = false;
        
                    metrics.total_online_time += (t_clock - graph.users.items(.session_start_time)[current_uid]);
                    metrics.empty_timeline_ends += 1;
                    graph.users.items(.session_gen)[current_uid] += 1;
                    
                    if (simconf.trace_to_file) { 
                        const s = TraceSession{ .time = t_clock, .type = .end, .user_id = current_uid, .event_id = metrics.processed_events, .gen_id = gen_id };
                        try writeToTrace(TraceSession, session_trace, s);
                    }
                    
                    const offline_duration = simconf.user_inter_session.sample(rng);
                    const e = Event{ 
                        .time = t_clock + offline_duration, 
                        .type = .{ .session = .start }, 
                        .user_id = current_uid, 
                        .id = metrics.generated_events, 
                        .session_gen = graph.users.items(.session_gen)[current_uid] 
                    }; 
                    try queue.add(gpa, e);
                    metrics.generated_events += 1;
                    // no need to nuke the timeline, it's already empty
                }
            }
        }
    } 
   
    try action_trace.flush();
    try session_trace.flush();
    try create_trace.flush();

    var total_backlog: usize = 0;
    for (graph.timelines) |*timeline| {
        const v = timeline.items.len;
        total_backlog += v;
    }
    
    const mean: f64 = @as(f64, @floatFromInt(total_backlog)) / @as(f64, @floatFromInt(graph.users.len));

    var sum_sq_diff: f64 = 0.0;
    for (graph.timelines) |*timeline| {
        const v: f64 = @floatFromInt(timeline.items.len);
        const diff = v - mean;
        sum_sq_diff += diff * diff;
    }

    const backlog_variance = sum_sq_diff / @as(f64, @floatFromInt(graph.users.len - 1));
    const std_dev = std.math.sqrt(backlog_variance);

    const margin_error = 1.96 * (std_dev / std.math.sqrt(@as(f64, @floatFromInt(graph.users.len))));
    const interactions = metrics.likes + metrics.reposts;

    const result = SimResults {
        .processed_events = metrics.processed_events,
        .duration = t_clock,
        .total_likes = metrics.likes,
        .total_reposts = metrics.reposts,
        .total_interactions = interactions,
        .total_ignored = metrics.ignored,
        .total_impressions = metrics.impressions,
        .avg_impressions_per_user = @as(f64, @floatFromInt(metrics.impressions)) / @as(f64, @floatFromInt(graph.users.len)),
        .engagement_rate = @as(f64, @floatFromInt(interactions)) / @as(f64, @floatFromInt(metrics.impressions)),
        .avg_backlog = mean,
        .variance_backlog = backlog_variance,
        .ci_backlog = margin_error,
        .total_sessions = metrics.total_sessions,
        .avg_session_length = metrics.total_online_time / @as(f64, @floatFromInt(metrics.total_sessions)),
        .avg_post_per_session = @as(f64, @floatFromInt(metrics.impressions)) / @as(f64, @floatFromInt(metrics.total_sessions)),
        .timeline_drain_ratio = @as(f64, @floatFromInt(metrics.empty_timeline_ends)) / @as(f64, @floatFromInt(metrics.total_sessions)),
        .posts_at_warmup = @as(f64, @floatFromInt(metrics.post_count)) / @as(f64, @floatFromInt(graph.user_seen_post.len)),
    };
    
    return result;
}


fn writeToTrace(comptime T: type, writer: *Io.Writer, event: T) !void {
    switch(T) {
        TraceAction, TraceSession, TraceCreate => {},
        else => @compileError("Unsupported trace type passed"),
    }

    try std.json.Stringify.value(event, .{}, writer);
    try writer.writeAll("\n");
}
