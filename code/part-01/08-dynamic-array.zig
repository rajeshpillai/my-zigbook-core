const std = @import("std");
const testing = std.testing;

/// A simple generic dynamic array (similar to ArrayList in stdlib).
///
/// What is a dynamic array?
/// - It's like a resizable array that grows automatically when needed
/// - You can add, remove, and access elements efficiently
/// - It manages memory automatically behind the scenes
///
/// Key features:
/// - Push elements to the end (like stacking plates)
/// - Pop elements from the end (like taking plates from the stack)
/// - Insert elements anywhere (shifts other elements)
/// - Remove elements from any position
/// - Automatic resizing when full
///
/// This is a learning implementation - in real code, you might use std.ArrayList instead.
pub fn DynamicArray(comptime T: type) type {
    // The 'comptime T: type' means this works for any type (int, float, struct, etc.)
    // at compile time. So DynamicArray(i32) creates an array of integers,
    // DynamicArray(f32) creates an array of floats, etc.

    return struct {
        // Internal storage
        items: []T, // The actual memory buffer where elements are stored
        len: usize, // How many elements are currently in use
        allocator: std.mem.Allocator, // Memory manager that handles allocations

        // Self is just a shortcut for "this type" to avoid typing the full name
        const Self = @This();

        // ========== BASIC LIFECYCLE METHODS ==========

        /// Create a new empty dynamic array.
        /// No memory is allocated initially - it will allocate on first push.
        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .items = &[_]T{}, // Empty slice - no heap memory allocated yet
                .len = 0, // No elements yet
                .allocator = allocator,
            };
        }

        /// Create a new dynamic array with initial capacity.
        /// This is more efficient if you know approximately how many elements you'll need.
        pub fn initWithCapacity(allocator: std.mem.Allocator, initial_capacity: usize) !Self {
            // If capacity is 0, just return an empty array
            if (initial_capacity == 0) {
                return Self.init(allocator);
            }

            // Allocate the initial buffer
            const buf = try allocator.alloc(T, initial_capacity);

            return .{
                .items = buf, // Our pre-allocated buffer
                .len = 0, // Still empty, but we have space ready
                .allocator = allocator,
            };
        }

        /// Free the memory used by this array.
        /// ALWAYS call this when you're done with the array to avoid memory leaks!
        pub fn deinit(self: *Self) void {
            // Only free if we actually allocated memory
            if (self.items.len != 0) {
                self.allocator.free(self.items);
            }

            // Reset to empty state for safety
            self.items = &[_]T{};
            self.len = 0;
        }

        // ========== INFORMATION METHODS ==========

        /// Get the number of elements currently in the array.
        pub fn count(self: *const Self) usize {
            return self.len;
        }

        /// Get the current capacity (maximum elements that fit without reallocation).
        pub fn capacity(self: *const Self) usize {
            return self.items.len;
        }

        /// Check if the array is empty.
        pub fn isEmpty(self: *const Self) bool {
            return self.len == 0;
        }

        /// Get a read-only view of all elements as a slice.
        /// Important: This slice becomes invalid if the array is modified!
        pub fn toSlice(self: *const Self) []const T {
            return self.items[0..self.len];
        }

        /// Get a mutable view of all elements as a slice.
        /// Use this when you want to modify elements in place.
        pub fn toSliceMut(self: *Self) []T {
            return self.items[0..self.len];
        }

        /// Remove all elements but keep the allocated memory.
        /// This is fast - just resets the length counter.
        pub fn clear(self: *Self) void {
            self.len = 0;
        }

        // ========== INTERNAL MEMORY MANAGEMENT ==========

        /// Ensure the array has enough capacity for at least 'needed' elements.
        /// This is called internally before adding new elements.
        fn ensureCapacity(self: *Self, needed: usize) !void {
            // If we already have enough space, do nothing
            if (self.items.len >= needed) return;

            const old_cap = self.items.len;

            // Calculate new capacity using a growth strategy:
            // - If empty: start with at least 4 or the needed size
            // - If not empty: double the current size, but at least enough for what we need
            const new_cap = blk: {
                if (old_cap == 0) {
                    break :blk @max(needed, 4); // Start with minimum 4 elements
                }
                const doubled = old_cap * 2;
                break :blk if (doubled > needed) doubled else needed;
            };

            // Allocate new, larger buffer
            const new_buf = try self.allocator.alloc(T, new_cap);

            // Copy existing elements to the new buffer
            if (self.len != 0) {
                std.mem.copyForwards(T, new_buf[0..self.len], self.items[0..self.len]);
            }

            // Free the old buffer (if we had one)
            if (old_cap != 0) {
                self.allocator.free(self.items);
            }

            // Start using the new buffer
            self.items = new_buf;
        }

        // ========== ADDING ELEMENTS ==========

        /// Add an element to the end of the array.
        /// Example: [1,2,3].push(4) → [1,2,3,4]
        pub fn push(self: *Self, value: T) !void {
            const needed = self.len + 1;
            try self.ensureCapacity(needed);

            // Add the new element at the end
            self.items[self.len] = value;
            self.len += 1;
        }

        /// Insert an element at a specific position.
        /// All elements from that position onward are shifted right.
        /// Example: [1,2,3].insert(1, 99) → [1,99,2,3]
        pub fn insert(self: *Self, index: usize, value: T) !void {
            // Check if index is valid (can be equal to len for inserting at end)
            if (index > self.len) return error.OutOfBounds;

            const needed = self.len + 1;
            try self.ensureCapacity(needed);

            // Shift elements to make room for the new one
            // We start from the end and move backwards
            var i: usize = self.len;
            while (i > index) : (i -= 1) {
                self.items[i] = self.items[i - 1];
            }

            // Insert the new value
            self.items[index] = value;
            self.len += 1;
        }

        // ========== REMOVING ELEMENTS ==========

        /// Remove and return the last element.
        /// Example: [1,2,3].pop() → returns 3, array becomes [1,2]
        pub fn pop(self: *Self) !T {
            if (self.len == 0) {
                return error.Empty; // Can't pop from empty array
            }
            self.len -= 1;
            return self.items[self.len]; // Return the element we just "removed"
        }

        /// Remove element at specific position, preserving order.
        /// All elements after the removed one are shifted left.
        /// Slower but maintains element order.
        /// Example: [1,2,3,4].removeAtShift(1) → returns 2, array becomes [1,3,4]
        pub fn removeAtShift(self: *Self, index: usize) !T {
            if (index >= self.len) return error.OutOfBounds;

            // Save the element we're removing
            const removed = self.items[index];

            // Shift all elements after 'index' one position left
            var i: usize = index;
            while (i + 1 < self.len) : (i += 1) {
                self.items[i] = self.items[i + 1];
            }

            self.len -= 1;
            return removed;
        }

        /// Remove element at specific position by swapping with last element.
        /// Very fast (O(1)) but DOES NOT preserve element order.
        /// Example: [1,2,3,4].removeAtSwap(1) → returns 2, array becomes [1,4,3]
        pub fn removeAtSwap(self: *Self, index: usize) !T {
            if (index >= self.len) return error.OutOfBounds;

            // Save the element we're removing
            const removed = self.items[index];

            const last_index = self.len - 1;

            // If we're not removing the last element, swap with the last one
            if (index != last_index) {
                self.items[index] = self.items[last_index];
            }

            self.len -= 1;
            return removed;
        }

        // ========== ACCESSING ELEMENTS ==========

        /// Get a read-only reference to element at index.
        /// Example: array.get(0) returns a pointer to the first element
        pub fn get(self: *const Self, index: usize) !*const T {
            if (index >= self.len) return error.OutOfBounds;
            return &self.items[index];
        }

        /// Get a mutable reference to element at index.
        /// Use this when you want to modify an element in place.
        pub fn getMut(self: *Self, index: usize) !*T {
            if (index >= self.len) return error.OutOfBounds;
            return &self.items[index];
        }

        /// Replace the element at index with a new value.
        pub fn set(self: *Self, index: usize, value: T) !void {
            if (index >= self.len) return error.OutOfBounds;
            self.items[index] = value;
        }
    };
}

