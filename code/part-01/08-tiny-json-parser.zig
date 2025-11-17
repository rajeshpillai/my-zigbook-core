const std = @import("std");

const JsonError = error{
    UnexpectedEnd,
    UnexpectedChar,
    InvalidLiteral,
    InvalidNumber,
    OutOfMemory, // include allocator error
};

const ObjectEntry = struct {
    key: []const u8,
    value: *JsonValue,
};

const JsonValue = union(enum) {
    null,
    bool: bool,
    number: f64,
    string: []const u8,
    array: []const *JsonValue,
    object: []const ObjectEntry,
};

const Parser = struct {
    input: []const u8,
    pos: usize,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, input: []const u8) Self {
        return .{
            .input = input,
            .pos = 0,
            .allocator = allocator,
        };
    }

    pub fn parse(self: *Self) JsonError!*JsonValue {
        self.skipWhitespace();
        const value = try self.parseValue();
        self.skipWhitespace();
        if (self.pos != self.input.len) {
            return JsonError.UnexpectedChar;
        }
        return value;
    }

    fn skipWhitespace(self: *Self) void {
        while (self.pos < self.input.len) {
            const c = self.input[self.pos];
            if (c == ' ' or c == '\n' or c == '\t' or c == '\r') {
                self.pos += 1;
            } else {
                break;
            }
        }
    }

    fn peek(self: *Self) ?u8 {
        if (self.pos >= self.input.len) return null;
        return self.input[self.pos];
    }

    fn consume(self: *Self, expected: u8) JsonError!void {
        if (self.pos >= self.input.len) return JsonError.UnexpectedEnd;
        const c = self.input[self.pos];
        if (c != expected) return JsonError.UnexpectedChar;
        self.pos += 1;
    }

    fn parseValue(self: *Self) JsonError!*JsonValue {
        self.skipWhitespace();
        const c_opt = self.peek() orelse return JsonError.UnexpectedEnd;
        return switch (c_opt) {
            'n' => self.parseNull(),
            't', 'f' => self.parseBool(),
            '"' => self.parseString(),
            '-', '0'...'9' => self.parseNumber(),
            '[' => self.parseArray(),
            '{' => self.parseObject(),
            else => JsonError.UnexpectedChar,
        };
    }

    fn parseNull(self: *Self) JsonError!*JsonValue {
        if (self.pos + 4 > self.input.len) return JsonError.UnexpectedEnd;
        if (!std.mem.eql(u8, self.input[self.pos .. self.pos + 4], "null")) {
            return JsonError.InvalidLiteral;
        }
        self.pos += 4;

        const node = try self.allocator.create(JsonValue);
        node.* = .null;
        return node;
    }

    fn parseBool(self: *Self) JsonError!*JsonValue {
        if (self.pos + 4 <= self.input.len and
            std.mem.eql(u8, self.input[self.pos .. self.pos + 4], "true"))
        {
            self.pos += 4;
            const node = try self.allocator.create(JsonValue);
            node.* = .{ .bool = true };
            return node;
        }

        if (self.pos + 5 <= self.input.len and
            std.mem.eql(u8, self.input[self.pos .. self.pos + 5], "false"))
        {
            self.pos += 5;
            const node = try self.allocator.create(JsonValue);
            node.* = .{ .bool = false };
            return node;
        }

        return JsonError.InvalidLiteral;
    }

    fn parseNumber(self: *Self) JsonError!*JsonValue {
        const start = self.pos;

        // Optional '-'
        if (self.peek()) |c| {
            if (c == '-') {
                self.pos += 1;
            }
        } else {
            return JsonError.UnexpectedEnd;
        }

        var has_digit = false;
        while (self.pos < self.input.len) {
            const c = self.input[self.pos];
            if (c >= '0' and c <= '9') {
                has_digit = true;
                self.pos += 1;
            } else break;
        }

        if (!has_digit) return JsonError.InvalidNumber;

        const slice = self.input[start..self.pos];

        // integer-only parse
        var sign: i64 = 1;
        var idx: usize = 0;

        if (slice[0] == '-') {
            sign = -1;
            idx = 1;
        }

        var value: i64 = 0;
        while (idx < slice.len) : (idx += 1) {
            const d = slice[idx] - '0';
            value = value * 10 + @as(i64, d);
        }

        const signed_val = value * sign;
        const f: f64 = @floatFromInt(signed_val);

        const node = try self.allocator.create(JsonValue);
        node.* = .{ .number = f };
        return node;
    }

    fn parseString(self: *Self) JsonError!*JsonValue {
        try self.consume('"');

        const start = self.pos;
        while (true) {
            if (self.pos >= self.input.len) return JsonError.UnexpectedEnd;
            const c = self.input[self.pos];
            if (c == '"') break;
            // no escape handling in this tiny parser
            self.pos += 1;
        }

        const s = self.input[start..self.pos];
        self.pos += 1; // closing quote

        const node = try self.allocator.create(JsonValue);
        node.* = .{ .string = s };
        return node;
    }

    fn parseArray(self: *Self) JsonError!*JsonValue {
        try self.consume('[');
        self.skipWhitespace();

        // Handle empty array: []
        const next = self.peek() orelse return JsonError.UnexpectedEnd;
        if (next == ']') {
            self.pos += 1;
            const node = try self.allocator.create(JsonValue);
            const empty: []const *JsonValue = &[_]*JsonValue{};
            node.* = .{ .array = empty };
            return node;
        }

        var cap: usize = 4;
        var buf = try self.allocator.alloc(*JsonValue, cap);
        var len: usize = 0;

        while (true) {
            const value = try self.parseValue();

            if (len == cap) {
                const new_cap = cap * 2;
                const new_buf = try self.allocator.alloc(*JsonValue, new_cap);
                if (len != 0) {
                    std.mem.copyForwards(*JsonValue, new_buf[0..len], buf[0..len]);
                }
                // with arena allocator, we can skip freeing old buf; all freed at once later
                buf = new_buf;
                cap = new_cap;
            }

            buf[len] = value;
            len += 1;

            self.skipWhitespace();
            const sep = self.peek() orelse return JsonError.UnexpectedEnd;
            if (sep == ',') {
                self.pos += 1;
                self.skipWhitespace();
                continue;
            } else if (sep == ']') {
                self.pos += 1;
                break;
            } else {
                return JsonError.UnexpectedChar;
            }
        }

        const slice = buf[0..len];
        const node = try self.allocator.create(JsonValue);
        node.* = .{ .array = slice };
        return node;
    }

    fn parseObject(self: *Self) JsonError!*JsonValue {
        try self.consume('{');
        self.skipWhitespace();

        // Handle empty object: {}
        const next = self.peek() orelse return JsonError.UnexpectedEnd;
        if (next == '}') {
            self.pos += 1;
            const node = try self.allocator.create(JsonValue);
            const empty: []const ObjectEntry = &[_]ObjectEntry{};
            node.* = .{ .object = empty };
            return node;
        }

        var cap: usize = 4;
        var buf = try self.allocator.alloc(ObjectEntry, cap);
        var len: usize = 0;

        while (true) {
            self.skipWhitespace();
            const key_val = try self.parseString();
            if (key_val.* != .string) return JsonError.UnexpectedChar;
            const key = key_val.string;

            self.skipWhitespace();
            try self.consume(':');

            const value = try self.parseValue();

            if (len == cap) {
                const new_cap = cap * 2;
                const new_buf = try self.allocator.alloc(ObjectEntry, new_cap);
                if (len != 0) {
                    std.mem.copyForwards(ObjectEntry, new_buf[0..len], buf[0..len]);
                }
                buf = new_buf;
                cap = new_cap;
            }

            buf[len] = .{ .key = key, .value = value };
            len += 1;

            self.skipWhitespace();
            const sep = self.peek() orelse return JsonError.UnexpectedEnd;
            if (sep == ',') {
                self.pos += 1;
                self.skipWhitespace();
                continue;
            } else if (sep == '}') {
                self.pos += 1;
                break;
            } else {
                return JsonError.UnexpectedChar;
            }
        }

        const slice = buf[0..len];
        const node = try self.allocator.create(JsonValue);
        node.* = .{ .object = slice };
        return node;
    }
};

