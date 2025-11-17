const std = @import("std");

pub fn main() void {
    var nums = [_]i32{ 10, 20, 30, 40 };

    // Single pointer
    const p: *i32 = &nums[0];
    std.debug.print("p -> {d}\n", .{p.*});

    // Slice (safe)
    const mid: []i32 = nums[1..4];
    std.debug.print("slice = {any}\n", .{mid});

    // Many-pointer (pointer arithmetic)
    var p_many: [*]i32 = mid.ptr;
    std.debug.print("p_many[0] = {d}\n", .{p_many[0]});

    p_many += 1;
    std.debug.print("p_many[0] = {d}\n", .{p_many[0]});

    // Optional pointer
    const maybe: ?*const i32 = &nums[2];
    if (maybe) |ptr| {
        std.debug.print("maybe points to: {d}\n", .{ptr.*});
    }
}