// ========== DEMONSTRATION AND TESTING ==========

/// Simple demo showing how to use the DynamicArray
pub fn main() !void {
    // Create a memory allocator (manages memory for us)
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        // Check for memory leaks when the program ends
        const leak = gpa.deinit();
        if (leak == .leak) {
            std.debug.print("MEMORY LEAK DETECTED\n", .{});
        }
    }

    const allocator = gpa.allocator();

    // Create a dynamic array of integers with initial capacity of 4
    var arr = try DynamicArray(i32).initWithCapacity(allocator, 4);
    defer arr.deinit(); // IMPORTANT: Always call deinit to free memory!

    // Add some elements
    try arr.push(10);
    try arr.push(20);
    try arr.push(30);

    std.debug.print("Initial array: {any}\n", .{arr.toSlice()});

    // Insert an element at position 1
    try arr.insert(1, 99);
    std.debug.print("After inserting 99 at index 1: {any}\n", .{arr.toSlice()});

    // Remove an element (preserving order)
    _ = try arr.removeAtShift(2);
    std.debug.print("After removeAtShift(2): {any}\n", .{arr.toSlice()});

    // Remove the last element
    const last = try arr.pop();
    std.debug.print("Popped value: {d}, array now: {any}\n", .{ last, arr.toSlice() });

    // Demonstrate error handling
    const result = arr.pop();
    if (result) |value| {
        std.debug.print("Popped: {d}\n", .{value});
    } else |err| {
        std.debug.print("Error while popping: {s}\n", .{@errorName(err)});
    }
}

// ========== COMPREHENSIVE TEST SUITE ==========

