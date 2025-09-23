const std = @import("std");
const assert = std.debug.assert;

const Random = std.Random;

const FiniteRandom = @This();

fillFn: *const fn (ptr: *FiniteRandom, buf: []u8) void,
fuel: isize,

pub const Error = error{
    OutOfFuel,
};

pub const Adapter = struct {
    random: Random,
    interface: FiniteRandom,

    pub fn init(random0: Random, fuel: isize) Adapter {
        return .{
            .random = random0,
            .interface = .{
                .fillFn = &struct {
                    pub fn fillFn(self0: *FiniteRandom, buf: []u8) void {
                        const self: *Adapter = @fieldParentPtr("interface", self0);
                        self.interface.fuel -= @as(u32, @truncate(buf.len));
                        self.random.fillFn(self.random.ptr, buf);
                    }
                }.fillFn,
                .fuel = fuel,
            },
        };
    }
};

pub fn random(self: *FiniteRandom) Random {
    const fillFn = &struct {
        pub fn fillFn(ptr0: *anyopaque, buf: []u8) void {
            const ptr: *FiniteRandom = @ptrCast(@alignCast(ptr0));
            ptr.fillFn(ptr, buf);
        }
    }.fillFn;
    return .{
        .ptr = self,
        .fillFn = fillFn,
    };
}

pub const Buffer = struct {
    buf: []const u8,
    interface: FiniteRandom,

    pub fn init(buf: []const u8) Buffer {
        return .{
            .buf = buf,
            .interface = .{
                .fillFn = fillFn,
                .fuel = @as(u32, @truncate(buf.len)),
            },
        };
    }

    fn fillFn(self0: *FiniteRandom, buf: []u8) void {
        const self: *Buffer = @fieldParentPtr("interface", self0);
        const fuel: u32 = @truncate(@max(0, self.interface.fuel));
        const start: u32 = @truncate(self.buf.len - fuel);
        const amount: u32 = @truncate(@min(self.buf.len - start, buf.len));
        @memcpy(buf[0..amount], self.buf[start..][0..amount]);
        @memset(buf[amount..], 0);
        self.interface.fuel -= amount;
    }

    pub fn random(self: *Buffer) *FiniteRandom {
        return &self.interface;
    }
};

pub fn check(self: *const FiniteRandom) Error!void {
    if (self.fuel < 0) return Error.OutOfFuel;
}

pub fn boolean(self: *FiniteRandom) Error!bool {
    const r = self.random().boolean();
    try self.check();
    return r;
}

pub fn bytes(self: *FiniteRandom, buf: []u8) Error!void {
    self.random().bytes(buf);
    try self.check();
}

pub inline fn enumValue(self: *FiniteRandom, comptime EnumType: type) Error!EnumType {
    const r = self.random().enumValue(EnumType);
    try self.check();
    return r;
}

pub fn enumValueWithIndex(self: *FiniteRandom, comptime EnumType: type, comptime Index: type) Error!EnumType {
    const r = self.random().enumValueWithIndex(EnumType, Index);
    try self.check();
    return r;
}

pub fn int(self: *FiniteRandom, comptime T: type) Error!T {
    const r = self.random().int(T);
    try self.check();
    return r;
}

pub fn uintLessThanBiased(self: *FiniteRandom, comptime T: type, less_than: T) Error!T {
    const r = self.random().uintLessThanBiased(T, less_than);
    try self.check();
    return r;
}

pub fn uintLessThan(self: *FiniteRandom, comptime T: type, less_than: T) Error!T {
    const r = self.random().uintLessThan(T, less_than);
    try self.check();
    return r;
}

pub fn uintAtMost(self: *FiniteRandom, comptime T: type, at_most: T) Error!T {
    const r = self.random().uintAtMost(T, at_most);
    try self.check();
    return r;
}

pub fn uintAtMostBiased(self: *FiniteRandom, comptime T: type, at_most: T) Error!T {
    const r = self.random().uintAtMostBiased(T, at_most);
    try self.check();
    return r;
}

pub fn intRangeLessThan(self: *FiniteRandom, comptime T: type, at_least: T, less_than: T) Error!T {
    const r = self.random().intRangeLessThan(T, at_least, less_than);
    try self.check();
    return r;
}

pub fn intRangeLessThanBiased(self: *FiniteRandom, comptime T: type, at_least: T, less_than: T) Error!T {
    const r = self.random().intRangeLessThanBiased(T, at_least, less_than);
    try self.check();
    return r;
}

