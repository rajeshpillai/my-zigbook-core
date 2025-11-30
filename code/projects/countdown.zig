const std = @import("std");
const print = std.debug.print;

/// Parse duration strings like:
/// "10s"  -> 10 seconds
/// "1m"   -> 60 seconds
/// "1.5m" -> 90 seconds
/// "2h"   -> 7200 seconds
pub fn parseDurationToSeconds(duration_str: []const u8) !u64 {
    if (duration_str.len == 0) return error.InvalidFormat;

    // Find where the unit starts (first non-digit, non-dot character)
    var unit_start: usize = duration_str.len;
    var i: usize = 0;
    while (i < duration_str.len) : (i += 1) {
        const c = duration_str[i];
        if (!((c >= '0' and c <= '9') or c == '.')) {
            unit_start = i;
            break;
        }
    }

    if (unit_start == 0) return error.InvalidFormat; // no numeric part

    const number_slice = duration_str[0..unit_start];
    const unit_slice: []const u8 =
        if (unit_start < duration_str.len) duration_str[unit_start..] else "s";

    // Parse the numeric part as float so "1.5m" works
    const number = try std.fmt.parseFloat(f64, number_slice);
    if (number <= 0) return error.InvalidFormat;

    // Decide multiplier based on unit
    var multiplier: f64 = 1.0;
    if (unit_slice.len > 0) {
        const u = unit_slice[0];
        if (u == 's') {
            multiplier = 1.0;
        } else if (u == 'm') {
            multiplier = 60.0;
        } else if (u == 'h') {
            multiplier = 3600.0;
        } else {
            return error.InvalidUnit;
        }
    }

    const total_seconds_f = number * multiplier;
    if (total_seconds_f < 1.0) return error.TooSmall;

    // In Zig 0.15.2 this builtin takes ONLY the float,
    // and the target int type is inferred from context.
    const total_seconds: u64 = @intFromFloat(total_seconds_f);
    return total_seconds;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len != 2) {
        print("Usage: {s} <duration>\n", .{args[0]});
        print("Examples: 10s, 1m, 1.5m, 2h\n", .{});
        return;
    }

    const duration_str = args[1];

    const total_seconds = parseDurationToSeconds(duration_str) catch |err| {
        switch (err) {
            error.InvalidFormat => {
                print("Invalid duration format: {s}\n", .{duration_str});
            },
            error.InvalidUnit => {
                print("Invalid unit in '{s}'. Use s, m, or h.\n", .{duration_str});
            },
            error.TooSmall => {
                print("Duration too small. Must be at least 1 second.\n", .{});
            },
            else => {
                print("Failed to parse duration: {s}\n", .{duration_str});
            },
        }
        return;
    };

    print("Starting countdown for {d} seconds ({s})\n", .{ total_seconds, duration_str });

    var remaining = total_seconds;
    while (remaining > 0) : (remaining -= 1) {
        print("{d}\n", .{remaining});
        std.Thread.sleep(1_000_000_000); // 1 second
    }

    print("Countdown complete!\n", .{});
}
