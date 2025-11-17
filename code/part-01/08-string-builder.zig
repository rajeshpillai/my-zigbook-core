const std = @import("std");
const testing = std.testing;

/// A simple, dynamic string builder.
///
/// Internals:
/// - `buf` is the allocated buffer (capacity).
/// - `len` is how many bytes are currently used.
/// - `allocator` is who owns and manages the memory.
///
/// We store bytes (`u8`) because in Zig, strings are `[]const u8`.
pub const StringBuilder = struct {
    buf: []u8, // allocated buffer (capacity = buf.len)
    len: usize, // number of bytes actually used
    allocator: std.mem.Allocator,

    /// Initialize an empty builder with zero capacity.
    /// Memory is only allocated on first append.
    pub fn init(allocator: std.mem.Allocator) StringBuilder {
        return .{
            .buf = &[_]u8{}, // empty slice, no heap allocation yet
            .len = 0,
            .allocator = allocator,
        };
    }

    /// Initialize with a preallocated capacity.
    /// Useful when you know approximately how large the final string will be.
    pub fn initWithCapacity(allocator: std.mem.Allocator, capacity: usize) !StringBuilder {
        if (capacity == 0) {
            return StringBuilder.init(allocator);
        }

        const buf = try allocator.alloc(u8, capacity);
        return .{
            .buf = buf,
            .len = 0,
            .allocator = allocator,
        };
    }

    /// Free the underlying buffer.
    /// After calling this, the builder must not be used again.
    pub fn deinit(self: *StringBuilder) void {
        // Only free if we actually allocated something on the heap.
        if (self.buf.len != 0) {
            self.allocator.free(self.buf);
        }
        self.buf = &[_]u8{};
        self.len = 0;
    }

    /// Return current contents as a read-only slice.
    /// IMPORTANT: The returned slice is valid only as long as the builder lives
    /// and is not re-allocated (i.e. no further appends that cause a grow).
    pub fn toSlice(self: *const StringBuilder) []const u8 {
        return self.buf[0..self.len];
    }

    /// Clear contents but keep capacity.
    /// This is like "reset" — cheap and does not free memory.
    pub fn clear(self: *StringBuilder) void {
        self.len = 0;
    }

    /// Ensure that the builder can hold at least `needed` bytes
    /// without reallocation.
    fn ensureCapacity(self: *StringBuilder, needed: usize) !void {
        if (self.buf.len >= needed) return;

        const old_cap = self.buf.len;

        // Simple growth strategy:
        // new_cap = max(old_cap * 2, needed), with a minimum of 16 when growing from 0.
        const new_cap = blk: {
            if (old_cap == 0) {
                break :blk @max(needed, 16);
            }
            const doubled = old_cap * 2;
            break :blk if (doubled > needed) doubled else needed;
        };

        const new_buf = try self.allocator.alloc(u8, new_cap);

        // Copy existing data into new buffer.
        if (self.len != 0) {
            std.mem.copyForwards(u8, new_buf[0..self.len], self.buf[0..self.len]);
        }

        // Free old buffer (if any).
        if (old_cap != 0) {
            self.allocator.free(self.buf);
        }

        self.buf = new_buf;
    }

    /// Append a single byte (character).
    pub fn appendByte(self: *StringBuilder, b: u8) !void {
        const needed = self.len + 1;
        try self.ensureCapacity(needed);
        self.buf[self.len] = b;
        self.len += 1;
    }

    /// Append a byte slice (string).
    pub fn appendSlice(self: *StringBuilder, s: []const u8) !void {
        if (s.len == 0) return;

        const needed = self.len + s.len;
        try self.ensureCapacity(needed);

        std.mem.copyForwards(u8, self.buf[self.len..needed], s);
        self.len = needed;
    }

    /// Append a null-terminated string (C-style).
    /// Convenient when working with [:0]const u8.
    pub fn appendSentinelTerminated(self: *StringBuilder, s: [:0]const u8) !void {
        try self.appendSlice(s);
    }

    /// Append formatted text just like std.debug.print,
    /// but write into the string builder instead of stdout.
    ///
    /// NOTE: This version uses a fixed-size stack buffer (256 bytes).
    /// For larger formatted strings you can loop in chunks or increase the buffer.
    pub fn appendFmt(
        self: *StringBuilder,
        comptime fmt: []const u8,
        args: anytype,
    ) !void {
        var tmp: [256]u8 = undefined;
        const written = try std.fmt.bufPrint(&tmp, fmt, args);
        try self.appendSlice(written);
    }
};

