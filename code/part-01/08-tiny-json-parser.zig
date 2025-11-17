// Limitations:
// Only basic support

const std = @import("std");
const testing = std.testing;

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

        // Optional leading '-'
        if (self.peek()) |c| {
            if (c == '-') {
                self.pos += 1;
            }
        } else {
            return JsonError.UnexpectedEnd;
        }

        // At least one digit required
        var c_opt = self.peek() orelse return JsonError.UnexpectedEnd;
        if (!(c_opt >= '0' and c_opt <= '9')) {
            return JsonError.InvalidNumber;
        }

        // Integer part: one or more digits
        while (self.pos < self.input.len) {
            const c = self.input[self.pos];
            if (c >= '0' and c <= '9') {
                self.pos += 1;
            } else break;
        }

        var is_float = false;

        // Optional fractional part: '.' digits+
        if (self.pos < self.input.len and self.input[self.pos] == '.') {
            is_float = true;
            self.pos += 1;

            // Must have at least one digit after '.'
            c_opt = self.peek() orelse return JsonError.InvalidNumber;
            if (!(c_opt >= '0' and c_opt <= '9')) {
                return JsonError.InvalidNumber;
            }

            while (self.pos < self.input.len) {
                const c = self.input[self.pos];
                if (c >= '0' and c <= '9') {
                    self.pos += 1;
                } else break;
            }
        }

        // Optional exponent: ('e' | 'E') ['+' | '-'] digits+
        if (self.pos < self.input.len) {
            const c = self.input[self.pos];
            if (c == 'e' or c == 'E') {
                is_float = true;
                self.pos += 1;

                // Optional sign in exponent
                if (self.pos < self.input.len) {
                    const sign_c = self.input[self.pos];
                    if (sign_c == '+' or sign_c == '-') {
                        self.pos += 1;
                    }
                } else {
                    return JsonError.UnexpectedEnd;
                }

                // At least one exponent digit required
                c_opt = self.peek() orelse return JsonError.InvalidNumber;
                if (!(c_opt >= '0' and c_opt <= '9')) {
                    return JsonError.InvalidNumber;
                }

                while (self.pos < self.input.len) {
                    const d = self.input[self.pos];
                    if (d >= '0' and d <= '9') {
                        self.pos += 1;
                    } else break;
                }
            }
        }

        const slice = self.input[start..self.pos];

        var value: f64 = 0;

        if (is_float) {
            // Use std.fmt.parseFloat for full float/exponent handling.
            value = std.fmt.parseFloat(f64, slice) catch {
                return JsonError.InvalidNumber;
            };
        } else {
            // Integer-only path (what we had earlier), but stored into f64.
            var sign: i64 = 1;
            var idx: usize = 0;

            if (slice[0] == '-') {
                sign = -1;
                idx = 1;
            }

            var acc: i64 = 0;
            while (idx < slice.len) : (idx += 1) {
                const d = slice[idx] - '0';
                acc = acc * 10 + @as(i64, d);
            }

            const signed_val: i64 = sign * acc;
            value = @floatFromInt(signed_val);
        }

        const node = try self.allocator.create(JsonValue);
        node.* = .{ .number = value };
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
        \\  "version": 0.2,
        \\  "is_cool": true,
        \\  "tags": ["systems", "safe", "manual"],
        \\  "misc": { "null_example": null, "nested": {"a": 1,"b": 2} }
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

// TEST CASES

