const std = @import("std");

// Helper function to join two strings
fn join2(
    allocator: std.mem.Allocator,
    a: []const u8,
    b: []const u8,
) ![]u8 {
    return std.fs.path.join(allocator, &[_][]const u8{ a, b });
}

fn processDirectory(cwd: *std.fs.Dir, allocator: std.mem.Allocator, src_dir: []const u8, out_dir: []const u8) !void {
    cwd.makeDir(out_dir) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };

    var dir = try cwd.openDir(src_dir, .{ .iterate = true });
    defer dir.close();

    var it = dir.iterate();
    while (try it.next()) |entry| {
        const name = entry.name;
        std.debug.print("Name: {s}\n", .{name});

        switch (entry.kind) {
            .file => {
                if (std.mem.endsWith(u8, name, ".md")) {
                    try processFile(cwd, allocator, src_dir, out_dir, name);
                }
            },
            .directory => {
                if (std.mem.eql(u8, name, ".") or std.mem.eql(u8, name, "..")) continue;

                const new_src = try join2(allocator, src_dir, name);
                defer allocator.free(new_src);

                const new_out = try join2(allocator, out_dir, name);
                defer allocator.free(new_out);

                try processDirectory(cwd, allocator, new_src, new_out);
            },
            else => {},
        }
    }
}

fn processFile(cwd: *std.fs.Dir, allocator: std.mem.Allocator, src_dir: []const u8, out_dir: []const u8, file_name: []const u8) !void {
    std.debug.print("PROCESS {s}\\{s} -> {s}\\{s}\n", .{ src_dir, file_name, out_dir, file_name });

    const src_path = try join2(allocator, src_dir, file_name);
    defer allocator.free(src_path);

    var in_file = try cwd.openFile(src_path, .{ .mode = .read_only });
    defer in_file.close();

    const max_size = 20 * 1024 * 1024;
    const content = try in_file.readToEndAlloc(allocator, max_size);
    defer allocator.free(content);

    const processed = try injectCode(allocator, content, src_dir);
    defer allocator.free(processed);

    const out_path = try join2(allocator, out_dir, file_name);
    defer allocator.free(out_path);

    cwd.makeDir(out_dir) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };

    var out_file = try cwd.createFile(out_path, .{ .truncate = true });
    defer out_file.close();

    try out_file.writeAll(processed);
    std.debug.print("✔ Wrote {s}\n", .{out_path});
}

fn injectCode(allocator: std.mem.Allocator, input: []const u8, base_dir: []const u8) ![]u8 {
    var out: std.ArrayList(u8) = .{};
    const marker = "```zig file=";
    const close = "```";

    var index: usize = 0;

    while (true) {
        const m_opt = std.mem.indexOfPos(u8, input, index, marker);
        if (m_opt == null) break;

        const m = m_opt.?;
        try out.appendSlice(allocator, input[index..m]);

        const after = m + marker.len;

        const close_opt = std.mem.indexOfPos(u8, input, after, close);
        if (close_opt == null) return error.MalformedIncludeDirective;
        const close_index = close_opt.?;

        var rel_path = input[after..close_index];
        rel_path = std.mem.trim(u8, rel_path, " \t\r\n");

        const full_path = try join2(allocator, base_dir, rel_path);
        defer allocator.free(full_path);

        var code_file = try std.fs.cwd().openFile(full_path, .{ .mode = .read_only });
        defer code_file.close();

        const max_code_size = 10 * 1024 * 1024;
        const code = try code_file.readToEndAlloc(allocator, max_code_size);
        defer allocator.free(code);

        try out.appendSlice(allocator, "```zig\n");
        try out.appendSlice(allocator, code);
        if (code.len == 0 or code[code.len - 1] != '\n') {
            try out.append(allocator, '\n');
        }
        try out.appendSlice(allocator, "```");

        index = close_index + close.len;
    }

    try out.appendSlice(allocator, input[index..]);
    return out.toOwnedSlice(allocator);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 3) {
        std.debug.print(
            "Usage: {s} <srcDir> <outDir>\nExample:\n  {s} book/part-01 out/part-01\n  {s} book out\n",
            .{ args[0], args[0], args[0] },
        );
        return;
    }

    const src_root = args[1];
    const out_root = args[2];

    var cwd = std.fs.cwd();

    cwd.makeDir(out_root) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };

    try processDirectory(&cwd, allocator, src_root, out_root);
}
