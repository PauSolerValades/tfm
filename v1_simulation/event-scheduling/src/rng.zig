const std = @import("std");
const eql = std.mem.eql;
const ArrayList = std.ArrayList;
const Random = std.Random;
const Allocator = std.mem.Allocator;
const pow = std.math.pow;

const RNGError = error{InvalidRange};

/// Generate a random number of a uniform distribution
/// in the interval [a,b].
pub fn runif(comptime T: type, a: T, b: T, rng: Random) !T {
    if (@typeInfo(T) != .float) @compileError("T must be a float (eg f32 or f64)\n");
    if (b < a) return RNGError.InvalidRange;

    return a + (b - a) * rng.float(T);
}

pub fn rexp(comptime T: type, lambda: T, rng: Random) T {
    const u = runif(T, 0, 1, rng) catch unreachable; // com que 0, 1 estan harcodejats, mai tindrem error
    return (1 / lambda) * (-@log(u));
}

pub fn rtexp(comptime T: type, k: T, rng: Random) T {
    const u = runif(T, 0, 1, rng) catch unreachable;
    const e = std.math.e;
    return k*(1 - 0.5*@log(e*e - u*(e*e - 1)));
}

/// Erlang distribution (Sum of k independent exponentials with rate lambda)
/// k: shape (number of phases)
/// lambda: rate
//pub fn rerlang(comptime T: type, k: usize, lambda: T, rng: Random) T {
//    var product_u: T = 1.0;
//    for (0..k) |_| {
//        product_u *= rng.float(T);
//    }
//    // sum of logs = Log of product
//    const safe_p = if (product_u == 0) std.math.floatEps(T) else product_u;
//    return -@log(safe_p) / lambda;
//}
pub fn rerlang(comptime T: type, k: usize, lambda: T, rng: Random) T {
    var sum: f64 = 0.0;
    for (0..k) |_| {
        sum += rexp(T, lambda, rng);
    }
    return sum;
}

/// Hypoexponential (Sum of n independent exponentials with DIFFERENT rates)
/// rates: slice of lambdas
pub fn rhypo(comptime T: type, rates: []const T, rng: Random) T {
    var sum: T = 0.0;
    for (rates) |lambda| {
        sum += rexp(T, lambda, rng);
    }
    return sum;
}

/// Hyperexponential (Probabilistic choice between parallel branches)
/// probs: probability of choosing branch i
/// rates: rate of exponential for branch i
pub fn rhyper(comptime T: type, probs: []const T, rates: []const T, rng: Random) T {
    const p = rng.float(T); // Roll a dice 0.0 to 1.0
    var cumulative: T = 0.0;

    for (probs, 0..) |prob, i| {
        cumulative += prob;
        if (p <= cumulative) {
            return rexp(T, rates[i], rng);
        }
    }
    // Fallback: return the last one in case of rounding errors
    return rexp(T, rates[rates.len - 1], rng);
}


const Distribution = @import("config.zig").Distribution;

/// Generates 'n' samples from any Distribution and returns them in an ArrayList.
/// Caller owns the returned memory.
pub fn sampleAlloc(
    allocator: *Allocator, 
    n: u32, 
    dist: Distribution, 
    rng: *Random
) !ArrayList(f64) {
    var list = ArrayList(f64){};
    
    try list.ensureTotalCapacity(allocator.*, n);

    for (0..n) |_| {
        const val = try dist.sample(rng.*);
        list.appendAssumeCapacity(val);
    }

    return list;
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var gpa = arena.allocator();
    
    var buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&buffer);
    const stdout = &stdout_writer.interface;
    
    var prng = std.Random.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    var rand = prng.random();

    const sample_size: u64 = 10000;

    var hypo_rates = [_]f64{ 3.0, 7.0 };
    const hyper_probs = [_]f64{ 0.3, 0.7 };
    var hyper_rates = [_]f64{ 3.0, 7.0 };

    const unif = Distribution{ .uniform = .{ .min = 0, .max = 1 } };
    const exp = Distribution{ .exponential = 3  };
    const texp = Distribution{ .exp_trunc = .{ .k = 30} };
    const hypo = Distribution{ .hypo = &hypo_rates };
    const hyper = Distribution{ .hyper = .{ .rates = &hyper_rates, .probs = &hyper_probs }};
    const erlang = Distribution{ .erlang = .{ .k = 3, .lambda = 0.5 }};

    var unif_sample = try sampleAlloc(&gpa, sample_size, unif, &rand);
    defer unif_sample.deinit(gpa);

    var exp_sample = try sampleAlloc(&gpa, sample_size, exp, &rand);
    defer exp_sample.deinit(gpa);

    var texp_sample = try sampleAlloc(&gpa, sample_size, texp, &rand);
    defer texp_sample.deinit(gpa);
    
    var hypo_sample = try sampleAlloc(&gpa, sample_size, hypo, &rand);
    defer hypo_sample.deinit(gpa);
    
    var hyper_sample = try sampleAlloc(&gpa, sample_size, hyper, &rand);
    defer hyper_sample.deinit(gpa);

    var erlang_sample = try sampleAlloc(&gpa, sample_size, erlang, &rand);
    defer erlang_sample.deinit(gpa);

    try write_sample_to_file("../python/samples/uniform.csv", unif_sample);
    try write_sample_to_file("../python/samples/exponential.csv", exp_sample);
    try write_sample_to_file("../python/samples/trunc_exp.csv", texp_sample);
    try write_sample_to_file("../python/samples/hypoexponential.csv", hypo_sample);
    try write_sample_to_file("../python/samples/hyperexponential.csv", hyper_sample);
    try write_sample_to_file("../python/samples/erlang.csv", erlang_sample);
    
    try stdout.writeAll("Finished writting samples in ../python/samples");
    try stdout.flush();
}

