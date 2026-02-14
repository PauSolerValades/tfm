const std = @import("std");
const Random = std.Random;
const ArrayList = std.ArrayList;
const Io = std.Io;

const main = @import("main.zig");
const Event = main.Event;
const sampling = @import("rng.zig");

/// Okay, aquí estaria la màgia...
/// En essència la unió només conté una de les tres quan s'inicialitza
pub const Distribution = union(enum) {
    constant: f64,
    exponential: f64,
    uniform: struct { min: f64, max: f64 },
    hypo: []f64, // directament les esperances
    hyper: struct { probs: []const f64, rates: []f64 }, // probabilitats del branching i els ratis de cada exponencial
    erlang: struct { k: usize, lambda: f64 }, // shape, scale
    exp_trunc: struct { k: f64 },

    pub fn sample(self: Distribution, rng: Random) !f64 {
        switch (self) {
            .constant => |val| return val,
            .exponential => |lambda| return sampling.rexp(f64, lambda, rng),
            .uniform => |p| return try sampling.runif(f64, p.min, p.max, rng),
            .hypo => |rates| return sampling.rhypo(f64, rates, rng),
            .hyper => |p| return sampling.rhyper(f64, p.probs, p.rates, rng),
            .erlang => |p| return sampling.rerlang(f64, p.k, p.lambda, rng),
            .exp_trunc => |p| return sampling.rtexp(f64, p.k, rng),
        }
    }

    // Helper to get integer capacity (e.g. 3.0 -> 3)
    pub fn sampleInt(self: Distribution, rng: Random) !u64 {
        const samp = try self.sample(rng);
        return @as(u64, @intFromFloat(@round(samp)));
    }

    pub fn scaleTime(self: *Distribution, factor: f64) void {
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
        self: Distribution,
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
        }
    }
};

pub const SimConfig = struct {
    seed: ?u64,
    user_policy: [5]f32,
    user_inter_action: Distribution,
    horizon: f64,

    pub fn format(
        self: SimConfig,
        writer: *std.Io.Writer,
    ) !void {
        try writer.writeAll("\n");
        try writer.writeAll("+--------------------------+\n");
        try writer.print("| SIMULATION CONFIGURATION |\n", .{});
        try writer.writeAll("+--------------------------+\n");
        try writer.writeAll("User policy:\n");
        try writer.print("{s: <24}:  {d}\n", .{ "- Non-Engage", self.user_policy[0]});
        try writer.print("{s: <24}:  {d}\n", .{ "- Like", self.user_policy[1]});
        try writer.print("{s: <24}:  {d}\n", .{ "- Reply", self.user_policy[2]});
        try writer.print("{s: <24}:  {d}\n", .{ "- Repost", self.user_policy[3]});
        try writer.print("{s: <24}:  {d}\n", .{ "- Quote", self.user_policy[4]});
        try writer.print("{s: <24}:  {f}\n", .{ "Time between actions", self.user_inter_action});
        try writer.writeAll("---------\n");
        try writer.print("{s: <24}:  {d: <23.2}\n", .{ "Horizon (Time)", self.horizon });
    }
};

pub const SimResults = struct {
    duration: f64,
    average_clients: f64,
    variance: f64,
    lost_passengers: u64,
    lost_buses: u64,
    processed_events: u64,
    average_queue_clients: f64,
    average_queue_time: f64,
    average_service_time: f64,
    average_total_time: f64,

    pub fn format(self: SimResults, writer: *Io.Writer) !void {
        try writer.writeAll("+-------------------+\n");
        try writer.print("| SIMULATION RESULT |\n", .{});
        try writer.writeAll("+-------------------+\n");
        try writer.print("{s: <24}: {d:.4} \n", .{ "Duration", self.duration });
        try writer.print("{s: <24}: {d} \n", .{ "Events processed", self.processed_events });
        try writer.print("{s: <24}: {d:.4}\n", .{ "Avg Clients (L)", self.average_clients });
        try writer.print("{s: <24}: {d:.4}\n", .{ "Avg Clients Queue (L_q)", self.average_queue_clients });
        try writer.print("{s: <24}: {d:.4}\n", .{ "Avg Queue Time (W_q)", self.average_queue_clients });
        try writer.print("{s: <24}: {d:.4}\n", .{ "Avg Service Time (W_s)", self.average_service_time });
        try writer.print("{s: <24}: {d:.4}\n", .{ "Avg Total Time (W)", self.average_total_time });
        try writer.print("{s: <24}: {d:.4}\n", .{ "Variance (Var)", self.variance });
        try writer.print("{s: <24}: {d}\n", .{ "Lost passengers", self.lost_passengers });
        try writer.print("{s: <24}: {d}\n", .{ "Lost buses", self.lost_buses });
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
