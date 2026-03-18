const std = @import("std");
const json = std.json;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Random = std.Random;
const eql = std.mem.eql;
const Io = std.Io;


const argz = @import("eazy_args"); 
const is_v1 = std.mem.eql(u8, "v1", @import("build").build);

const structs = @import("config.zig");

const simulation = if (is_v1) @import("sim_chron.zig") else @import("sim_rev_chron.zig");

const loader = @import("json_loading.zig");
const gn = @import("graph_network.zig");

const Distribution = structs.Distribution;
const SimConfig = structs.SimConfig;
const SimResults = structs.SimResults;

const User = simulation.User;
const Post = simulation.Post;
const TimelineEvent = simulation.TimelineEvent;

const Arg = argz.Argument;
const ParseErrors = argz.ParseErrors;
const PostGeneration = enum {
    all,
    one,
};

const def = .{
    .name = "v1",
    .description = "BSKY sim",
    .required = .{
        Arg(PostGeneration, "postinit", "Post initialization strategy"),
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

    // const gpa = init.gpa;
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

    // const parsed_config = try loader.loadJson(arena, init.io, args.config, SimConfig);
    const parsed_config = loader.loadJson(arena, init.io, args.config, SimConfig) catch |err| {
        try stderr.print("Error parsing config JSON file: {any}", .{err});
        try stderr.flush();
        std.process.exit(0);
    };
    defer parsed_config.deinit();
    const config = parsed_config.value;
    _ = config.isValid(); // not used for now

    const startTimeLoadData = Io.Timestamp.now(init.io, .real);
    // const loaded_data = try loader.loadJson(arena, init.io, args.data, loader.NetworkJson);
    const loaded_data = loader.loadJson(arena, init.io, args.data, loader.NetworkJson) catch |err| {
        try stderr.print("Error parsing data JSON: {any}", .{err});
        try stderr.flush();
        std.process.exit(0);
    };
    defer loaded_data.deinit(); // this will free the json object and data
    const elapsedTimeLoadData = startTimeLoadData.untilNow(init.io, .real);
    
    try stdout.print("Time Elapsed Loading Data: {d} ms\n", .{ elapsedTimeLoadData.toMilliseconds()});
    try stdout.flush();

    const startTimeWireData = Io.Timestamp.now(init.io, .real);
    var graph: gn.StaticNetworkGraph = try .create(arena, loaded_data.value);
    const elapsedTimeWireData = startTimeWireData.untilNow(init.io, .real);
    
    try stdout.print("Time Elapsed Wiring Data: {d} ms\n", .{ elapsedTimeWireData.toMilliseconds()});
    try stdout.flush();
    
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
    
    const session_writer = blk: { 
        if (config.trace_to_file) {
            const trace_path = "results/session_trace.txt"; 
            var trace_buffer: [64 * 1024]u8 = undefined;
            const trace_file = try cwd.createFile(init.io, trace_path, .{ .read = false });
            var trace_file_writer = trace_file.writer(init.io, &trace_buffer);
            break :blk &trace_file_writer.interface;
        } else {
            var discard_writer = std.Io.Writer.Discarding.init(&.{});
            break :blk &discard_writer.writer;
        }
    };

    const SimulateFnChron = *const fn (
        Allocator, 
        Random, 
        SimConfig, 
        *gn.StaticNetworkGraph, 
        *Io.Writer
    ) anyerror!SimResults;

    const SimulateFnRevChron = *const fn (
        Allocator, 
        Random, 
        SimConfig, 
        *gn.StaticNetworkGraph, 
        *Io.Writer,
        *Io.Writer
    ) anyerror!SimResults;
    
    const SimulateFn = if (is_v1) SimulateFnChron else SimulateFnRevChron;

    const simulate: SimulateFn = if (comptime is_v1)
        switch (args.postinit) {
            // .one => simulation.staticOnePostScheduled,
            .all => simulation.diffusionSimulation,
            else => unreachable,
        }
    else
        switch (args.postinit) {
            .one => simulation.staticOnePostScheduled, // (Assuming this matches the 6-arg signature!)
            .all => simulation.stagedSimulation,
        };
    // var simulate: *const fn (Allocator, Random, SimConfig, *gn.StaticNetworkGraph, *Io.Writer) anyerror!SimResults;
        
    const startTime = Io.Timestamp.now(init.io, .real);

    const results = if (is_v1)
        try simulate(arena, rng, config, &graph, trace_writer)
    else
        try simulate(arena, rng, config, &graph, trace_writer, session_writer);

    const elapsedTime = startTime.untilNow(init.io, .real);   

    try stdout.print("{f}\n", .{results});
    try stdout.print("Time Elapsed: {d} ms\n", .{ elapsedTime.toMilliseconds()});
    try stdout.flush();

}
