const std = @import("std");
const print = std.debug.print;
pub fn main() !void {
    for (0..5) |i| {
        print("{d}\n", .{i});
        std.Thread.sleep(1_000_000_000); // Sleep for 1 second (it takes nanoseconds) -> 1_000_000_000 ns = 1 s
    }
    print("Countdown complete!\n", .{});
}
