const std = @import("std");

pub fn main() void {
    var arr = [_]i32{ 10, 20, 30 };

    // A normal single-item pointer (no pointer arithmetic on this):
    const p_single: *i32 = &arr[0];
    std.debug.print("p_single points to: {d}\n", .{p_single.*}); // 10

    // Get a slice over the whole array.
    const slice: []i32 = arr[0..];

    // A "many-pointer": pointer to multiple elements.
    // Slices in Zig have a .ptr field of type [*]T (many-pointer).
    var p_many: [*]i32 = slice.ptr;

    std.debug.print("p_many[0] = {d}\n", .{p_many[0]}); // 10

    // Pointer arithmetic: move one element forward (to arr[1]).
    p_many += 1;
    std.debug.print("p_many[0] = {d}\n", .{p_many[0]}); // 20

    // Move again (to arr[2]).
    p_many += 1;
    std.debug.print("p_many[0] = {d}\n", .{p_many[0]}); // 30
}
