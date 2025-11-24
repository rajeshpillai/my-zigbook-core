# 6. Pointers - The Fun Part

(You've Survived the Type System. Now Welcome to the Real Zig.)

- If you're a JavaScript dev, you've probably lived your entire life pretending pointers don't exist.
- If you're a Python dev, the interpreter hides everything from you like a protective mother. 
- If you're a Go dev, you've met pointers, but Go keeps them on a child-safety leash.
- If you're a Rust dev… well, you already know trauma.

Zig?

Zig gives you raw pointers, constant pointers, nullable pointers, sentinel-terminated pointers, slices, many-pointers, c-pointers, address-of, pointer arithmetic, and manual memory allocations…

…and then tells you:

>"You are responsible.
 I trust you.
 Don't mess this up."

This section is where you go from "I'm learning Zig" → "Okay this is actually fun."

Let's go step-by-step.


## 6.1 The Absolute Basics: *T is "pointer to a T"
A pointer is just:
- the memory address of a value
- not the value itself

This simple playground will get us warmed up:

pointer-basic.zig

```zig
const std = @import("std");

pub fn main() void {
    var x: i32 = 42;

    // Normal value
    std.debug.print("x = {d}\n", .{x});

    // Pointer to x
    const p: *i32 = &x; // & = "address-of"

    std.debug.print("pointer p points to address: {*}\n", .{p});
    std.debug.print("value at pointer p = {d}\n", .{p.*});
}
```

The output of the above program will be

```
x = 42
pointer p points to address: 0x7ffee1a3c5ac  (example)
value at pointer p = 42
```

Key ideas:
- &x = "give me the address of x"
- *i32 = "pointer to an i32"
- p.* = "dereference the pointer", i.e., "give me the value at that address"

## 6.2 Pointers Are References. Mutating Through Them Mutates the Original
Pointers aren't copies - they refer to the same location.

Try this:
pointer-mut.zig

```zig 
const std = @import("std");

pub fn main() void {
    var x: i32 = 10;
    const p: *i32 = &x;

    std.debug.print("Before: x = {d}\n", .{x});

    // Modify through pointer
    p.* = 999;

    std.debug.print("After: x = {d}\n", .{x});
}

```

The output will be

```
Before: x = 10
After: x = 999
```

6.3 Const Pointers vs Mutable Pointers
Zig separates two ideas:

- The pointed-to value may be mutable or const
- The pointer itself may be mutable or const

Let's demonstrate:


Pointer to mutable value:
```
* i32         // can mutate the pointed-to value
```

Pointer to const value:
```
* const i32   // cannot mutate the pointed-to value
```

Const pointer itself:
```
const p = &x;   // pointer cannot be reassigned
```

Full example - pointer-const.zig

```zig
const std = @import("std");

pub fn main() void {
    var x: i32 = 50;

    // Pointer to const value: cannot modify x through this pointer.
    const p_const_value: *const i32 = &x;

    // Pointer itself is const (cannot be reassigned),
    // but the value it points to (x) IS mutable.
    const p_const_pointer: *i32 = &x;

    std.debug.print("x initially = {d}\n", .{x});

    // Reading through a const pointer is allowed:
    std.debug.print("Reading through p_const_value: {d}\n", .{p_const_value.*});

    // Mutate x directly (valid)
    x = 999;

    std.debug.print("x after direct mutation = {d}\n", .{x});

    // ❌ This would NOT compile:
    // p_const_value.* = 123;   // cannot assign, value is const

    // ❌ This would NOT compile:
    // p_const_pointer = &x;    // cannot reassign const pointer

    // Both pointers still see the updated value:
    std.debug.print("p_const_value now reads = {d}\n", .{p_const_value.*});
    std.debug.print("p_const_pointer now reads = {d}\n", .{p_const_pointer.*});
}

```

Output

```
x initially = 50
Reading through p_const_value: 50
x after direct mutation = 999    
p_const_value now reads = 999    
p_const_pointer now reads = 999
```

6.4 Nullable Pointers: ?*T
A pointer may or may not point to something.

```zig
var maybe: ?*i32 = null;

if (maybe == null) {
    std.debug.print("Pointer is null\n", .{});
}
```

Full code: pointer-null.zig

```zig
const std = @import("std");

// Return: either a pointer to a (const) i32, or null.
fn findPositive(ptr: *const i32) ?*const i32 {
    // Check the value that the pointer points to.
    if (ptr.* > 0) {
        return ptr; // not null
    }
    return null;
}

pub fn main() void {
    // These values are never mutated, so we use const.
    const a: i32 = 10;
    const b: i32 = -5;

    // Take their addresses (pointers to const i32).
    const pa: *const i32 = &a;
    const pb: *const i32 = &b;

    if (findPositive(pa)) |ptr| {
        // Inside this block, ptr is a non-null *const i32.
        std.debug.print("pa points to a positive value: {d}\n", .{ptr.*});
    }

    if (findPositive(pb) == null) {
        std.debug.print("pb does NOT point to a positive value\n", .{});
    }
}

```

Explanation:

```zig
if (findPositive(pa)) |ptr| {
 std.debug.print("pa points to a positive value: {d}\n", .{ptr.*});
}
```

This single line combines:
- calling a function that returns an optional pointer (?*const i32)
- checking whether it is null or non-null
- extracting (unwrapping) the pointer when non-null
- binding the unwrapped pointer to a new variable (ptr)
- executing the block only when it's not null


## 6.5 Pointer Arithmetic - Yes, You Can Do It (Carefully)
Zig (unlike Rust) allows pointer arithmetic:

```zig
p += 1;   // move pointer one element forward
p -= 1;
```

Full code: pointer-arithmetic.zig

```zig
const std = @import("std");

pub fn main() void {
    var arr = [_]i32{ 10, 20, 30 };

    // A normal single-item pointer (no pointer arithmetic on this):
    const p_single: *i32 = &arr[0];
    std.debug.print("p_single points to: {d}\n", .{p_single.*}); // 10

    // Get a slice over the whole array.
    const slice: []i32 = arr[0..];

    // A "many-pointer": pointer to multiple elements.
    // Slices in Zig have a .ptr field of type [*]T (many-pointer).
    var p_many: [*]i32 = slice.ptr;

    std.debug.print("p_many[0] = {d}\n", .{p_many[0]}); // 10

    // Pointer arithmetic: move one element forward (to arr[1]).
    p_many += 1;
    std.debug.print("p_many[0] = {d}\n", .{p_many[0]}); // 20

    // Move again (to arr[2]).
    p_many += 1;
    std.debug.print("p_many[0] = {d}\n", .{p_many[0]}); // 30
}

```

Output:

```
p_single points to: 10
p_many[0] = 10
p_many[0] = 20
p_many[0] = 30
```

If you want pointer arithmetic in Zig, get a slice first, then use slice.ptr to access the raw many-pointer.

In Zig, you don't get to casually do p += 1 on any pointer you like.

- *T (single pointer) → no pointer arithmetic
- [*]T (many-pointer) → pointer arithmetic allowed
- You usually get [ * ]T from a slice: slice.ptr


If you try:

```zig
var p: *i32 = &arr[0];
p += 1; // ❌ Zig: expected '*i32', found 'comptime_int'
```


Zig stops you.

If you really want raw pointer math, you must opt in explicitly:

```zig
const slice: []i32 = arr[0..];
var p_many: [*]i32 = slice.ptr;
p_many += 1; // ✅ points to the next element
```

>Slices are the everyday tool.

Many-pointers are the "I know what I'm doing, give me the sharp knife" tool.


## 6.6 Slices: "Pointer + Length = Safety"
Slices are Zig's safer, more pleasant pointer type:

Slices give you:
- a pointer ([*]T)
- a length (usize)


```zig
[] T          // slice of T (unknown length)
```

It stores:
- pointer to first element
- length
- (optionally: sentinel - explained later)

Example: 

```zig
var arr = [_]u8{ 1, 2, 3, 4 };
const s: []u8 = arr[1..3]; // slice 1..2
```

You already used slices in the type system section.

>Important: Slices are views, not copies.

## 6.7 Many-Pointers ([*]T)
A many-pointer is:

>"Here is a pointer that might point to many elements.
 You decide how many.
 No safety, no bounds checks."

Used when dealing with:
- pointer arithmetic
- raw memory
- C interop
- performance-critical loops

By default, don't use many-pointers unless you know why.

## 6.8 Sentinel-Terminated Pointers ([*:0]T)

For C-style strings:

```zig
[*:0]const u8   = pointer to null-terminated UTF-8 bytes
```

Example:
```zig
const cstr: [*:0]const u8 = "Hello\0";
```

This tells Zig:
- "Walk until you see a 0 byte."
- Useful for C interop and low-level code.

## 6.9 Combined Demo - The Ultimate Pointer Playground

code/pointer-demo.zig

```zig
const std = @import("std");

pub fn main() void {
    var nums = [_]i32{ 10, 20, 30, 40 };

    // Single pointer
    const p: *i32 = &nums[0];
    std.debug.print("p -> {d}\n", .{p.*});

    // Slice (safe)
    const mid: []i32 = nums[1..4];
    std.debug.print("slice = {any}\n", .{mid});

    // Many-pointer (pointer arithmetic)
    var p_many: [*]i32 = mid.ptr;
    std.debug.print("p_many[0] = {d}\n", .{p_many[0]});

    p_many += 1;
    std.debug.print("p_many[0] = {d}\n", .{p_many[0]});

    // Optional pointer
    const maybe: ?*const i32 = &nums[2];
    if (maybe) |ptr| {
        std.debug.print("maybe points to: {d}\n", .{ptr.*});
    }
}

```

Output:

```
p -> 10
slice = { 20, 30, 40 }     
p_many[0] = 20
p_many[0] = 30
maybe points to: 30
```

## 6.10 The Zig Pointer Philosophy
Zig makes you earn your power.

- If you want a safe view → use slices.
- If you want raw speed → use many-pointers.
- If you want to mutate through a pointer → the value must be mutable.
- If you want safety → Zig forces it at compile time.
- If you want sharp knives → Zig hands them to you with no training wheels.

By now, pointers should not scare you. They should excite you.


