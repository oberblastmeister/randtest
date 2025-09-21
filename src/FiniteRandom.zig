const std = @import("std");

const Random = std.Random;

const FiniteRandom = @This();

ptr: *anyopaque,
fillFn: *const fn (ptr: *anyopaque, buf: []u8) void,
fuel: isize,

pub const Error = error{
    OutOfFuel,
};

pub fn init(rand: Random, fuel: isize) FiniteRandom {
    return .{
        .ptr = rand.ptr,
        .fillFn = rand.fillFn,
        .fuel = fuel,
    };
}

pub fn random(self: *FiniteRandom) Random {
    const fillFn = &struct {
        pub fn fillFn(ptr0: *anyopaque, buf: []u8) void {
            const ptr: *FiniteRandom = @ptrCast(@alignCast(ptr0));
            ptr.fuel -= @as(u32, @truncate(buf.len));
            ptr.fillFn(ptr.ptr, buf);
        }
    }.fillFn;
    return .{
        .ptr = self,
        .fillFn = fillFn,
    };
}

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

pub fn int(self: *FiniteRandom, comptime T: type) Error!T {
    const r = self.random().int(T);
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

test {
    std.testing.refAllDecls(@This());
}
