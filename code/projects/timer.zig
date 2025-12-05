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

    var total_seconds: u64 = 5; // Default if no args, though we might want to enforce args or keep this default.
    // Let's enforce usage message if not provided, consistent with countdown.zig logic
    // but if the user wants "like 1s...", maybe a default is not what they want if they provided nothing.
    // Let's check args length.

    if (args.len > 1) {
        const duration_str = args[1];
        total_seconds = parseDurationToSeconds(duration_str) catch |err| {
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
    } else {
        print("Usage: {s} <duration>\n", .{args[0]});
        print("Examples: 10s, 1m, 1.5m, 2h\n", .{});
        return;
    }

    var remaining = total_seconds;

    // Clear the screen initially
    print("\x1b[2J", .{});

    // Hide cursor
    print("\x1b[?25l", .{});
    defer print("\x1b[?25h", .{}); // Show cursor on exit

    while (remaining > 0) : (remaining -= 1) {
        // Move to approximate center (row 12, col 40)
        // \x1b[H moves to 0,0. \x1b[<row>;<col>H moves to absolute position.
        print("\x1b[12;40H", .{});

        // Clear the line just in case remaining digits shrink (e.g. 10 -> 9)
        print("\x1b[K", .{});

        // Print the timer
        // We can format it nicely as HH:MM:SS or just seconds.
        // Let's do MM:SS for better readability if it's large, or just seconds if small?
        // Let's stick to simple seconds print as requested "starts a countdown", but maybe a bit nicer?

        const m = remaining / 60;
        const s = remaining % 60;

        if (m > 0) {
            print("{d:0>2}:{d:0>2}", .{ m, s });
        } else {
            print("{d}", .{s});
        }

        std.Thread.sleep(1_000_000_000); // 1 second
    }

    // Centered "Done!"
    print("\x1b[2J", .{}); // Clear screen again? or just overwrite?
    // Let's just print done in the center.
    print("\x1b[12;35H", .{}); // slightly shifted left for "Countdown complete!"?
    // "Countdown complete!" is 19 chars.
    // 40 - (19/2) = 31 approx.
    print("\x1b[12;31HCountdown complete!\n", .{});

    // Move cursor to bottom so prompt doesn't overwrite nicely
    print("\x1b[24;0H", .{});
}