/// Simple demo of using StringBuilder.
/// Build a greeting string dynamically and print it.
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leak = gpa.deinit();
        if (leak == .leak) {
            std.debug.print("MEMORY LEAK DETECTED\n", .{});
        }
    }

    const allocator = gpa.allocator();

    var sb = try StringBuilder.initWithCapacity(allocator, 32);
    defer sb.deinit();

    try sb.appendSlice("Hello, ");
    try sb.appendSlice("Zig ");
    try sb.appendSlice("Developer");
    try sb.appendByte('!');
    try sb.appendByte('\n');

    try sb.appendFmt("2 + 3 = {d}\n", .{2 + 3});

    const result = sb.toSlice();
    std.debug.print("Final string ({d} bytes):\n{s}", .{ result.len, result });
}

// TEST CASES
// Existing StringBuilder and main are above...

test "StringBuilder.init is empty" {
    var sb = StringBuilder.init(testing.allocator);
    defer sb.deinit();

    try testing.expectEqual(@as(usize, 0), sb.len);
    try testing.expectEqual(@as(usize, 0), sb.toSlice().len);
    try testing.expectEqualStrings("", sb.toSlice());
}

test "StringBuilder.appendSlice appends simple strings" {
    var sb = StringBuilder.init(testing.allocator);
    defer sb.deinit();

    try sb.appendSlice("Hello");
    try testing.expectEqualStrings("Hello", sb.toSlice());

    try sb.appendSlice(", Zig");
    try testing.expectEqualStrings("Hello, Zig", sb.toSlice());
}

test "StringBuilder.appendByte appends single characters" {
    var sb = StringBuilder.init(testing.allocator);
    defer sb.deinit();

    try sb.appendSlice("Hi");
    try sb.appendByte('!');
    try sb.appendByte('\n');

    try testing.expectEqualStrings("Hi!\n", sb.toSlice());
}

test "StringBuilder.appendFmt formats into builder" {
    var sb = StringBuilder.init(testing.allocator);
    defer sb.deinit();

    try sb.appendSlice("Sum = ");
    try sb.appendFmt("{d}", .{2 + 3});

    try testing.expectEqualStrings("Sum = 5", sb.toSlice());
}

test "StringBuilder.clear resets len but keeps capacity" {
    var sb = try StringBuilder.initWithCapacity(testing.allocator, 32);
    defer sb.deinit();

    try sb.appendSlice("Hello");
    try testing.expectEqualStrings("Hello", sb.toSlice());

    const cap_before = sb.buf.len;

    sb.clear();

    try testing.expectEqual(@as(usize, 0), sb.len);
    try testing.expectEqual(@as(usize, 0), sb.toSlice().len);
    try testing.expectEqual(cap_before, sb.buf.len);
}

test "StringBuilder grows capacity when needed" {
    var sb = try StringBuilder.initWithCapacity(testing.allocator, 4);
    defer sb.deinit();

    const long = "This is longer than four bytes";
    try sb.appendSlice(long);

    // Capacity must be at least the current length.
    try testing.expect(sb.buf.len >= sb.len);
    try testing.expectEqualStrings(long, sb.toSlice());
}

test "StringBuilder.appendSentinelTerminated works with [:0]const u8" {
    var sb = StringBuilder.init(testing.allocator);
    defer sb.deinit();

    const msg: [:0]const u8 = "Hi";
    try sb.appendSentinelTerminated(msg);

    try testing.expectEqualStrings("Hi", sb.toSlice());
}
