const std = @import("std");
const print = std.debug.print;

// Font height: 5
const FONT_HEIGHT = 5;

// We'll use a simple struct to hold our character map
const BigChar = struct {
    lines: [FONT_HEIGHT][]const u8,
    width: usize,
};

// Define characters 0-9 and :
// Width mostly 7 chars
const DIGITS = [_]BigChar{
    // 0
    .{
        .lines = .{
            "  ###  ",
            " #   # ",
            " #   # ",
            " #   # ",
            "  ###  ",
        },
        .width = 7,
    },
    // 1
    .{
        .lines = .{
            "   #   ",
            "  ##   ",
            "   #   ",
            "   #   ",
            " ##### ",
        },
        .width = 7,
    },
    // 2
    .{
        .lines = .{
            " ##### ",
            "     # ",
            " ##### ",
            " #     ",
            " ##### ",
        },
        .width = 7,
    },
    // 3
    .{
        .lines = .{
            " ##### ",
            "     # ",
            " ##### ",
            "     # ",
            " ##### ",
        },
        .width = 7,
    },
    // 4
    .{
        .lines = .{
            " #   # ",
            " #   # ",
            " ##### ",
            "     # ",
            "     # ",
        },
        .width = 7,
    },
    // 5
    .{
        .lines = .{
            " ##### ",
            " #     ",
            " ##### ",
            "     # ",
            " ##### ",
        },
        .width = 7,
    },
    // 6
    .{
        .lines = .{
            " ##### ",
            " #     ",
            " ##### ",
            " #   # ",
            " ##### ",
        },
        .width = 7,
    },
    // 7
    .{
        .lines = .{
            " ##### ",
            "     # ",
            "    #  ",
            "   #   ",
            "   #   ",
        },
        .width = 7,
    },
    // 8
    .{
        .lines = .{
            " ##### ",
            " #   # ",
            " ##### ",
            " #   # ",
            " ##### ",
        },
        .width = 7,
    },
    // 9
    .{
        .lines = .{
            " ##### ",
            " #   # ",
            " ##### ",
            "     # ",
            " ##### ",
        },
        .width = 7,
    },
};

const COLON = BigChar{
    .lines = .{
        "   ",
        " # ",
        "   ",
        " # ",
        "   ",
    },
    .width = 3,
};

fn getBigChar(c: u8) ?BigChar {
    if (c >= '0' and c <= '9') {
        return DIGITS[c - '0'];
    }
    if (c == ':') {
        return COLON;
    }
    return null;
}

/// Print string in big font at specified row/col (top-left)
fn printBig(text: []const u8, start_row: usize, start_col: usize) void {
    var current_col = start_col;

    // We print line by line
    for (0..FONT_HEIGHT) |line_idx| {
        // Reset column for new line
        current_col = start_col;

        // Move cursor to start of this line
        print("\x1b[{d};{d}H", .{ start_row + line_idx, start_col });

        for (text) |char| {
            if (getBigChar(char)) |bc| {
                print("{s}", .{bc.lines[line_idx]});
                // Add 1 space padding
                print(" ", .{});
            } else {
                // Space or unknown
                print("       ", .{});
            }
        }
    }
}

fn measureTextWidth(text: []const u8) usize {
    var width: usize = 0;
    for (text) |char| {
        if (getBigChar(char)) |bc| {
            width += bc.width;
        } else {
            width += 7; // default space
        }
        // padding
        width += 1;
    }
    if (width > 0) width -= 1; // remove trailing padding
    return width;
}

/// Parse duration strings like usage in countdown.zig
pub fn parseDurationToSeconds(duration_str: []const u8) !u64 {
    if (duration_str.len == 0) return error.InvalidFormat;
    var unit_start: usize = duration_str.len;
    var i: usize = 0;
    while (i < duration_str.len) : (i += 1) {
        const c = duration_str[i];
        if (!((c >= '0' and c <= '9') or c == '.')) {
            unit_start = i;
            break;
        }
    }
    if (unit_start == 0) return error.InvalidFormat;
    const number_slice = duration_str[0..unit_start];
    const unit_slice: []const u8 =
        if (unit_start < duration_str.len) duration_str[unit_start..] else "s";
    const number = try std.fmt.parseFloat(f64, number_slice);
    if (number <= 0) return error.InvalidFormat;
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
    return @intFromFloat(total_seconds_f);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var total_seconds: u64 = 0;

    if (args.len > 1) {
        const duration_str = args[1];
        total_seconds = parseDurationToSeconds(duration_str) catch |err| {
            switch (err) {
                error.InvalidFormat => print("Invalid duration format: {s}\n", .{duration_str}),
                error.InvalidUnit => print("Invalid unit in '{s}'. Use s, m, or h.\n", .{duration_str}),
                error.TooSmall => print("Duration too small.\n", .{}),
                else => print("Failed to parse duration.\n", .{}),
            }
            return;
        };
    } else {
        print("Usage: {s} <duration>\nExamples: 10s, 1m\n", .{args[0]});
        return;
    }

    var remaining = total_seconds;

    // Clear screen
    print("\x1b[2J", .{});
    // Hide cursor
    print("\x1b[?25l", .{});
    defer print("\x1b[?25h", .{});

    // Assume 80x24 terminal for centering
    // Center Row = 12. Font Height = 5. Start Row = 12 - 2 = 10.
    const start_row = 10;

    var buf: [32]u8 = undefined;

    while (remaining > 0) : (remaining -= 1) {
        const m = remaining / 60;
        const s = remaining % 60;

        var time_str: []const u8 = undefined;
        if (m > 0) {
            time_str = try std.fmt.bufPrint(&buf, "{d:0>2}:{d:0>2}", .{ m, s });
        } else {
            time_str = try std.fmt.bufPrint(&buf, "{d}", .{s});
        }

        const width = measureTextWidth(time_str);
        // Center col = 40. Start col = 40 - width/2
        var start_col: usize = 1;
        if (width < 80) {
            start_col = 40 - (width / 2);
        }

        // Clear only the area we draw on or full screen?
        // Full screen clear is safer for shrinking digits
        print("\x1b[2J", .{});

        printBig(time_str, start_row, start_col);

        std.Thread.sleep(1_000_000_000);
    }

    print("\x1b[2J", .{});
    print("\x1b[12;31HCountdown complete!\n", .{});
    print("\x1b[24;0H", .{});
}
