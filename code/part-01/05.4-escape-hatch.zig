const std = @import("std");

const DemoError = error{
    ShouldNeverHappen,
};

fn cannotFailInThisContext() DemoError!void {
    // Imagine this can only fail if some invariant is broken.
    return DemoError.ShouldNeverHappen;
}

pub fn main() void {
    // We are *asserting* that this call will never fail.
    // If it *does* fail in Debug or ReleaseSafe, the program will crash.
    cannotFailInThisContext() catch unreachable;

    std.debug.print("If you see this, cannotFailInThisContext() did not error.\n", .{});
}
