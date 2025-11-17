const std = @import("std");

pub fn main() void {
    var x: i32 = 10;
    const p: *i32 = &x;

    std.debug.print("Before: x = {d}\n", .{x});

    // Modify through pointer
    p.* = 999;

    std.debug.print("After: x = {d}\n", .{x});
}
