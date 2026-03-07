const std = @import("std");
const stats = @import("distributions");

const Random = std.Random;
const ArrayList = std.ArrayList;
const Io = std.Io;

const main = @import("main.zig");
const sampling = @import("rng.zig");
const entities = @import("entities.zig");

const ContDist = stats.ContinuousDistribution;
const DiscDist = stats.DiscreteDistribution;

const is_v1 = std.mem.eql(u8, "v1", @import("build").build);
pub const SimConfig = if(is_v1) SimConfigV1 else SimConfigV2;

// accepts just f64 and f32 due to rng implementaiton
pub const Precision = f32;


const SimConfigV1 = struct {
    seed: ?u64,
    user_policy: DiscDist(Precision, entities.Action),       // probability of available actions of the user
    user_inter_action: ContDist(Precision), // time between a user two actions
    propagation_delay: ContDist(f64),       // time between an action over a post and showing up followers timeline
    interaction_delay: ContDist(f64),       // time between 
    trace_to_file: bool,                    // true is trace is written to a file. False not
    horizon: f64,                           // duration of the simulation

    pub fn format(
        self: SimConfigV1,
        writer: *std.Io.Writer,
    ) !void {
        try writer.writeAll("\n");
        try writer.writeAll("+--------------------------+\n");
        try writer.print("| SIMULATION CONFIGURATION |\n", .{});
        try writer.writeAll("+--------------------------+\n");
        try writer.print("{s: <24}:  {f}\n", .{ "User policy", self.user_policy});
        try writer.print("{s: <24}:  {f}\n", .{ "Time between actions", self.user_inter_action});
        try writer.print("{s: <24}:  {f}\n", .{ "Propagation delay", self.propagation_delay});
        try writer.print("{s: <24}:  {f}\n", .{ "Interaction delay", self.interaction_delay});
        try writer.writeAll("---------\n");
        try writer.print("{s: <24}:  {d: <23.2}\n", .{ "Horizon (Time)", self.horizon });
    }
};

const SimConfigV2 = struct {
    seed: ?u64,
    horizon: f64,                           // duration of the simulation
    // user related actions
    user_policy: DiscDist(Precision, entities.Action),   // probability of available actions of the user
    user_inter_action: ContDist(Precision),     // time between a user two actions
    // delays on posts transmissions
    propagation_delay: ContDist(f64),           // time between an action over a post and showing up followers timeline
    interaction_delay: ContDist(f64),           // time between 
    // session configuration                                        
    init_vacation_ratio: Precision,             // which proportion of the users start on vacation
    session_duration: ContDist(f64),           // duration of the current session
    user_inter_session: ContDist(f64),         // time between sessions
    // notification stuff
    // if you receive a notification when online, go see that reply 
    // if you receive a notification when online, which chance to go online (and see that reply): Precision             
    // if seeing a reply to a post, chance to read the the thread from the beginning: ???? no friking clue
    // misc config
    trace_to_file: bool,                        // true is trace is written to a file. False not

    pub fn format(
        self: SimConfigV2,
        writer: *std.Io.Writer,
    ) !void {
        try writer.writeAll("\n");
        try writer.writeAll("+--------------------------+\n");
        try writer.print("| SIMULATION CONFIGURATION |\n", .{});
        try writer.writeAll("+--------------------------+\n");
       
        try writer.writeAll("--- User Actions Config ---\n");
        try writer.print("{s: <24}:  {f}\n", .{ "User policy", self.user_policy});
        try writer.print("{s: <24}:  {f}\n", .{ "Time between actions", self.user_inter_action});
       
        try writer.writeAll("--- Post Propagation Delays ---\n");
        try writer.print("{s: <24}:  {f}\n", .{ "Propagation delay", self.propagation_delay});
        try writer.print("{s: <24}:  {f}\n", .{ "Interaction delay", self.interaction_delay});
        
        try writer.writeAll("--- User Sessions (Vacations) ---\n");
        try writer.print("{s: <24}:  {d}\n", .{ "% of user starting on vacation", self.init_vacation_ratio});
        try writer.print("{s: <24}:  {f}\n", .{ "Vacation Duration", self.session_duration});
        try writer.print("{s: <24}:  {f}\n", .{ "Time between Vacations", self.user_inter_session});
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
