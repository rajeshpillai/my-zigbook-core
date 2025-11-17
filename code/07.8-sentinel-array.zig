const std = @import("std");

pub fn main() void {
    // Fixed-size, last byte must be 0:
    const hello: [6:0]u8 = .{ 'H', 'e', 'l', 'l', 'o', 'w' };

    std.debug.print("Sentinel array: {any}\n", .{hello});
    std.debug.print("Length: {}\n", .{hello.len});
    std.debug.print("At 5: {}\n", .{hello[5] == 'w'});
    std.debug.print("At 6: {}\n", .{hello[6] == 0});

    const hello2: [6:'x']u8 = .{ 'H', 'e', 'l', 'l', 'o', 'w' };

    std.debug.print("Sentinel array: {any}\n", .{hello2});
    std.debug.print("Length: {}\n", .{hello2.len});
    std.debug.print("At 5: {}\n", .{hello2[5] == 'w'});
    std.debug.print("At 6: {}\n", .{hello2[6] == 'x'});
}
