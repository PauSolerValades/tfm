const std = @import("std");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Random = std.Random;
const Io = std.Io;
const Order = std.math.Order;

const Heap = @import("heap").Heap;

const config = @import("config.zig");
const entities = @import("entities.zig");

const Distribution = config.Distribution;
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
const Graph = entities.Graph;

fn CreateRandomEvent(user_id: Index, event_id: u64, t_clock: f64, simconf: SimConfig, rng: Random) !Event {
    const float_index: Precision = try simconf.user_policy.sample(rng);
    const index: usize = @as(usize, @intFromFloat(float_index));
    const action: Action = @enumFromInt(index);
    const event_time = try simconf.user_inter_action.sample(rng);
    const interaction_delay = try simconf.interaction_delay.sample(rng);
    const event = Event{ 
        .time = t_clock + event_time + interaction_delay, 
        .type = action, 
        .user_id = user_id, 
        .id = event_id, 
    };
    
    return event;
}

pub fn v1(gpa: Allocator, rng: Random, simconf: SimConfig, data: Graph, trace: *Io.Writer) !SimResults {
    
    const users: []User = data.users;
    const posts: []Post = data.posts;

    const EventQueue: type = Heap(Event, void, entities.compareEvent);

    var processed_events: u64 = 0;
    var t_clock: f64 = 0.0;
    
    var impressions: u64 = 0;
    var interactions: u64 = 0;
    var ignored: u64 = 0;
   
    var starting_events = try gpa.alloc(Event, users.len);
    //defer gpa.free(starting_events); <- NO!! fromOwnedSlice takes ownership of this

    // add a first event per every user
    for (0..users.len) |i| { // users are in odrder, that i is the user id
        const event = try CreateRandomEvent(@intCast(i), processed_events, 0, simconf, rng);
        starting_events[i] = event;
        processed_events += 1;
    }
    
    var queue = EventQueue.fromOwnedSlice(starting_events, {});
    defer queue.deinit(gpa);
    
    while (t_clock <= simconf.horizon and queue.items.len > 0) : (processed_events += 1) {
        const current_event = queue.remove();
        t_clock = current_event.time;
        
        //const current_user_ptr = current_event.user_ptr;
        const current_user_id: Index = current_event.user_id; 
        // generate another event
        const event = try CreateRandomEvent(current_user_id, processed_events, t_clock, simconf, rng);

        try queue.add(gpa, event);
        
        // pop seen post from the user associated with the event
        const poped_post: ?TimelineEvent = users[current_user_id].timeline.removeOrNull();
        
        // if a user has no remaing posts in the timeline (eg simulation is very long it could run out of posts)
        // we CANT stop generating actions, due to potential reply, repor or quotes that could fill the timeline again
        if (poped_post) |current_post| { 
            // add the post reference to the historic of the current user
            // try current_user_ptr.*.historic.append(gpa, current_post.post);
            const post_id: Index = current_post.post_id;
            try users[current_user_id].seen_posts_ids.append(gpa, post_id);
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
        } 

        
        switch (current_event.type) {
            .repost => {
                // if the user had no posts to see, there is nothing to update
                if (poped_post) |current_post| {

                    for (users[current_user_id].followers) |follower| { // followers is a Slice of Index
                        //check that user_ptr has not seen this post already...
                        const post_id: Index = current_post.post_id;
                        if (std.mem.indexOfScalar(@TypeOf(post_id), users[follower].seen_posts_ids.items, post_id) == null and 
                            posts[post_id].author != users[follower].id) {
                            const propagation_delay = try simconf.propagation_delay.sample(rng);
                            const propagated_event = TimelineEvent{
                                .time = t_clock + propagation_delay, 
                                .post_id = current_post.post_id, //this is an ID now
                            };

                            try users[follower].timeline.add(gpa, propagated_event);
                        } // else the post was in the seen_posts to do not add it
                    }

                    interactions += 1;
                }
            },
//            .reply, .quote => {}, // do nothing. It never enters here due to never being generated
            .like => interactions += 1,
            .nothing => ignored += 1,
        } 
    }
    
    try trace.flush();
    
    var timeline_backlog: usize = 0;
    for (0..users.len) |id| {
        timeline_backlog += users[id].timeline.items.len;
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


