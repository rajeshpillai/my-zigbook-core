# 3. Zig Basics (But Not Boring)

Let's warm up.  Here's a tiny Zig program:
```zig
const std = @import("std");
pub fn main() void {
    std.debug.print("Hello, Zig!\n", .{});
}
```

Explanations:

std.debug is a namespace inside Zig's stdlib:
- std.debug.print
- std.debug.panic
- std.debug.assert
- std.debug.stackTrace

Beautiful -  Minimal. - No ceremony - No 58 imports - No magical runtime.

Zig always gives you:
- deterministic execution
- predictable cost
- explicit memory ownership

Like C, but without:
- UB landmines
- preprocessor drama
- header file nightmares
- crazy build chains
- "why did this pointer suddenly become a ghost?"


**"UB landmines" is a colloquial expression that refers to common programming errors which result in undefined behavior (UB)**

## The format string: "Hello, Zig!\n"

Zig format strings look like Rust's:

- {} = general placeholder
- {s} = UTF-8 slice
- {d} = integer
- {any} = auto format anything

But here → no placeholders. Just a simple string with a newline.

## The mysterious .{}

Every std.debug.print call MUST pass arguments as a tuple literal.
Yep. Even if it's empty.

This:

```
{}
```

Is Zig syntax for:

"An empty tuple - I'm not providing any formatting arguments."

If you had variables:

```zig 
const name = "Zig";
std.debug.print("Hello, {s}!\n", .{ name });
```

### Why tuples?
- Zig avoids hidden stack allocations.
- Tuples are lightweight.
- This avoids the runtime cost of variadic functions.