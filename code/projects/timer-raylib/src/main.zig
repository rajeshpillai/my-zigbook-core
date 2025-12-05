const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
});

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

    var total_seconds: u64 = 5; // Default

    if (args.len > 1) {
        total_seconds = parseDurationToSeconds(args[1]) catch 5;
    }

    const screenWidth = 800;
    const screenHeight = 450;

    rl.InitWindow(screenWidth, screenHeight, "Zig Timer");
    defer rl.CloseWindow();

    rl.SetTargetFPS(60);

    var remaining_time: f64 = @floatFromInt(total_seconds);

    while (!rl.WindowShouldClose()) {
        const delta = rl.GetFrameTime();
        if (remaining_time > 0) {
            remaining_time -= delta;
            if (remaining_time < 0) remaining_time = 0;
        }

        rl.BeginDrawing();
        defer rl.EndDrawing();

        rl.ClearBackground(rl.RAYWHITE);

        var buf: [64]u8 = undefined;
        var time_str: []const u8 = "";

        const r_int: u64 = @intFromFloat(@ceil(remaining_time));
        const m = r_int / 60;
        const s = r_int % 60;

        // Use sentinel terminated slice for C string if needed,
        // but Raylib usually takes [*:0]const u8.
        // bufPrint returns []u8 (slice). We need to ensure null termination if we pass pointer.
        // Or assume buf has space.
        // Safe way: `try std.fmt.bufPrintZ`

        if (remaining_time <= 0) {
            time_str = try std.fmt.bufPrintZ(&buf, "DONE!", .{});
        } else {
            if (m > 0) {
                time_str = try std.fmt.bufPrintZ(&buf, "{d:0>2}:{d:0>2}", .{ m, s });
            } else {
                time_str = try std.fmt.bufPrintZ(&buf, "{d}", .{s});
            }
        }

        const fontSize = 100;
        const textWidth = rl.MeasureText(time_str.ptr, fontSize);
        const posX = @divFloor(screenWidth - textWidth, 2);
        const posY = @divFloor(screenHeight - fontSize, 2);

        var color = rl.DARKGRAY;
        if (r_int <= 10 and r_int > 0) color = rl.RED;
        if (r_int == 0) color = rl.GREEN;

        rl.DrawText(time_str.ptr, posX, posY, fontSize, color);
    }
}
