const std = @import("std");
const Random = std.Random;
const ArrayList = std.ArrayList;
const Io = std.Io;

const main = @import("main.zig");
const Event = main.Event;
const sampling = @import("rng.zig");

pub const Precision = f32;

/// Okay, aquí estaria la màgia...
/// En essència la unió només conté una de les tres quan s'inicialitza
pub fn Distribution(comptime T: type) type {
    if (@typeInfo(T) != .float) @compileError("A floating point type is required for a distribution");
    if (@typeInfo(T).float.bits < 32) @compileError("Distribution does not support floating point less than 32 bits do to the generalized lacking of RNG generation other than f32 and f64");

    return union(enum) {
        constant: T,
        exponential: T,
        uniform: struct { min: T, max: T},
        hypo: []const T, // directament les esperances
        hyper: struct { probs: []const T, rates: []T }, // probabilitats del branching i els ratis de cada exponencial
        erlang: struct { k: usize, lambda: T }, // shape, scale
        exp_trunc: struct { k: T },
        weighted: []const T,

        pub fn sample(self: Distribution(T), rng: Random) !T {
            switch (self) {
                .constant => |val| return val,
                .exponential => |lambda| return sampling.rexp(T, lambda, rng),
                .uniform => |p| return try sampling.runif(T, p.min, p.max, rng),
                .hypo => |rates| return sampling.rhypo(T, rates, rng),
                .hyper => |p| return sampling.rhyper(T, p.probs, p.rates, rng),
                .erlang => |p| return sampling.rerlang(T, p.k, p.lambda, rng),
                .exp_trunc => |p| return sampling.rtexp(T, p.k, rng),
                .weighted => |p| return sampling.rweighted(T, p, rng),
            }
        }

        // Helper to get integer capacity (e.g. 3.0 -> 3)
        pub fn sampleInt(self: *Distribution(T), rng: Random) !u64 {
            const samp = try self.sample(rng);
            return @as(u64, @intFromFloat(@round(samp)));
        }

        pub fn scaleTime(self: *Distribution(T), factor: T) void {
            switch (self.*) {
                .constant => |*val| val.* *= factor,

                .uniform => |*u| {
                    u.min *= factor;
                    u.max *= factor;
                },

                .exponential => |*lambda| lambda.* /= factor,
                .erlang => |*e| e.lambda /= factor, // k (shape) stays same
                .hypo => |rates| {
                    for (rates) |*r| r.* /= factor;
                },
                .hyper => |rates_probs| {
                    for (rates_probs.rates) |*r| r.* /= factor;
                },
                // la exp_trunc és en realitat una exp amb 2/K, ergo multiplicar directament per factor ho ajusta
                // si factor (QUE HO HAURIA DE SER) és 1/60
                .exp_trunc => |*et| {
                    et.k *= factor; // Max limit is a Time unit, so it scales directly
                },
            }
        }

        pub fn format(
            self: Distribution(T),
            writer: *std.Io.Writer,
        ) !void {
            switch (self) {
                .constant => |val| try writer.print("Const({d:.2})", .{val}),
                .exponential => |lambda| try writer.print("Exp(λ={d:.2})", .{lambda}),
                .uniform => |u| try writer.print("Uni({d:.1}, {d:.1})", .{ u.min, u.max }),
                .hypo => |rates| {
                    try writer.writeAll("Hypo(");
                    const n = rates.len;
                    for (0..n) |i| {
                        if (i != n - 1) try writer.print("λ{d}={d:.1}, ", .{ i, rates[i] }) else try writer.print("λ{d}={d:.1})", .{ i, rates[i] });
                    }
                },
                .hyper => |rates_probs| {
                    try writer.writeAll("Hyper(");
                    const n = rates_probs.rates.len;
                    for (0..n) |i| {
                        if (i != n - 1) try writer.print("λ{d}={d:.1}, p{d}={d:.1}, ", .{ i, rates_probs.rates[i], i, rates_probs.probs[i] }) else try writer.print("λ{d}={d:.1}, p{d}={d:.1})", .{ i, rates_probs.rates[i], i, rates_probs.probs[i] });
                    }
                },
                .erlang => |k_rate| try writer.print("Erl(k={d}, λ={d:.1})", .{ k_rate.k, k_rate.lambda }),
                .exp_trunc => |rate_max| try writer.print("ExpTrunc(λ=2/{d:.1})", .{ rate_max.k }),
                .weighted => |pvec| {
                    try writer.writeAll("Weighted(");
                    for (0..pvec.len - 1) |i| {
                        try writer.print("{d:.2} ", .{pvec[i]});
                    }
                    try writer.print("{d:.2})", .{pvec[pvec.len-1]});
                }
            }
        }
    };
}


