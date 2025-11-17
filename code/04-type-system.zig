const std = @import("std");

// ------------------------------------------------------------
// 4. Error sets and error unions (!T)
// ------------------------------------------------------------

// Define an error set at top level.
// This is like defining all possible error variants.
const MyError = error{
    NotFound,
    PermissionDenied,
};

// A function that can either return a u8 or one of the MyError values.
// Signature: MyError!u8  ==>  "u8 or MyError"
fn mightFail(id: u8) MyError!u8 {
    if (id == 0) return MyError.NotFound;
    if (id == 255) return MyError.PermissionDenied;
    return id + 1;
}

pub fn main() !void {
    // ------------------------------------------------------------
    // 1. Integers: explicit sizes, no implicit conversions
    // ------------------------------------------------------------
    const a: u32 = 10; // 32-bit unsigned integer
    const b: i32 = -5; // 32-bit signed integer

    // No cast needed here: a is u32, 5 becomes u32 in this expression.
    const c: u32 = a + 5;
    std.debug.print("Integers -> a = {d}, b = {d}, c = {d}\n", .{ a, b, c });

    // ------------------------------------------------------------
    // 2. Arrays and Slices
    // ------------------------------------------------------------
    var numbers = [_]u8{ 1, 2, 3, 4 }; // Fixed-size array
    const middle: []u8 = numbers[1..3]; // Slice (view) into the array

    std.debug.print("Array length = {d}\n", .{numbers.len});
    std.debug.print("Slice length = {d}, values = {any}\n", .{ middle.len, middle });

    // ------------------------------------------------------------
    // 3. Optionals: ?T means "T or null"
    // ------------------------------------------------------------
    var maybe_number: ?u32 = null; // "maybe" value: either u32 or null

    if (maybe_number == null) {
        std.debug.print("maybe_number is currently null\n", .{});
    }

    maybe_number = 99;

    // Optional unwrapping: if it has a value, bind it to "value"
    if (maybe_number) |value| {
        std.debug.print("maybe_number now has value = {d}\n", .{value});
    }

    // ------------------------------------------------------------
    // 4. Using the error union function
    // ------------------------------------------------------------

    // This call *should* succeed.
    const ok_result = mightFail(10) catch |err| {
        // This branch only runs on error.
        std.debug.print("Unexpected error in mightFail(10): {any}\n", .{err});
        return err; // Propagate from main (main returns !void == anyerror!void)
    };
    std.debug.print("mightFail(10) => {d}\n", .{ok_result});

    // This call is expected to fail with MyError.NotFound.
    const fail_result = mightFail(0) catch |err| {
        std.debug.print("mightFail(0) failed with error = {any}\n", .{err});
        // We just return early from main after logging.
        return;
    };
    _ = fail_result; // Silence "unused variable" warning (not reached anyway).

    // ------------------------------------------------------------
    // 5. Structs
    // ------------------------------------------------------------
    const User = struct {
        id: u32,
        name: []const u8, // UTF-8 string slice
    };

    const user = User{
        .id = 1,
        .name = "Zig Developer",
    };

    std.debug.print("User -> id = {d}, name = {s}\n", .{ user.id, user.name });

    // ------------------------------------------------------------
    // 6. Enums
    // ------------------------------------------------------------
    const Color = enum {
        red,
        green,
        blue,
    };

    const col: Color = .red;

    switch (col) {
        .red => std.debug.print("Color is red\n", .{}),
        .green => std.debug.print("Color is green\n", .{}),
        .blue => std.debug.print("Color is blue\n", .{}),
    }

    // ------------------------------------------------------------
    // 7. Tagged unions
    // ------------------------------------------------------------
    const Shape = union(enum) {
        circle: f32,
        rectangle: struct { w: f32, h: f32 },
    };

    // Start with a circle variant
    var s = Shape{ .circle = 2.5 };

    switch (s) {
        .circle => |radius| {
            std.debug.print("Circle: radius={d}\n", .{radius});
        },
        .rectangle => |_| {
            unreachable; // Not possible in this branch
        },
    }

    // Change the union to be a rectangle
    s = Shape{ .rectangle = .{ .w = 10.0, .h = 4.0 } };

    switch (s) {
        .circle => {
            unreachable; // Not possible here
        },
        .rectangle => |rect| {
            std.debug.print(
                "Rectangle: {d} x {d}\n",
                .{ rect.w, rect.h },
            );
        },
    }
}
