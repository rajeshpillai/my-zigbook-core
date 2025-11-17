const std = @import("std");

// Define a small error set for this demo.
const DemoError = error{
    Boom,
};

// A function that sometimes fails.
fn demoErrDefer(should_fail: bool) DemoError!void {
    std.debug.print("--- demoErrDefer (should_fail = {any}) ---\n", .{should_fail});

    // This always runs when demoErrDefer returns (success or error).
    defer std.debug.print("defer: always runs (success or error)\n", .{});

    // This only runs if we return with an error.
    errdefer std.debug.print("errdefer: runs only on error\n", .{});

    if (should_fail) {
        std.debug.print("About to fail with DemoError.Boom\n", .{});
        return DemoError.Boom;
    }

    std.debug.print("Work done successfully, returning OK\n", .{});
}

pub fn main() void {
    // Case 1: success path
    _ = demoErrDefer(false) catch |err| {
        std.debug.print("Unexpected error: {any}\n", .{err});
    };

    std.debug.print("\n", .{}); // separator

    // Case 2: error path
    _ = demoErrDefer(true) catch |err| {
        std.debug.print("Caught error in main: {any}\n", .{err});
    };
}
