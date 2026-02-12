const std = @import("std");

const json = std.json;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Random = std.Random;
const eql = std.mem.eql;
const Timer = std.time.Timer;
const Io = std.Io;

const heap = @import("structheap.zig");
const structs = @import("config.zig");

const v1 = @import("simulation.zig").v1;

const Distribution = structs.Distribution;
const SimResults = structs.SimResults;
const SimConfig = structs.SimConfig;
const Stats = structs.Stats;
const User = @import("simulation.zig").User;

pub const AppConfig = struct {
    iterations: usize,
    sim_config: SimConfig,
    seed: ?u64,
};

pub fn loadConfig(allocator: std.mem.Allocator, file_path: []const u8) !json.Parsed(AppConfig) {
    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const max_size = 1024 * 1024; // 1MB max config file
    const file_content = try file.readToEndAlloc(allocator, max_size);
    defer allocator.free(file_content);

    // We use .ignore_unknown_fields = true so comments or extra metadata in JSON don't crash it
    const options = std.json.ParseOptions{ .ignore_unknown_fields = true };
    
    // parsed_result holds the data AND the arena allocator used for strings/slices in the JSON
    var parsed_result = try std.json.parseFromSlice(AppConfig, allocator, file_content, options);
    
    return parsed_result;
}

pub fn loadData(allocator: Allocator, file_path: []const u8) !ArrayList(json.Parsed(User)) {
    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const max_size = 1024 * 1024; // 1MB max config file
    const file_content = try file.readToEndAlloc(allocator, max_size);
    defer allocator.free(file_content);

    const options = std.json.ParseOptions{ .ignore_unknown_fields = true };

    const parsed_result = try std.json.parseFromSlice([]User, allocator, file_content, options);
     
    return parsed_result;
}

const HELP =
    \\Usage: this is the version 1 simulation :D <config_filepath>
;

