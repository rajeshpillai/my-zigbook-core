const std = @import("std");

fn demoBasicDefer() void {
    std.debug.print("--- demoBasicDefer ---\n", .{});

    std.debug.print("start of function\n", .{});

    // This will run when demoBasicDefer returns (at end of this function).
    defer std.debug.print("outer defer (function scope)\n", .{});

    {
        std.debug.print("  enter inner block\n", .{});

        // This will run when the inner block ends (after this { } finishes).
        defer std.debug.print("  inner defer (block scope)\n", .{});

        std.debug.print("  leaving inner block body\n", .{});
    }

    std.debug.print("after inner block\n", .{});
}

pub fn main() void {
    demoBasicDefer();
}