pub const SimConfig = struct {
    seed: ?u64,
    user_policy: Distribution(Precision),
    user_inter_action: Distribution(Precision),
    user_inter_session: Distribution(Precision),
    init_vacation_ratio: f64, // which proportion of the users start on vacation
    horizon: f64,

    pub fn format(
        self: SimConfig,
        writer: *std.Io.Writer,
    ) !void {
        try writer.writeAll("\n");
        try writer.writeAll("+--------------------------+\n");
        try writer.print("| SIMULATION CONFIGURATION |\n", .{});
        try writer.writeAll("+--------------------------+\n");
        try writer.print("{s: <24}:  {f}\n", .{ "User policy", self.user_policy});
        try writer.print("{s: <24}:  {f}\n", .{ "Time between actions", self.user_inter_action});
        try writer.writeAll("---------\n");
        try writer.print("{s: <24}:  {d: <23.2}\n", .{ "Horizon (Time)", self.horizon });
    }
};

pub const SimResults = struct {
    duration: f64,
    processed_events: u64,

    total_impressions: u64,      // Every time a post is popped from a timeline
    total_interactions: u64,     // Sum of likes, replies, reposts, quotes
    total_ignored: u64,          // Events where action was .nothing

    avg_impressions_per_user: f64,
    engagement_rate: f64,        // interactions / impressions
    avg_timeline_backlog: f64,   // How many unread posts remain in heaps at horizon
    
    pub fn format(
        self: SimResults,
        writer: *std.Io.Writer,
    ) !void {
        
        try writer.writeAll("\n+---------------------------------+\n");
        try writer.print("| SOCIAL NETWORK SIMULATION STATS |\n", .{});
        try writer.writeAll("+---------------------------------+\n");
        try writer.print("{s: <28}: {d:.4}\n", .{ "Simulation Duration (T)", self.duration });
        try writer.print("{s: <28}: {d}\n", .{ "Total Events Processed", self.processed_events });
        try writer.writeAll("------- Global Post Metrics -------\n");
        try writer.print("{s: <28}: {d}\n", .{ "Total Impressions (Views)", self.total_impressions });
        try writer.print("{s: <28}: {d}\n", .{ "Total Interactions", self.total_interactions });
        try writer.print("{s: <28}: {d}\n", .{ "Total Ignored (.nothing)", self.total_ignored });
        try writer.writeAll("------------- Averages ------------\n");
        try writer.print("{s: <28}: {d:.4}\n", .{ "Avg Impressions / User", self.avg_impressions_per_user });
        try writer.print("{s: <28}: {d:.2}%\n", .{ "Global Engagement Rate", self.engagement_rate * 100.0 });
        try writer.print("{s: <28}: {d:.2}\n", .{ "Avg Unread Backlog / User", self.avg_timeline_backlog });
        try writer.writeAll("+---------------------------------+\n");
    }
};

pub const Stats = struct {
    mean: f64,
    ci: f64,

    pub fn calculateFromData(data: []f64) Stats {
        var sum: f64 = 0.0;
        for (data) |v| sum += v;
        const mean = sum / @as(f64, @floatFromInt(data.len));

        var sum_sq_diff: f64 = 0.0;
        for (data) |v| {
            const diff = v - mean;
            sum_sq_diff += diff * diff;
        }

        const variance = sum_sq_diff / @as(f64, @floatFromInt(data.len - 1));
        const std_dev = std.math.sqrt(variance);

        const margin_error = 1.96 * (std_dev / std.math.sqrt(@as(f64, @floatFromInt(data.len))));

        return Stats{ .mean = mean, .ci = margin_error };
    }
};