const INFO = "Yet again, this is the version 1 of the simulation";

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const gpa = arena.allocator(); // set up the stdout buffer

    var buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&buffer);
    const stdout = &stdout_writer.interface;

    var bufferr: [1024]u8 = undefined;
    var stderr_writer = std.fs.File.stderr().writer(&bufferr);
    const stderr = &stderr_writer.interface;

    const args = try std.process.argsAlloc(gpa);
    defer std.process.argsFree(gpa, args);

    if (args.len <= 1) {
        try stdout.print("Usage: <config_filepath> --iterations/-i <int>\n", .{});
        try stdout.flush();
        std.process.exit(0);
    }

    if (eql(u8, args[1], "-h") or
        eql(u8, args[1], "--help") or
        eql(u8, args[1], "help"))
    {
        try stdout.print("{s}\n", .{HELP});
        try stdout.flush();
        std.process.exit(0);
    }

    if (eql(u8, args[1], "-i") or
        eql(u8, args[1], "--info") or
        eql(u8, args[1], "info"))
    {
        try stdout.print("{s}\n", .{INFO});
        try stdout.flush();
        std.process.exit(0);
    }
    
    const config_path = args[1];
    const override_iterations: ?u64 = if (args.len == 4 and (std.mem.eql(u8, args[2], "--iterations") or (std.mem.eql(u8, args[2], "-i")))) try std.fmt.parseInt(u64, args[3], 10) else null; 
    
    // We use a separate parsing_arena because the JSON parser allocates internal
    // slices (like the 'hypo' array) that must live as long as the config exists.
    var parsing_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer parsing_arena.deinit();
    const parsing_allocator = parsing_arena.allocator();

    const loaded_data = loadConfig(parsing_allocator, config_path) catch |err| {
        try stderr.print("Error parsing the JSON: {any}", .{err});
        try stderr.flush();
        std.process.exit(0);
    };
    defer loaded_data.deinit();

    const app_config = loaded_data.value;
    const config = app_config.sim_config;
    const B = if (override_iterations) |iterations| iterations else app_config.iterations;

    const seed = if (app_config.seed) |s| s else blk: {
        var os_seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&os_seed));
        break :blk os_seed;
    };

    var prng = Random.DefaultPrng.init(seed);
    const rng = prng.random();

    try stdout.print("Loaded configuration from {s}\n", .{config_path});
    try stdout.print("Iterations (B): {d}\n", .{B});
    try stdout.print("{f}\n", .{config});
    try stdout.flush();

    if (B == 1) {
        try stdout.writeAll("Running the simulation once\n");
        try stdout.flush();
         
        // create the results folder
        std.fs.cwd().access("results", .{}) catch |err| switch (err) {
            error.FileNotFound => try std.fs.cwd().makeDir("results"),
            else => return err,
        };

        const timestamp = std.time.timestamp();
        
        // buffers to hold the formatted file paths to avoid dynamic memory
        var traca_path_buffer: [256]u8 = undefined;
        var user_path_buffer: [256]u8 = undefined;

        const traca_path = try std.fmt.bufPrint(&traca_path_buffer, "results/traca_{d}.txt", .{timestamp});
        const user_path = try std.fmt.bufPrint(&user_path_buffer, "results/usertimes_{d}.csv", .{timestamp});
        
        var traca_buffer: [64 * 1024]u8 = undefined;
        const traca_file = try std.fs.cwd().createFile(traca_path, .{ .read = false });
        var traca_writer = traca_file.writer(&traca_buffer);
        const twriter = &traca_writer.interface;

        // add the system config in the traca file
        try twriter.print("{f}\n", .{config}); 

        var user_buffer: [64 * 1024]u8 = undefined;
        const user_file = try std.fs.cwd().createFile(user_path, .{ .read = false });
        var user_writer = user_file.writer(&user_buffer);
        const uwriter = &user_writer.interface;
        

        var timer = try Timer.start();
        const results = try eventSchedulingBus(gpa, rng, config, twriter, uwriter);
        const end = timer.read();

        const seconds = @as(f64, @floatFromInt(end)) / 1_000_000_000.0;

        try stdout.print("{f}\n", .{results});
        try stdout.print("Time Elapsed: {d:.4} seconds\n", .{seconds});
        try stdout.flush();
    
    } else {

        try stdout.print("Running the simulation {d} times\n", .{B});
        try stdout.flush();

        const L_vals = try gpa.alloc(f64, B);
        defer gpa.free(L_vals);

        const Lq_vals = try gpa.alloc(f64, B);
        defer gpa.free(L_vals);

        const t_vals = try gpa.alloc(f64, B);
        defer gpa.free(t_vals);

        const Wq_vals = try gpa.alloc(f64, B);
        defer gpa.free(Wq_vals);

        const Ws_vals = try gpa.alloc(f64, B);
        defer gpa.free(Ws_vals);

        const W_vals = try gpa.alloc(f64, B);
        defer gpa.free(W_vals);

        var global_timer = try Timer.start();

        for (0..B) |i| {
            var timer = try Timer.start();

            const results = try eventSchedulingBus(gpa, rng, config, null, null);

            const end = timer.read();
            const seconds = @as(f64, @floatFromInt(end)) / 1_000_000_000.0;

            L_vals[i] = results.average_clients;
            Lq_vals[i] = results.average_queue_clients;
            Wq_vals[i] = results.average_queue_time;
            Ws_vals[i] = results.average_service_time;
            W_vals[i] = results.average_total_time;
            t_vals[i] = seconds;
            
            const mod = @divTrunc(B, 10);
            if ((i + 1) % mod == 0) {
                const checkpoint = global_timer.read();
                const checkpoint_seconds = @as(f64, @floatFromInt(checkpoint)) / 1_000_000_000.0;
                try stdout.print("Done {d}/{d} iterations. Time Elapsed {d:.4}s.\n", .{ i + 1, B, checkpoint_seconds });
                try stdout.flush();
            }
        }

        const total_time = @as(f64, @floatFromInt(global_timer.read())) / 1_000_000_000.0;
        const l_stats: Stats = Stats.calculateFromData(L_vals);
        const lq_stats: Stats = Stats.calculateFromData(Lq_vals);
        const Wq_stats: Stats = Stats.calculateFromData(Wq_vals);
        const Ws_stats: Stats = Stats.calculateFromData(Ws_vals);
        const W_stats: Stats = Stats.calculateFromData(W_vals);
        const t_stats: Stats = Stats.calculateFromData(t_vals);

        try stdout.writeAll("\n+----------------------+\n");
        try stdout.print("| BATCH RESULTS (B={d}) |\n", .{B});
        try stdout.writeAll("+----------------------+\n");
        try stdout.print("{s: <24}: {d:.4} +/- {d:.6} (95% CI)\n", .{ "Avg Duration (s)", t_stats.mean, t_stats.ci });
        try stdout.print("{s: <24}: {d:.4} +/- {d:.6} (95% CI)\n", .{ "Avg Clients (L)", l_stats.mean, l_stats.ci });
        try stdout.print("{s: <24}: {d:.4} +/- {d:.6} (95% CI)\n", .{ "Avg Clients Queue (L_q)", lq_stats.mean, lq_stats.ci });
        try stdout.print("{s: <24}: {d:.4} +/- {d:.6} (95% CI)\n", .{ "Avg Queue Time (W_q)", Wq_stats.mean, Wq_stats.ci });
        try stdout.print("{s: <24}: {d:.4} +/- {d:.6} (95% CI)\n", .{ "Avg Service Time (W_s)", Ws_stats.mean, Ws_stats.ci });
        try stdout.print("{s: <24}: {d:.4} +/- {d:.6} (95% CI)\n", .{ "Avg Total Time (W)", W_stats.mean, W_stats.ci });
        try stdout.print("Total Time Elapsed: {d:.4}s\n", .{total_time});
        try stdout.flush();
    }
}