test "parse null" {
    var buf: [1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    const alloc = fba.allocator();

    var parser = Parser.init(alloc, "null");
    const root = try parser.parse();
    try testing.expect(root.* == .null);
}

test "parse booleans true/false" {
    // true
    {
        var buf: [1024]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        const alloc = fba.allocator();

        var parser = Parser.init(alloc, "true");
        const root = try parser.parse();

        try testing.expect(root.* == .bool);
        try testing.expectEqual(@as(bool, true), root.bool);
    }

    // false
    {
        var buf: [1024]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        const alloc = fba.allocator();

        var parser = Parser.init(alloc, "false");
        const root = try parser.parse();

        try testing.expect(root.* == .bool);
        try testing.expectEqual(@as(bool, false), root.bool);
    }
}

test "parse integer number" {
    var buf: [1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    const alloc = fba.allocator();

    var parser = Parser.init(alloc, "123");
    const root = try parser.parse();

    try testing.expect(root.* == .number);
    try testing.expectEqual(@as(f64, 123), root.number);
}

test "parse negative number" {
    var buf: [1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    const alloc = fba.allocator();

    var parser = Parser.init(alloc, "-42");
    const root = try parser.parse();

    try testing.expect(root.* == .number);
    try testing.expectEqual(@as(f64, -42), root.number);
}

test "parse simple string" {
    var buf: [1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    const alloc = fba.allocator();

    var parser = Parser.init(alloc, "\"hello\"");
    const root = try parser.parse();

    try testing.expect(root.* == .string);
    try testing.expectEqualStrings("hello", root.string);
}

test "parse array of numbers" {
    var buf: [2048]u8 = undefined; // a bit more for arrays
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    const alloc = fba.allocator();

    var parser = Parser.init(alloc, "[1, 2, 3]");
    const root = try parser.parse();

    try testing.expect(root.* == .array);

    const arr = root.array;
    try testing.expectEqual(@as(usize, 3), arr.len);

    try testing.expect(arr[0].* == .number);
    try testing.expect(arr[1].* == .number);
    try testing.expect(arr[2].* == .number);

    try testing.expectEqual(@as(f64, 1), arr[0].number);
    try testing.expectEqual(@as(f64, 2), arr[1].number);
    try testing.expectEqual(@as(f64, 3), arr[2].number);
}

test "parse empty array" {
    var buf: [1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    const alloc = fba.allocator();

    var parser = Parser.init(alloc, "[]");
    const root = try parser.parse();

    try testing.expect(root.* == .array);
    try testing.expectEqual(@as(usize, 0), root.array.len);
}

test "parse simple object" {
    const json =
        \\{
        \\  "name": "Zig",
        \\  "version": 0,
        \\  "is_cool": true
        \\}
    ;

    var buf: [4096]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    const alloc = fba.allocator();

    var parser = Parser.init(alloc, json);
    const root = try parser.parse();

    try testing.expect(root.* == .object);

    const obj = root.object;
    try testing.expectEqual(@as(usize, 3), obj.len);

    // name
    try testing.expectEqualStrings("name", obj[0].key);
    try testing.expect(obj[0].value.* == .string);
    try testing.expectEqualStrings("Zig", obj[0].value.string);

    // version
    try testing.expectEqualStrings("version", obj[1].key);
    try testing.expect(obj[1].value.* == .number);
    try testing.expectEqual(@as(f64, 0), obj[1].value.number);

    // is_cool
    try testing.expectEqualStrings("is_cool", obj[2].key);
    try testing.expect(obj[2].value.* == .bool);
    try testing.expectEqual(@as(bool, true), obj[2].value.bool);
}

test "parse nested object with array" {
    const json =
        \\{
        \\  "tags": ["systems", "safe", "manual"],
        \\  "meta": { "null_example": null }
        \\}
    ;

    var buf: [4096]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    const alloc = fba.allocator();

    var parser = Parser.init(alloc, json);
    const root = try parser.parse();

    try testing.expect(root.* == .object);

    const obj = root.object;
    try testing.expectEqual(@as(usize, 2), obj.len);

    // tags
    try testing.expectEqualStrings("tags", obj[0].key);
    try testing.expect(obj[0].value.* == .array);

    const tags = obj[0].value.array;
    try testing.expectEqual(@as(usize, 3), tags.len);

    try testing.expect(tags[0].* == .string);
    try testing.expect(tags[1].* == .string);
    try testing.expect(tags[2].* == .string);

    try testing.expectEqualStrings("systems", tags[0].string);
    try testing.expectEqualStrings("safe", tags[1].string);
    try testing.expectEqualStrings("manual", tags[2].string);

    // meta.null_example
    try testing.expectEqualStrings("meta", obj[1].key);
    try testing.expect(obj[1].value.* == .object);

    const meta = obj[1].value.object;
    try testing.expectEqual(@as(usize, 1), meta.len);
    try testing.expectEqualStrings("null_example", meta[0].key);
    try testing.expect(meta[0].value.* == .null);
}

test "parse simple float 3.14" {
    var buf: [1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    const alloc = fba.allocator();

    var parser = Parser.init(alloc, "3.14");
    const root = try parser.parse();

    try testing.expect(root.* == .number);
    try testing.expectApproxEqAbs(@as(f64, 3.14), root.number, 1e-9);
}

test "parse float with leading minus -0.5" {
    var buf: [1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    const alloc = fba.allocator();

    var parser = Parser.init(alloc, "-0.5");
    const root = try parser.parse();

    try testing.expect(root.* == .number);
    try testing.expectApproxEqAbs(@as(f64, -0.5), root.number, 1e-9);
}

test "parse number with exponent 1e3" {
    var buf: [1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    const alloc = fba.allocator();

    var parser = Parser.init(alloc, "1e3");
    const root = try parser.parse();

    try testing.expect(root.* == .number);
    try testing.expectApproxEqAbs(@as(f64, 1000), root.number, 1e-9);
}

test "parse float with exponent 6.02e23" {
    var buf: [1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    const alloc = fba.allocator();

    var parser = Parser.init(alloc, "6.02e23");
    const root = try parser.parse();

    try testing.expect(root.* == .number);
    try testing.expect(root.number > 1e23);
}
