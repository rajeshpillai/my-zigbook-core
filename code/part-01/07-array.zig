const std = @import("std");

pub fn main() void {
    var arr = [_]i32{ 10, 20, 30, 40 };

    const whole = arr[0..];
    const mid = arr[1..3];
    const tail = arr[2..];

    std.debug.print("whole = {any}\n", .{whole});
    std.debug.print("mid   = {any}\n", .{mid});
    std.debug.print("tail  = {any}\n", .{tail});

    const name = "Zig Language";
    const part = name[4..12];

    std.debug.print("part of name = {s}\n", .{part});
}
