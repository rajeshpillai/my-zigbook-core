const std = @import("std");

pub fn main() void {
    const msg: [:0]const u8 = "Hello Zig!";

    std.debug.print("Message: {s}\n", .{msg});

    std.debug.print("Iterating bytes:\n", .{});
    for (msg) |b| { // stops at sentinel automatically
        std.debug.print("{c} ", .{b});
    }

    // You can’t use a plain string literal directly, because it’s always \0-terminated.
    // You must build a sentinel-terminated array with sentinel 'x', then slice it.

    // const msg2: [:'x']const u8 = "Hello Zig!x"; // This will NOT WORK

    // This will work
    const msg2 = [_:'x']u8{
        'H', 'e', 'l', 'l', 'o', ' ', 'Z', 'i', 'g', '!',
    };

    // std.debug.print("\nMessage: {s}\n", .{msg2});

    std.debug.print("\nIterating bytes:\n", .{});
    for (msg2) |b| { // stops at sentinel automatically
        std.debug.print("{c} ", .{b});
    }

    std.debug.print("\nChar AT 10 is {c} ", .{msg2[10]});
}
