const std = @import("std");

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

pub fn intRangeLessThan(self: *FiniteRandom, comptime T: type, at_least: T, less_than: T) Error!T {
    const r = self.random().intRangeLessThan(T, at_least, less_than);
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

test {
    std.testing.refAllDecls(@This());
}
