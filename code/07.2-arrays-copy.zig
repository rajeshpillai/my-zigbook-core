const std = @import("std");

pub fn main() void {
    const a = [_]i32{ 1, 2, 3 };
    var b = a; // deep copy

    b[0] = 999;

    std.debug.print("a = {any}\n", .{a});
    std.debug.print("b = {any}\n", .{b});
}