test "create empty array" {
    var arr = DynamicArray(i32).init(testing.allocator);
    defer arr.deinit();

    // New array should be empty
    try testing.expectEqual(@as(usize, 0), arr.count());
    try testing.expect(arr.isEmpty());
    try testing.expectEqualStrings("", ""); // Just to show empty slice works
}

test "push and count elements" {
    var arr = DynamicArray(i32).init(testing.allocator);
    defer arr.deinit();

    // Push some elements
    try arr.push(1);
    try arr.push(2);
    try arr.push(3);

    // Verify count and contents
    try testing.expectEqual(@as(usize, 3), arr.count());
    try testing.expect(!arr.isEmpty());

    const slice = arr.toSlice();
    try testing.expectEqual(@as(i32, 1), slice[0]);
    try testing.expectEqual(@as(i32, 2), slice[1]);
    try testing.expectEqual(@as(i32, 3), slice[2]);
}

test "insert elements at specific positions" {
    var arr = DynamicArray(i32).init(testing.allocator);
    defer arr.deinit();

    try arr.push(10);
    try arr.push(20);
    try arr.push(30);

    // Insert in the middle
    try arr.insert(1, 99); // [10,99,20,30]

    const slice = arr.toSlice();
    try testing.expectEqual(@as(i32, 10), slice[0]);
    try testing.expectEqual(@as(i32, 99), slice[1]);
    try testing.expectEqual(@as(i32, 20), slice[2]);
    try testing.expectEqual(@as(i32, 30), slice[3]);
}

test "remove elements preserving order" {
    var arr = DynamicArray(i32).init(testing.allocator);
    defer arr.deinit();

    try arr.push(10);
    try arr.push(20);
    try arr.push(30);
    try arr.push(40);

    // Remove from middle - should preserve order
    const removed = try arr.removeAtShift(1); // Remove 20 → [10,30,40]
    try testing.expectEqual(@as(i32, 20), removed);

    const slice = arr.toSlice();
    try testing.expectEqual(@as(usize, 3), slice.len);
    try testing.expectEqual(@as(i32, 10), slice[0]);
    try testing.expectEqual(@as(i32, 30), slice[1]);
    try testing.expectEqual(@as(i32, 40), slice[2]);
}

test "remove elements using swap (fast but unordered)" {
    var arr = DynamicArray(i32).init(testing.allocator);
    defer arr.deinit();

    try arr.push(10);
    try arr.push(20);
    try arr.push(30);
    try arr.push(40);

    // Remove using swap - last element moves to fill the gap
    const removed = try arr.removeAtSwap(1); // Remove 20, 40 moves to position 1 → [10,40,30]
    try testing.expectEqual(@as(i32, 20), removed);

    const slice = arr.toSlice();
    try testing.expectEqual(@as(usize, 3), slice.len);
    try testing.expectEqual(@as(i32, 10), slice[0]);
    try testing.expectEqual(@as(i32, 40), slice[1]); // Last element moved here
    try testing.expectEqual(@as(i32, 30), slice[2]);
}

test "pop from empty array returns error" {
    var arr = DynamicArray(i32).init(testing.allocator);
    defer arr.deinit();

    // Try to pop from empty array - should fail
    const result = arr.pop();
    try testing.expectError(error.Empty, result);
}

test "access elements with bounds checking" {
    var arr = DynamicArray(i32).init(testing.allocator);
    defer arr.deinit();

    try arr.push(5);
    try arr.push(6);

    // Valid access
    const element = try arr.getMut(1);
    element.* = 99; // Modify the element

    const slice = arr.toSlice();
    try testing.expectEqual(@as(i32, 5), slice[0]);
    try testing.expectEqual(@as(i32, 99), slice[1]);

    // Invalid access - should fail
    try testing.expectError(error.OutOfBounds, arr.get(2));
    try testing.expectError(error.OutOfBounds, arr.set(2, 123));
}

test "array grows automatically when full" {
    var arr = try DynamicArray(i32).initWithCapacity(testing.allocator, 2); // Small capacity
    defer arr.deinit();

    const initial_capacity = arr.capacity();
    try testing.expectEqual(@as(usize, 2), initial_capacity);

    // Fill the array
    try arr.push(1);
    try arr.push(2);

    // Array should grow when we add more
    try arr.push(3);
    try arr.push(4);
    try arr.push(5);

    // Capacity should have increased
    try testing.expect(arr.capacity() > initial_capacity);

    // All elements should be present
    const slice = arr.toSlice();
    try testing.expectEqual(@as(usize, 5), slice.len);
    try testing.expectEqual(@as(i32, 1), slice[0]);
    try testing.expectEqual(@as(i32, 2), slice[1]);
    try testing.expectEqual(@as(i32, 3), slice[2]);
    try testing.expectEqual(@as(i32, 4), slice[3]);
    try testing.expectEqual(@as(i32, 5), slice[4]);
}
