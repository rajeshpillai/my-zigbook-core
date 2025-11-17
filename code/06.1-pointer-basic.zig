const std = @import("std");

pub fn main() void {
    var x: i32 = 42;

    // Normal value
    std.debug.print("x = {d}\n", .{x});

    // Pointer to x
    const p: *i32 = &x; // & = "address-of"

    std.debug.print("pointer p points to address: {*}\n", .{p});
    std.debug.print("value at pointer p = {d}\n", .{p.*});
}