fn write_sample_to_file(name: []const u8, sample: ArrayList(f64)) !void {
    const cwd = std.fs.cwd();
    const file = try cwd.createFile(name, .{});
    defer file.close();

    var buf: [2048]u8 = undefined;
    var stdout_file = file.writer(&buf);
    const writer: *std.Io.Writer = &stdout_file.interface;

    for (sample.items) |s| {
        try writer.print("{d} ", .{s});
    }
    try writer.print("\n", .{});
    try writer.flush();
    return;
}
// petita nota sobre l'arraylist. A la següent funció, quan es crea una array list crea, en essència, una
// struct amb un slice apuntant al heap i la capacitat d'aquest slice (que és un punter a una array + len).
// Per tant, quan es retorna l'arrayList i no un punter a l'arraylist, el que es fa és una còpia d'aquesta mini
// estructura, ja que al estar a l'stack de la funció no es pot tornar-hi un punter (s'allibrerarà just quan es
// retorni la funció.)
// La còpia d'aquesta estructura fa que necessitis declarar l'array list al main com a var i no com a const, ja
// que al intentar allibrerar la memòria de const __sample no funcinarà el .deinit() ja que ha de ser mutable.

/// Generate an sample of a uniform distribution [a,b)
pub fn runifSampleAlloc(allocator: Allocator, n: u32, comptime T: type, a: T, b: T, rng: Random) !ArrayList(T) {
    var sample: ArrayList(T) = .empty;
    try sample.ensureTotalCapacity(allocator, n);

    for (0..n) |_| {
        const u = try runif(T, a, b, rng);
        _ = try sample.append(allocator, u);
    }

    return sample;
}

/// Generate a sample of a Exponential distribution of parameter lambda.
fn rexpSampleAlloc(allocator: Allocator, n: u32, comptime T: type, lambda: T, rng: Random) !ArrayList(T) {
    var sample: ArrayList(T) = .empty;
    try sample.ensureTotalCapacity(allocator, n);

    for (0..n) |_| {
        const u = try runif(T, 0, 1, rng) catch unreachable;
        const e = lambda * (-@log(u));
        _ = try sample.append(allocator, e);
    }

    return sample;
}

/// Generate a sample of a Weibull distribution of lambda and k.
fn rwbSampleAlloc(allocator: Allocator, n: u32, comptime T: type, lambda: T, k: T, rng: Random) !ArrayList(T) {
    var sample: ArrayList(T) = .empty;
    try sample.ensureTotalCapacity(allocator, n);

    for (0..n) |_| {
        const u = try runif(T, 0, 1, rng);
        const w = lambda * (pow(T, -@log(u), 1.0 / k));
        _ = try sample.append(allocator, w);
    }

    return sample;
}

/// Generate a gamma distrubution taking into account that a gamma is the sum of exponentials.
///
fn rgammaSampleAlloc(allocator: Allocator, n: u32, comptime T: type, shape: u32, scale: T, rng: Random) !ArrayList(T) {
    var sample: ArrayList(T) = .empty;
    try sample.ensureTotalCapacity(allocator, n);

    for (0..n) |_| {
        var g: T = 0.0;
        // sum of exponentials
        for (0..shape) |_| {
            const u = try runif(T, 0, 1, rng);
            g -= @log(u);
        }
        g *= scale;
        _ = try sample.append(allocator, g);
    }

    return sample;
}

fn rcauchySampleAlloc(allocator: Allocator, n: u32, comptime T: type, gamma: T, x0: T, rng: Random) !ArrayList(T) {
    var sample: ArrayList(T) = .empty;
    try sample.ensureTotalCapacity(allocator, n);

    for (0..n) |_| {
        const u = try runif(T, 0, 1, rng);
        const e = x0 + gamma * @tan(std.math.pi * (u - 0.5));
        _ = try sample.append(allocator, e);
    }

    return sample;
}
