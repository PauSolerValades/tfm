const std = @import("std");
const argz = @import("eazy_args");

const json = std.json;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Random = std.Random;
const eql = std.mem.eql;
const Io = std.Io;

const structs = @import("config.zig");
const simulation = @import("simulation.zig");
const data = @import("data_loading.zig");

const v1 = simulation.v1;

const Distribution = structs.Distribution;
const SimConfig = structs.SimConfig;

const User = simulation.User;
const Post = simulation.Post;
const TimelineEvent = simulation.TimelineEvent;

const SimData = data.SimData;

const Arg = argz.Argument;
const ParseErrors = argz.ParseErrors;

const def = .{
    .name = "v1",
    .description = "BSKY sim v1",
    .required = .{
        Arg([]const u8, "config", "Configuration file for the simulation"),
        Arg([]const u8, "data", "Data file containing the network definition"),
    },
};


pub fn main(init: std.process.Init) !void {
    
    var buffer: [1024]u8 = undefined;
    var stdout_writer = Io.File.stdout().writer(init.io, &buffer);
    const stdout = &stdout_writer.interface;

    var bufferr: [1024]u8 = undefined;
    var stderr_writer = Io.File.stderr().writer(init.io, &bufferr);
    const stderr = &stderr_writer.interface;

    const arena = init.arena.allocator();
    const cwd = Io.Dir.cwd();

    var iter = init.minimal.args.iterate(); 
    const args = argz.parseArgsPosix(def, &iter, stdout, stderr) catch |err| {
        switch (err) {
            ParseErrors.HelpShown => try stdout.flush(),
            else => try stderr.flush(),
        }
        std.process.exit(0);
    };   
         
    const parsed_config = data.loadJson(arena, init.io, args.config, SimConfig) catch |err| {
        try stderr.print("Error parsing the JSON: {any}", .{err});
        try stderr.flush();
        std.process.exit(0);
    };
    defer parsed_config.deinit();
    
    const config = parsed_config.value;

    const startTimeLoadData = Io.Timestamp.now(init.io, .real);
    const loaded_data = data.loadJson(arena, init.io, args.data, SimData) catch |err| {
        try stderr.print("Error parsing data JSON: {any}", .{err});
        try stderr.flush();
        std.process.exit(0);
    };
    defer loaded_data.deinit(); // this will free the json object and data
    const elapsedTimeLoadData = startTimeLoadData.untilNow(init.io, .real);
    
    try stdout.print("Time Elapsed Loading Data: {d} ms\n", .{ elapsedTimeLoadData.toMilliseconds()});
    try stdout.flush();

    const startTimeWireData = Io.Timestamp.now(init.io, .real);
    const result = try data.wireSimulation(arena, loaded_data.value); // this is an anonymous struct, which will make easy to free the data
    defer {
        
        for (result.users) |*user| {
            user.seen_posts_ids.deinit(arena);
            user.timeline.deinit(arena);
            arena.free(user.following);
            arena.free(user.followers);
            arena.free(user.posts);
        }
        arena.free(result.users);
        arena.free(result.posts);
    }
    const elapsedTimeWireData = startTimeWireData.untilNow(init.io, .real);
    try stdout.print("Time Elapsed Wiring Data: {d} ms\n", .{ elapsedTimeWireData.toMilliseconds()});
    try stdout.flush();

    const users = result.users;
    // const posts = result.posts;
    // as we use an arena, there is no need to specifically free both users and posts.
    
    const seed = if (config.seed) |s| s else blk: {
        var os_seed: u64 = undefined;
        init.io.random(std.mem.asBytes(&os_seed));
        break :blk os_seed;
    };

    var prng = Random.DefaultPrng.init(seed);
    const rng = prng.random();

    try stdout.print("Loaded configuration from {s}\n", .{args.config});
    try stdout.print("{f}\n", .{config});
    try stdout.flush();

    try stdout.writeAll("Running the simulation once\n");
    try stdout.flush();
        
    // create the results folder
    // cwd.access(init.io, "results", .{}) catch |err| switch (err) {
    //     error.FileNotFound => try cwd.createDir(init.io, "results", .{ .mode = Oo755} ),
    //     else => return err,
    // };
   
    // const timestamp = Io.Clock.real.now(init.io);
    // buffers to hold the formatted file paths to avoid dynamic memory
    // var trace_path_buffer: [256]u8 = undefined;
    // const traca_path = try std.fmt.bufPrint(&traca_path_buffer, "traca_{d}.txt", .{timestamp});

    const trace_writer = blk: { 
        if (config.trace_to_file) {
            const trace_path = "results/trace.txt"; 
            var trace_buffer: [64 * 1024]u8 = undefined;
            const trace_file = try cwd.createFile(init.io, trace_path, .{ .read = false });
            var trace_file_writer = trace_file.writer(init.io, &trace_buffer);
            break :blk &trace_file_writer.interface;
        } else {
            var discard_writer = std.Io.Writer.Discarding.init(&.{});
            break :blk &discard_writer.writer;
        }
    };

    const startTime = Io.Timestamp.now(init.io, .real);
    const results = try simulation.v1(arena, rng, config, users, trace_writer);
    const elapsedTime = startTime.untilNow(init.io, .real);
   
    try stdout.print("{f}\n", .{results});
    try stdout.print("Time Elapsed: {d} ms\n", .{ elapsedTime.toMilliseconds()});
    try stdout.flush();

}