fn printIndent(indent: usize) void {
    var i: usize = 0;
    while (i < indent) : (i += 1) {
        std.debug.print(" ", .{});
    }
}

fn printJson(value: *const JsonValue, indent: usize) void {
    switch (value.*) {
        .null => std.debug.print("null", .{}),
        .bool => |b| std.debug.print("{s}", .{if (b) "true" else "false"}),
        .number => |n| std.debug.print("{d}", .{n}),
        .string => |s| std.debug.print("\"{s}\"", .{s}),
        .array => |arr| {
            std.debug.print("[\n", .{});
            var i: usize = 0;
            while (i < arr.len) : (i += 1) {
                printIndent(indent + 2);
                printJson(arr[i], indent + 2);
                if (i + 1 < arr.len) std.debug.print(",", .{});
                std.debug.print("\n", .{});
            }
            printIndent(indent);
            std.debug.print("]", .{});
        },
        .object => |obj| {
            std.debug.print("{{\n", .{});
            var i: usize = 0;
            while (i < obj.len) : (i += 1) {
                printIndent(indent + 2);
                std.debug.print("\"{s}\": ", .{obj[i].key});
                printJson(obj[i].value, indent + 2);
                if (i + 1 < obj.len) std.debug.print(",", .{});
                std.debug.print("\n", .{});
            }
            printIndent(indent);
            std.debug.print("}}", .{});
        },
    }
}

/// Demo: parse a small JSON string using an arena-based parser.
pub fn main() !void {
    const json_text =
        \\{
        \\  "name": "Zig",
        \\  "version": 0,
        \\  "is_cool": true,
        \\  "tags": ["systems", "safe", "manual"],
        \\  "misc": { "null_example": null }
        \\}
    ;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leak = gpa.deinit();
        if (leak == .leak) {
            std.debug.print("MEMORY LEAK DETECTED\n", .{});
        }
    }

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit(); // frees all JsonValues and buffers at once

    const allocator = arena.allocator();

    var parser = Parser.init(allocator, json_text);
    const root = try parser.parse();

    std.debug.print("Parsed JSON:\n", .{});
    printJson(root, 0);
    std.debug.print("\n", .{});
}
