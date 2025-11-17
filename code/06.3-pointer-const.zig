const std = @import("std");

pub fn main() void {
    var x: i32 = 50;

    // Pointer to const value: cannot modify x through this pointer.
    const p_const_value: *const i32 = &x;

    // Pointer itself is const (cannot be reassigned),
    // but the value it points to (x) IS mutable.
    const p_const_pointer: *i32 = &x;

    std.debug.print("x initially = {d}\n", .{x});

    // Reading through a const pointer is allowed:
    std.debug.print("Reading through p_const_value: {d}\n", .{p_const_value.*});

    // Mutate x directly (valid)
    x = 999;

    std.debug.print("x after direct mutation = {d}\n", .{x});

    // ❌ This would NOT compile:
    // p_const_value.* = 123;   // cannot assign, value is const

    // ❌ This would NOT compile:
    // p_const_pointer = &x;    // cannot reassign const pointer

    // Both pointers still see the updated value:
    std.debug.print("p_const_value now reads = {d}\n", .{p_const_value.*});
    std.debug.print("p_const_pointer now reads = {d}\n", .{p_const_pointer.*});
}
