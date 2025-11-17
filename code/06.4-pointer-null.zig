const std = @import("std");

// Return: either a pointer to a (const) i32, or null.
fn findPositive(ptr: *const i32) ?*const i32 {
    // Check the value that the pointer points to.
    if (ptr.* > 0) {
        return ptr; // not null
    }
    return null;
}

pub fn main() void {
    // These values are never mutated, so we use const.
    const a: i32 = 10;
    const b: i32 = -5;

    // Take their addresses (pointers to const i32).
    const pa: *const i32 = &a;
    const pb: *const i32 = &b;

    if (findPositive(pa)) |ptr| {
        // Inside this block, ptr is a non-null *const i32.
        std.debug.print("pa points to a positive value: {d}\n", .{ptr.*});
    }

    if (findPositive(pb) == null) {
        std.debug.print("pb does NOT point to a positive value\n", .{});
    }
}
