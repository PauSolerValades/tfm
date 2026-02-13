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
    type: Action,    // what will the user do
    id: u64,            // who does the action
};

const User = struct {
    following: ArrayList(*User),  //neighbors
    follower: ArrayList(*User),
    timeline: heap.Heap(*Post),
    posts: ArrayList(*Post),
    historic: ArrayList(*Post) = .empty,
    policy: [5]f32,                        // as many as the number of actions
};

const Post = struct {
    id: u64,
    time: f64,
};

pub fn v1(gpa: Allocator, rng: Random, config: SimConfig, trace: ?*Io.Writer) void {
    _ = rng;
    _ = trace; 
    var hp = heap.Heap(Event).init();
    defer hp.deinit(gpa);

    var processed_events: u64 = 0;
    var t_clock: f64 = 0.0;

    // add a first event per every user
    // create minheap (timeline) per user containing which is the next post the user has to see.
    // and append the first element of the event scheduling algorithm
    
    while (t_clock <= config.horizon and hp.len() > 0) : (processed_events += 1) {
        const next_event = hp.pop().?; // we use ? because we are absolutely sure there will be an element
        t_clock = next_event.time;

        switch (next_event.type) {
            Action.nothing => std.debug.print("Hothing!\n", .{}),
            Action.like => std.debug.print("Hothing!\n", .{}),
            Action.reply => std.debug.print("Update all the followers timelines!\n", .{}),
            Action.repost => std.debug.print("Update all the followers timelines!\n", .{}),
            Action.quote => std.debug.print("Update all the followers timelines!\n", .{}),
        } 
    }

    return;
}


