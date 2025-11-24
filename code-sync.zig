const std = @import("std");

//
// join2: Small helper to join two path segments.
//
// Why this exists:
// std.fs.path.join() expects a slice of slices: []const []const u8
// Constructing that inline with &[_][]const u8{ a, b } is verbose.
//
fn join2(
    allocator: std.mem.Allocator,
    a: []const u8,
    b: []const u8,
) ![]u8 {
    return std.fs.path.join(allocator, &[_][]const u8{ a, b });
}

//
// Recursively walk the source directory (`src_dir`)
// and mirror the structure into the output directory (`out_dir`).
//
// For each `.md` file found, process it using processFile().
// For each directory, recurse into it.
//
fn processDirectory(
    cwd: *std.fs.Dir,
    allocator: std.mem.Allocator,
    src_dir: []const u8,
    out_dir: []const u8,
) !void {
    // Ensure output directory exists (ignore "already exists")
    cwd.makeDir(out_dir) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };

    // Open the directory we are scanning
    var dir = try cwd.openDir(src_dir, .{ .iterate = true });
    defer dir.close();

    var it = dir.iterate();
    while (try it.next()) |entry| {
        const name = entry.name;
        std.debug.print("Name: {s}\n", .{name});

        switch (entry.kind) {
            .file => {
                // Only process Markdown files
                if (std.mem.endsWith(u8, name, ".md")) {
                    try processFile(cwd, allocator, src_dir, out_dir, name);
                }
            },
            .directory => {
                // Skip "." and ".." entries
                if (std.mem.eql(u8, name, ".") or std.mem.eql(u8, name, ".."))
                    continue;

                // Build src_dir/name and out_dir/name
                const new_src = try join2(allocator, src_dir, name);
                defer allocator.free(new_src);

                const new_out = try join2(allocator, out_dir, name);
                defer allocator.free(new_out);

                // Recurse into the subdirectory
                try processDirectory(cwd, allocator, new_src, new_out);
            },
            else => {}, // Ignore symbolic links, devices, etc.
        }
    }
}

//
// Process a single Markdown file.
// - Reads the entire file into memory
// - Calls injectCode() to replace ```zig file=...``` markers
// - Writes updated content to the output folder
//
fn processFile(
    cwd: *std.fs.Dir,
    allocator: std.mem.Allocator,
    src_dir: []const u8,
    out_dir: []const u8,
    file_name: []const u8,
) !void {
    // Debug log: helpful when tracking file transformations
    std.debug.print("PROCESS {s}\\{s} -> {s}\\{s}\n", .{ src_dir, file_name, out_dir, file_name });

    // Build full input path = src_dir + file_name
    const src_path = try join2(allocator, src_dir, file_name);
    defer allocator.free(src_path);

    // Open the Markdown file
    var in_file = try cwd.openFile(src_path, .{ .mode = .read_only });
    defer in_file.close();

    // Read entire markdown content into memory (max 20 MB)
    const max_size = 20 * 1024 * 1024;
    const content = try in_file.readToEndAlloc(allocator, max_size);
    defer allocator.free(content);

    // Transform Markdown by injecting Zig code blocks
    // `src_dir` is passed as base_dir to resolve relative file paths
    const processed = try injectCode(allocator, content, src_dir);
    defer allocator.free(processed);

    // Build full output path = out_dir + file_name
    const out_path = try join2(allocator, out_dir, file_name);
    defer allocator.free(out_path);

    // Ensure destination directory exists
    cwd.makeDir(out_dir) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };

    // Create/truncate output file
    var out_file = try cwd.createFile(out_path, .{ .truncate = true });
    defer out_file.close();

    // Write transformed Markdown
    try out_file.writeAll(processed);
    std.debug.print("✔ Wrote {s}\n", .{out_path});
}

//
// injectCode:
// Scan a Markdown buffer, replacing specially-formatted markers:
//
//     ```zig file=path/to/code.zig
//     ```
//
// with the actual contents of the Zig file.
//
// This function outputs the transformed Markdown as a new allocated buffer.
//
fn injectCode(
    allocator: std.mem.Allocator,
    input: []const u8,
    base_dir: []const u8, // directory containing the .md file
) ![]u8 {
    // Unmanaged ArrayList in Zig 0.15.x
    // We manually feed allocator into appendSlice(), append(), etc.
    var out: std.ArrayList(u8) = .{};
    const marker = "```zig file=";
    const close = "```";

    var index: usize = 0;

    while (true) {
        // Find the next marker in the Markdown text
        const m_opt = std.mem.indexOfPos(u8, input, index, marker);
        if (m_opt == null) break; // no more markers → exit loop

        const m = m_opt.?;

        // Copy everything before the marker directly to output
        try out.appendSlice(allocator, input[index..m]);

        const after = m + marker.len;

        // Find the closing triple-backtick after the marker
        const close_opt = std.mem.indexOfPos(u8, input, after, close);
        if (close_opt == null) return error.MalformedIncludeDirective;

        const close_index = close_opt.?;

        // Extract the file path between marker and closing ```
        var rel_path = input[after..close_index];
        // Trim whitespace, tabs, newlines
        rel_path = std.mem.trim(u8, rel_path, " \t\r\n");

        // Build full absolute/relative path to the Zig file
        // - base_dir is path of the .md file (e.g., book/part-01)
        // - rel_path is something like "../../code/part-01/example.zig"
        const full_path = try join2(allocator, base_dir, rel_path);
        defer allocator.free(full_path);

        // Open the Zig code file
        var code_file = try std.fs.cwd().openFile(full_path, .{ .mode = .read_only });
        defer code_file.close();

        // Read Zig code contents (max 10 MB)
        const max_code_size = 10 * 1024 * 1024;
        const code = try code_file.readToEndAlloc(allocator, max_code_size);
        defer allocator.free(code);

        // Insert clean, fenced Markdown code block
        try out.appendSlice(allocator, "```zig\n");
        try out.appendSlice(allocator, code);

        // Ensure trailing newline (Markdown code blocks prefer this)
        if (code.len == 0 or code[code.len - 1] != '\n') {
            try out.append(allocator, '\n');
        }

        try out.appendSlice(allocator, "```");

        // Move cursor forward after the closing ```
        index = close_index + close.len;
    }

    // Append remaining Markdown text after last marker
    try out.appendSlice(allocator, input[index..]);

    // Convert ArrayList buffer → owned slice
    return out.toOwnedSlice(allocator);
}

//
// Program entry point:
// Loads args, validates them, and starts directory processing.
//
pub fn main() !void {
    // GeneralPurposeAllocator is good for CLI tools
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 3) {
        std.debug.print(
            "Usage: {s} <srcDir> <outDir>\n" ++
                "Example:\n  {s} book/part-01 out/part-01\n  {s} book out\n",
            .{ args[0], args[0], args[0] },
        );
        return;
    }

    const src_root = args[1];
    const out_root = args[2];

    var cwd = std.fs.cwd();

    // Ensure destination root exists
    cwd.makeDir(out_root) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };

    // Begin recursive directory processing
    try processDirectory(&cwd, allocator, src_root, out_root);
}
