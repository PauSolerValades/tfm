const std = @import("std");
const argz = @import("eazy_args");

const json = std.json;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Random = std.Random;
const eql = std.mem.eql;
const Io = std.Io;

const heap = @import("structheap.zig");
const structs = @import("config.zig");
const simulation = @import("simulation.zig");

const v1 = simulation.v1;

const Distribution = structs.Distribution;
const SimResults = structs.SimResults;
const SimConfig = structs.SimConfig;
const User = simulation.User;

pub const AppConfig = struct {
    iterations: usize,
    sim_config: SimConfig,
    seed: ?u64,
};

pub fn loadConfig(allocator: Allocator, io: Io, path: []const u8) !json.Parsed(AppConfig) {
    const content = try std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .unlimited);
    defer allocator.free(content);

    // We use .ignore_unknown_fields = true so comments or extra metadata in JSON don't crash it
    const options = std.json.ParseOptions{ .ignore_unknown_fields = true };
    
    // parsed_result holds the data AND the arena allocator used for strings/slices in the JSON
    const parsed_result = try std.json.parseFromSlice(AppConfig, allocator, content, options);
    
    return parsed_result;
}

// pub fn loadData(allocator: Allocator, io: Io, path: []const u8) !ArrayList(json.Parsed(User)) {
//     const content = try std.fs.cwd().readFileAlloc(allocator, path, .unlimited);
//     defer allocator.free(content);
//
//     const options = std.json.ParseOptions{ .ignore_unknown_fields = true };
//
//     const parsed_result = try std.json.parseFromSlice([]User, allocator, content, options);
//
//     return parsed_result;
// }

const Arg = argz.Argument;
const ParseErrors = argz.ParseErrors;

const def = .{
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
    
    const loaded_config = loadConfig(arena, init.io, args.config) catch |err| {
        try stderr.print("Error parsing the JSON: {any}", .{err});
        try stderr.flush();
        std.process.exit(0);
    };
    defer loaded_config.deinit();

    const app_config = loaded_config.value;
    const config = app_config.sim_config;

    // const loaded_data = loadData(arena, init.io, args.data) catch |err| {
    //     try stderr.print("Error parsing data JSON: {any}", .{err});
    //     try stderr.flush();
    //     std.process.exit(0);
    // };
    // _ = loaded_data;

    const seed = if (app_config.seed) |s| s else blk: {
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
        
    // // create the results folder
    // cwd.access(init.io, "results", .{}) catch |err| switch (err) {
    //     error.FileNotFound => try cwd.createDir(init.io, "results", .{ .mode = Oo755} ),
    //     else => return err,
    // };
   
    // this is basically witchcraft, found here:
    // https://codeberg.org/ehrktia/zig-epoch/src/branch/main/src/root.zig
    const real_clock = Io.Clock.real;
    const timestamp = Io.Clock.now(real_clock, init.io);
    
    // buffers to hold the formatted file paths to avoid dynamic memory
    var traca_path_buffer: [256]u8 = undefined;

    const traca_path = try std.fmt.bufPrint(&traca_path_buffer, "traca_{d}.txt", .{timestamp});
    
    var traca_buffer: [64 * 1024]u8 = undefined;
    const traca_file = try cwd.createFile(init.io, traca_path, .{ .read = false });
    var traca_writer = traca_file.writer(init.io, &traca_buffer);
    const twriter = &traca_writer.interface;

    // add the system config in the traca file
    try twriter.print("{f}\n", .{config}); 


    _ = simulation.v1(arena, rng,  config, twriter);


    // try stdout.print("{f}\n", .{results});
    // try stdout.print("Time Elapsed: {d:.4} seconds\n", .{1});
    // try stdout.flush();
}
