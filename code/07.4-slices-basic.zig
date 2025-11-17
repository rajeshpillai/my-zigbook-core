const std = @import("std");

pub fn main() void {
    var arr = [_]i32{ 10, 20, 30, 40 };

    const mid = arr[1..3];
    std.debug.print("slice len = {d}\n", .{mid.len});
    std.debug.print("slice = {any}\n", .{mid});
}
