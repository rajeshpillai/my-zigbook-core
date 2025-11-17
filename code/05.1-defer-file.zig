const std = @import("std");

fn demoFileDefer() !void {
    std.debug.print("--- demoFileDefer ---\n", .{});

    // Get a handle to the current working directory.
    const cwd = std.fs.cwd();

    // Create (or truncate) a file for writing.
    var file = try cwd.createFile("output/defer-demo.txt", .{});
    // Ensure the file is closed when this function returns,
    // whether it returns successfully or with an error.
    defer file.close();

    // Write some bytes into the file.
    try file.writeAll("Hello from defer demo!\n");

    std.debug.print("File written. It will be closed automatically by defer.\n", .{});
}

pub fn main() !void {
    try demoFileDefer();
}
