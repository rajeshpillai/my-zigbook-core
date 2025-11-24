## 7. ARRAYS, SLICES & STRINGS — Welcome to Zig’s Real Identity

If pointers make you feel like a systems programmer,
arrays and slices are where you become one.

- JavaScript developers treat arrays like expandable rubber buckets.
- Python developers treat lists like bags of holding (infinite space).
- Go developers think make([]T, n) is low-level.
- Rust devs… yeah, they know pain.

Zig says:

- Arrays are fixed-size.
- Slices are views.
- Strings are just bytes.
- Nothing resizes itself.
- You resize it — explicitly.

This chapter is where Zig's simplicity starts to feel magical.


## 7.1 Arrays — Real Arrays, Not JS Fake Ones

Arrays in Zig have:

- fixed size
- contiguous memory
- no dynamic resizing
- no push() / pop() magic

Syntax:

```zig
[N]T
```

## Meaning of [T]n

[N]T  means:  “An array of n elements, each of type T”

- N is compile-time-known
- T is the element type


Examples:

```zig
var nums: [4]i32 = .{ 10, 20, 30, 40 };
```

Inferred-length array

```zig
var nums = [_]i32{ 10, 20, 30, 40 };

```

[_] tells Zig: “count this for me”.

Equivalent to [4]i32.


## 7.2 Arrays Own Their Memory

Arrays in Zig:

- store data inline
- have fixed size
- are value types
- are deep-copied

Source code: code/07.2-arrays-copy.zig

```zig
const std = @import("std");

pub fn main() void {
    const a = [_]i32{ 1, 2, 3 };
    var b = a; // deep copy

    b[0] = 999;

    std.debug.print("a = {any}\n", .{a});
    std.debug.print("b = {any}\n", .{b});
}

```

Output:

```
a = { 1, 2, 3 }
b = { 999, 2, 3 }
```

## 7.3 Indexing & Mutating Arrays

```zig
var nums = [_]i32{ 10, 20, 30, 40 };
nums[2] = 999;
```

Array indexing is bounds-checked by default.


## 7.4 Slices — Zig’s Superpower Type

Slices in Zig have type:
```zig
[]T
```

Internally, a slice is literally a struct:

```zig
struct {
    ptr: [*]T,   // many-pointer
    len: usize,  // length
}
```

So a slice is a view into memory — it does not own memory.

**Creating a slice from an array**

07.4-slices-basic.zig


```zig
const std = @import("std");

pub fn main() void {
    var arr = [_]i32{ 10, 20, 30, 40 };

    const mid = arr[1..3];
    std.debug.print("slice len = {d}\n", .{mid.len});
    std.debug.print("slice = {any}\n", .{mid});
}

```

Output:

```
slice len = 2
slice = { 20, 30 }
```

## 7.5 Slices Mutate Original Data

Because slices are “views”, modifying them modified the array.

```zig
var arr = [_]i32{ 10, 20, 30 };
var s = arr[0..2];

s[1] = 555;

std.debug.print("{any} {any}\n", .{s, arr});
```

Output:

```
{ 10, 555 } { 10, 555, 30 }

```

## 7.6 Arrays vs Slices (Visual Diagram

```
arr ──▶ [ 10 | 20 | 30 | 40 ]
           ↑      ↑
           │       └── slice end
           └──────── slice start

slice = arr[1..3]
slice.ptr = &arr[1]
slice.len = 2

```

>start = inclusive  
end   = exclusive

- Arrays own memory.
- Slices just point into memory.


## 7.7 Converting Arrays ↔ Slices
Array → Slice

```zig
const s = arr[0..]; // whole array
```

Slice → Many-pointer (for pointer arithmetic)

```zig
var p_many: [*]i32 = s.ptr;
p_many += 1;    // now pointing at s[1]
```

Array → Pointer

```zig
const first: *i32 = &arr[0];
```

## 7.8 Sentinel-Terminated Arrays — [N:s]T

Syntax:

```zig
[N:s] T
```

This means

"A fixed-size array of length N, whose last element has sentinel value s.”

Example:

```zig
var arr: [5:0]u8 = .{ 'H', 'e', 'l', 'l', 0 };
```

This is:

an array of 5 bytes

the last element must be 0

compiler enforces it

✔ Zig validates the sentinel at compile time

```zig
var bad: [5:0]u8 = .{ 'H', 'i', 0, 0, 1 }; 
//                       ↑       ↑
//                 compiler error: last element is not 0
```

Sentinel arrays are mostly useful for:

- global constants
- static lookup tables
- fixed-size buffers where sentinel status matters
- compile-time code that needs guaranteed termination


## 7.9 Sentinel-Terminated Slices — [:s]T

Syntax:
```zig
[:s]T
```


This means:

“A slice whose underlying memory is guaranteed to be terminated by the sentinel s.”

Example (most common):

```zig
const msg: [:0]const u8 = "Hello\0";
```

This is a null-terminated UTF-8 string slice.

Zig guarantees this:

- memory starts at msg.ptr
- walking forward will eventually hit a 0
- iteration using sentinel-safe APIs is valid

✔ Why sentinel slices matter

They enable safe iteration without knowing length:

```zig
for (msg) |byte| {
    // loop stops automatically at sentinel 0
}
```

This matches C’s behavior for strings:

- C strings end in \0
- Zig can interop safely with them




