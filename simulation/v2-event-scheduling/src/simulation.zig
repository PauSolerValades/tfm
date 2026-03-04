const std = @import("std");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Random = std.Random;
const Io = std.Io;
const Order = std.math.Order;

const Heap = @import("heap").Heap;
const dist = @import("distribution");

const Unif = dist.Uniform(Precision);

const config = @import("config.zig");
const entities = @import("entities.zig");

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

    var is_user_online: []bool = try gpa.alloc(bool, users.len); // true: is online 
    defer gpa.free(is_user_online);

    const unif: Unif = .init(0, 1);
    
    // add a first event per every user
    for (users, 0..) |*user, i| {
        const event = blk: {
            const r = unif.sample(rng); 
            if (r < simconf.init_vacation_ratio) {
                // this user is going in vacation. We schedule a wake up and we set them as inactive
                is_user_online[i] = false;
                const wake_up_time = simconf.user_inter_session.sample(rng);
                break :blk Event{ .time = wake_up_time, .type = .go_online, .user_ptr = user, .id = processed_events }; 
            } else {
                // No vacation, start_time = t_clock = 0
                is_user_online[i] = true;
                break :blk try CreateRandomEvent(user, processed_events, 0, simconf, rng);
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
       
        // pop seen post from the user associated with the event
        const poped_post: ?TimelineEvent = users[current_user_id].timeline.removeOrNull();
        
        // if a user has no remaing posts in the timeline (eg simulation is very long it could run out of posts)
        // we CANT stop generating actions, due to potential reply, repor or quotes that could fill the timeline again
        if (poped_post) |current_post| { 
            // add the post reference to the historic of the current user
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
                            const propagation_delay = simconf.propagation_delay.sample(rng);
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
            .reply => {
                // this needs that posts be generated as replies to another posts...
                // so i need threads to implement this.
                // search which user post does the post replied belong
                // check if owner_replied_post_id is online
                //  true: chance to look at the reply. 
                //      if yes, add to Queue an event with t = now with a random action.
                //  false: chance to make the user back online.
                //      true: search for the Event on the Heap which makes the user back online an delete it
                //          add a start_session, with a session duration sampled.
                //          add to users timeline this post.
                //          generate an action over this post
            },
            .like => interactions += 1,
            .nothing => ignored += 1,
            .start_session => is_user_online[current_user_id] = true, // we will generate an event after the switch for this user
            .end_session => {
                // schedule users wake up time
                is_user_online[current_user_id] = false;
                const offline_duration = simconf.user_inter_session.sample(rng);
                const event = Event{ .time = t_clock + offline_duration, .type = .go_online, .user_ptr = current_user_ptr, .id = processed_events }; 
                try queue.add(gpa, event);
                continue; // skip this iteration, you just generated an event for this user
            },

        }
        
        
        // generate another event
        const event = try CreateRandomEvent(current_user_id, processed_events, t_clock, simconf, rng);

        try queue.add(gpa, event);
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