pub fn float(self: *FiniteRandom, comptime T: type) Error!T {
    const r = self.random().float(T);
    try self.check();
    return r;
}

pub fn floatNorm(self: *FiniteRandom, comptime T: type) Error!T {
    const r = self.random().floatNorm(T);
    try self.check();
    return r;
}

pub inline fn shuffle(self: *FiniteRandom, comptime T: type, buf: []T) Error!void {
    const r = self.random().shuffle(T, buf);
    try self.check();
    return r;
}

pub fn weightedIndex(self: *FiniteRandom, comptime T: type, proportions: []const T) Error!usize {
    const r = self.random().weightedIndex(T, proportions);
    try self.check();
    return r;
}

pub fn chance(self: *FiniteRandom, probability: Ratio) Error!bool {
    assert(probability.denominator > 0);
    assert(probability.numerator <= probability.denominator);
    return try self.uintLessThan(u64, probability.denominator) < probability.numerator;
}

/// A less than one rational number, used to specify probabilities.
pub const Ratio = struct {
    // Invariant: numerator ≤ denominator.
    numerator: u64,
    // Invariant: denominator ≠ 0.
    denominator: u64,

    pub fn zero() Ratio {
        return .{ .numerator = 0, .denominator = 1 };
    }
};

/// Canonical constructor for Ratio
pub fn ratio(numerator: u64, denominator: u64) Ratio {
    assert(denominator > 0);
    assert(numerator <= denominator);
    return .{ .numerator = numerator, .denominator = denominator };
}

pub const Combination = struct {
    total: u32,
    sample: u32,

    taken: u32,
    seen: u32,

    pub fn init(options: struct {
        total: u32,
        sample: u32,
    }) Combination {
        assert(options.sample <= options.total);
        return .{
            .total = options.total,
            .sample = options.sample,
            .taken = 0,
            .seen = 0,
        };
    }

    pub fn done(combination: *const Combination) bool {
        return combination.taken == combination.sample and combination.seen == combination.total;
    }

    pub fn take(combination: *Combination, rand: *FiniteRandom) Error!bool {
        assert(combination.seen < combination.total);
        assert(combination.taken <= combination.sample);

        const n = combination.total - combination.seen;
        const k = combination.sample - combination.taken;
        const result = try rand.chance(ratio(k, n));

        combination.seen += 1;
        if (result) combination.taken += 1;
        return result;
    }
};

pub fn EnumWeightsType(E: type) type {
    return std.enums.EnumFieldStruct(E, u64, null);
}

/// Returns a random value of an enum, where probability is proportional to weight.
pub fn enumWeighted(prng: *FiniteRandom, Enum: type, weights: EnumWeightsType(Enum)) Error!Enum {
    return enumWeightedImpl(prng, Enum, weights);
}

fn enumWeightedImpl(prng: *FiniteRandom, Enum: type, weights: anytype) Error!Enum {
    const fields = @typeInfo(Enum).@"enum".fields;
    var total: u64 = 0;
    inline for (fields) |field| {
        total += @field(weights, field.name);
    }
    assert(total > 0);
    var pick = try prng.uintLessThan(u64, total);
    inline for (fields) |field| {
        const weight = @field(weights, field.name);
        if (pick < weight) return @as(Enum, @enumFromInt(field.value));
        pick -= weight;
    }
    unreachable;
}

pub fn randomEnumWeights(
    prng: *FiniteRandom,
    comptime Enum: type,
) Error!EnumWeightsType(Enum) {
    const fields = comptime std.meta.fieldNames(Enum);

    var combination = Combination.init(.{
        .total = fields.len,
        .sample = try prng.intRangeLessThan(u32, 1, fields.len + 1),
    });
    defer assert(combination.done());

    var weights: EnumWeightsType(Enum) = undefined;
    inline for (fields) |field| {
        @field(weights, field) = if (try combination.take(prng))
            try prng.intRangeLessThan(u64, 1, 101)
        else
            0;
    }

    return weights;
}

test {
    std.testing.refAllDecls(@This());
}

test "smoke" {
    const testing = std.testing;
    const expect = testing.expect;
    _ = expect; // autofix
    const expectEqual = testing.expectEqual;

    var rand0 = Random.Xoshiro256.init(1234);
    var rand1 = FiniteRandom.Adapter.init(rand0.random(), std.math.maxInt(isize));
    const rand = &rand1.interface;
    const E = enum {
        first,
        second,
        third,
        fourth,
    };
    const weights = try rand.randomEnumWeights(E);
    const e = try rand.enumWeighted(E, weights);
    try expectEqual(.third, e);
}
