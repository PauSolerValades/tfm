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

fn CreateRandomEvent(user: *User, event_id: u64, t_clock: f64, simconf: SimConfig, rng: Random) !Event {
    const float_index: Precision = try simconf.user_policy.sample(rng);
    const index: usize = @as(usize, @intFromFloat(float_index));
    const action: Action = @enumFromInt(index);
    const event_time = try simconf.user_inter_action.sample(rng);
    const interaction_delay = try simconf.interaction_delay.sample(rng);
    const event = Event{ 
        .time = t_clock + event_time + interaction_delay, 
        .type = action, 
        .user_ptr = user, 
        .id = event_id, 
    };
    
    return event;
}

pub fn v1(gpa: Allocator, rng: Random, simconf: SimConfig, users: []User, trace: *Io.Writer) !SimResults {
    
    const EventQueue: type = Heap(Event, void, entities.compareEvent);

    var processed_events: u64 = 0;
    var t_clock: f64 = 0.0;
    
    var impressions: u64 = 0;
    var interactions: u64 = 0;
    var ignored: u64 = 0;
   
    var starting_events = try gpa.alloc(Event, users.len);
    //defer gpa.free(starting_events);

    // add a first event per every user
    for (users, 0..) |*user, i| {
        const event = try CreateRandomEvent(user, processed_events, 0, simconf, rng);
        starting_events[i] = event;
        processed_events += 1;
    }
    
    var queue = EventQueue.fromOwnedSlice(starting_events, {});
    defer queue.deinit(gpa);
    
    while (t_clock <= simconf.horizon and queue.items.len > 0) : (processed_events += 1) {
        const current_event = queue.remove();
        t_clock = current_event.time;
        
        const current_user_ptr = current_event.user_ptr;
       
        // generate another event
        const event = try CreateRandomEvent(current_user_ptr, processed_events, t_clock, simconf, rng);

        try queue.add(gpa, event);
        
        // pop seen post from the user associated with the event
        const poped_post: ?TimelineEvent = current_user_ptr.*.timeline.removeOrNull();
        
        // if a user has no remaing posts in the timeline (eg simulation is very long it could run out of posts)
        // we CANT stop generating actions, due to potential reply, repor or quotes that could fill the timeline again
        if (poped_post) |current_post| {
            // add the post reference to the historic of the current user
            // try current_user_ptr.*.historic.append(gpa, current_post.post);
            try current_user_ptr.*.seen_posts_ids.append(gpa, current_post.post.id);
            impressions += 1;
            
            const trace_event = TracePost{
                .time = t_clock,
                .type = current_event.type,
                .event_id = processed_events,
                .user_id = current_user_ptr.id,
                .post_id = current_post.post.*.id,
            };
            // this might be very slow, it could be better to use the lower json api
            try std.json.Stringify.value(trace_event, .{}, trace);
            try trace.writeAll("\n");
        } 

        
        switch (current_event.type) {
            .repost => {
                // if the user had no posts to see, there is nothing to update
                if (poped_post) |current_post| {

                    for (current_user_ptr.*.followers) |follower_ptr| {
                        //check that user_ptr has not seen this post already...
                        const target_id = current_post.post.id; 
                        if (std.mem.indexOfScalar(@TypeOf(target_id), follower_ptr.seen_posts_ids.items, target_id) == null and 
                            current_post.post.author != follower_ptr.*.id) {
                            const propagation_delay = try simconf.propagation_delay.sample(rng);
                            const propagated_event = TimelineEvent{
                                .time = t_clock + propagation_delay, 
                                .post = current_post.post,
                            };

                            try follower_ptr.*.timeline.add(gpa, propagated_event);
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
    for (users) |*user| {
        timeline_backlog += user.*.timeline.items.len;
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


