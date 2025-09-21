//! By convention, root.zig is the root source file when making a library.
const std = @import("std");
const FiniteRandom = @import("FiniteRandom.zig");
const time = std.time;
const Random = std.Random;

pub const Seed = packed struct(u64) {
    size: u32,
    seed: u32,

    pub fn format(
        self: Seed,
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        try writer.print("0x{x}", .{@as(u64, @bitCast(self))});
    }
};

pub const Options = struct {
    size_min: u32 = 32,
    size_max: u32 = 65536,
    budget: u64 = time.ns_per_ms * 100,
    seed: ?u64 = null,
    minimize: bool = false,
    minimize_rounds: u64 = std.math.maxInt(u64),
    search_rounds: u64 = std.math.maxInt(u64),
    search_rounds_per_size: u64 = 3,
};

const Context = struct {
    context: *anyopaque,
    testCase: *const fn (context: *anyopaque, rand: *FiniteRandom) anyerror!void,
    options: Options,
    rand: Random,

    fn seed(self: *const Context, size: u32) Seed {
        return .{ .seed = self.rand.int(u32), .size = size };
    }
};

pub fn run(context0: anytype, comptime testCase0: fn (context: @TypeOf(context0), rand: *FiniteRandom) anyerror!void, options: Options) anyerror!void {
    const C = @TypeOf(context0);
    var context1 = context0;
    var context_rand = Random.DefaultPrng.init(std.testing.random_seed);
    const context: Context = .{
        .context = &context1,
        .testCase = &struct {
            fn testCase(context2: *anyopaque, rand: *FiniteRandom) anyerror!void {
                const context3: *C = @ptrCast(@alignCast(context2));
                try testCase0(context3.*, rand);
            }
        }.testCase,
        .options = options,
        .rand = context_rand.random(),
    };
    if (options.seed) |seed| {
        if (options.minimize) {
            try runMinimize(&context, @bitCast(seed));
        } else {
            try runReproduce(&context, @bitCast(seed));
        }
    } else {
        if (options.minimize) {
            std.debug.panic("Cannot minimize without seed", .{});
        }
        try runSearch(&context);
    }
}
fn runReproduce(context: *const Context, seed: Seed) anyerror!void {
    trySeed(context, seed) catch |err| {
        std.debug.print("Reproduced seed failure {f}\n", .{seed});
        return err;
    };
}

fn trySeed(context: *const Context, seed: Seed) anyerror!void {
    var rand0 = Random.DefaultPrng.init(seed.seed);
    var rand1 = FiniteRandom.init(rand0.random(), seed.size);
    try context.testCase(context.context, &rand1);
}

fn halfMinimizer(s: u32) u32 {
    return s / 2;
}

fn nineTenthsMinimizer(s: u32) u32 {
    return (s *| 9) / 10;
}

fn subOneMinimizer(s: u32) u32 {
    return s - 1;
}

fn elapsed(instant: time.Instant) !u64 {
    return (try time.Instant.now()).since(instant);
}

fn runMinimize(context: *const Context, seed0: Seed) anyerror!void {
    var seed = seed0;
    const options = context.options;
    const budget = options.budget;
    const t = try time.Instant.now();
    const minimizers: []const (*const fn (u32) u32) = &.{
        &halfMinimizer,
        &nineTenthsMinimizer,
        &subOneMinimizer,
    };
    var last_minimization_time = try time.Instant.now();
    var last_error: ?anyerror = null;
    var last_error_trace: ?*std.builtin.StackTrace = null;
    var minimizer: usize = 0;
    var rounds: usize = 0;
    search: while (true) {
        std.debug.print("seed {f}, seed size {}, search time {}\n", .{ seed, seed.size, try elapsed(t) });
        if (seed.size == 0) {
            break;
        }
        while (true) {
            if (rounds >= options.minimize_rounds) break :search;
            rounds += 1;
            if (try elapsed(t) > budget) {
                break :search;
            }
            if (try elapsed(last_minimization_time) > budget / 5 and minimizer < minimizers.len - 1) {
                minimizer += 1;
            }
            const size = minimizers[minimizer](seed.size);
            const candidate_seed = context.seed(size);
            trySeed(context, candidate_seed) catch |err| {
                if (err == FiniteRandom.Error.OutOfFuel) {
                    if (minimizer == minimizers.len - 1) {
                        break :search;
                    }
                    minimizer += 1;
                    continue :search;
                }
                seed = candidate_seed;
                last_minimization_time = try time.Instant.now();
                last_error_trace = @errorReturnTrace();
                last_error = err;
                continue :search;
            };
        }
    }
    std.debug.print("minimized\n", .{});
    std.debug.print("seed {f}, seed size {}, search time {}\n", .{ seed, seed.size, try elapsed(t) });
    if (last_error) |err| {
        std.debug.print("{}{f}", .{ err, last_error_trace.? });
        return err;
    } else {
        std.debug.print("failed to find error\n", .{});
        return error.MinimizationFailedToFindError;
    }
}

const ROUNDS_FOR_FIXED_SIZE = 3;

fn runSearch(context: *const Context) anyerror!void {
    const options = context.options;
    const t = try time.Instant.now();
    var size = options.size_min;
    var rounds: usize = 0;
    search: while (true) {
        for (0..options.search_rounds_per_size) |_| {
            if (rounds >= options.search_rounds) break :search;
            rounds += 1;
            if (try elapsed(t) > options.budget) {
                break :search;
            }
            const seed = context.seed(size);
            trySeed(context, seed) catch |err| {
                std.debug.print("Found failing seed {f}\n", .{seed});
                return err;
            };
        }
        const bigger = (@as(u64, size) *| 5) / 4;
        size = @min(bigger, options.size_max);
    }
    std.debug.print("Found no error after {} rounds\n", .{rounds});
}

test {
    std.testing.refAllDecls(@This());
    _ = FiniteRandom;
}

test "smoke" {
    const testing = std.testing;
    try run(
        {},
        struct {
            fn f(_: void, rand: *FiniteRandom) anyerror!void {
                const b1 = try rand.boolean();
                const b2 = try rand.boolean();
                try testing.expect(b1 == b2);
            }
        }.f,
        .{
            .seed = 0xa41f617a00000020,
            .minimize = true,
        },
    );
}
