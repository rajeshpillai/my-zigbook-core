## 5. defer - Zig's Personal Janitor
In most languages you've probably done at least one of these:

Node.js:

```js
try {   // work } finally {   // cleanup }
```

Go:

```go
defer file.Close()
```

Rust:
 Let RAII drop do the cleanup "when it goes out of scope".

Python:

```python
with open(...) as f:     ...
```

Zig looks at all of that and says:

>"Just tell me what to run at the end of this scope. I'll handle the rest."

That's what defer is.


## 5.1 The Core Idea: Run This Later, No Matter What
defer means:

>"Run this statement when the current scope ends - 
 whether we return, hit an error, or just reach the end."
Let's start with a tiny, runnable example.

Save this as defer-basic.zig:

```zig
const std = @import("std");

fn demoBasicDefer() void {
    std.debug.print("--- demoBasicDefer ---\n", .{});

    std.debug.print("start of function\n", .{});

    // This will run when demoBasicDefer returns (at end of this function).
    defer std.debug.print("outer defer (function scope)\n", .{});

    {
        std.debug.print("  enter inner block\n", .{});

        // This will run when the inner block ends (after this { } finishes).
        defer std.debug.print("  inner defer (block scope)\n", .{});

        std.debug.print("  leaving inner block body\n", .{});
    }

    std.debug.print("after inner block\n", .{});
}

pub fn main() void {
    demoBasicDefer();
}

```

Expected Output:

```
--- demoBasicDefer ---
start of function
  enter inner block
  leaving inner block body
  inner defer (block scope)
after inner block
outer defer (function scope)
```

Key observations:
- defer is LIFO (last in, first out) per scope.
- Inner defer runs before outer defer.
- Block scopes ({ ... }) matter in Zig - each has its own defer list.

> Think of each scope as a small stack of "cleanup tasks".
  
> Every defer pushes one item, and when the scope ends, Zig pops and runs them in reverse order.



## 5.2 defer with Real Resources (Files, Memory, etc.)
The above is cute, but let's use defer for something real.

This example:
- creates a file
- writes to it
- guarantees .close() is called even if something fails in between

defer-file.zig

```zig
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

```

Run:

```zig 
zig run defer-file.zig
```

Then open defer-demo.txt - you'll see the content.

Why this is nice:
- No need for try { ... } finally { file.close(); }
- No need for a custom "resource wrapper" type
- No hidden control flow - defer is visible in the code


## 5.3 errdefer: Cleanup Only When Things Go Wrong
defer runs always (success or error).
 Sometimes you want cleanup that only runs on error paths.
That's what errdefer is for.
- errdefer = "run this only if the function returns with an error".

Here's a small demo to show the difference:

defer-errdefer.zig

```zig 
const std = @import("std");

// Define a small error set for this demo.
const DemoError = error{
    Boom,
};

// A function that sometimes fails.
fn demoErrDefer(should_fail: bool) DemoError!void {
    std.debug.print("--- demoErrDefer (should_fail = {any}) ---\n", .{should_fail});

    // This always runs when demoErrDefer returns (success or error).
    defer std.debug.print("defer: always runs (success or error)\n", .{});

    // This only runs if we return with an error.
    errdefer std.debug.print("errdefer: runs only on error\n", .{});

    if (should_fail) {
        std.debug.print("About to fail with DemoError.Boom\n", .{});
        return DemoError.Boom;
    }

    std.debug.print("Work done successfully, returning OK\n", .{});
}

pub fn main() void {
    // Case 1: success path
    _ = demoErrDefer(false) catch |err| {
        std.debug.print("Unexpected error: {any}\n", .{err});
    };

    std.debug.print("\n", .{}); // separator

    // Case 2: error path
    _ = demoErrDefer(true) catch |err| {
        std.debug.print("Caught error in main: {any}\n", .{err});
    };
}

```

You'll see output like:
```
--- demoErrDefer (should_fail = false) ---
Work done successfully, returning OK
defer: always runs (success or error)

--- demoErrDefer (should_fail = true) ---
About to fail with DemoError.Boom
errdefer: runs only on error
defer: always runs (success or error)
Caught error in main: error.Boom
```

Notice:
On success:
- defer runs
- errdefer does not run
On error:
- errdefer runs first
- defer still runs afterwards

Both follow the same "stack" / LIFO ordering inside the function.

## 5.4 Error Handling + defer: You're Not Allowed to Ignore Errors
Here's where Zig gets interesting and opinionated.
Because of:
- !T (error unions),
- try,
- catch,
- defer / errdefer,

Zig's primitives are powerful enough that the compiler can say:

"If a function returns !T, you must handle the error.

You are not allowed to silently ignore it."

cant-ignore-error.zig

```zig
fn mightFail() error{Boom}!void {
    return error.Boom;
}

pub fn main() void {
    // This is NOT allowed:
    // _ = mightFail(); // ❌ compile error: error result unused

    // You must either:
    // - propagate it with `try`, or
    // - handle it with `catch`.
}
```

If you uncomment _ = mightFail() the code will not compile.
In Zig, ignoring an error from an error-union function is a compile-time error.

You must use try or catch.


## 5.5 "No Really, I Want to Ignore It": catch unreachable
Now, sometimes you know - truly know - that something cannot fail.

Example: you're calling a function that only returns an error in situations you've already ruled out.

Zig gives you an escape hatch for that:


escape-hatch.zig

```zig
const std = @import("std");

const DemoError = error{
    ShouldNeverHappen,
};

fn cannotFailInThisContext() DemoError!void {
    // Imagine this can only fail if some invariant is broken.
    return DemoError.ShouldNeverHappen;
}

pub fn main() void {
    // We are *asserting* that this call will never fail.
    // If it *does* fail in Debug or ReleaseSafe, the program will crash.
    cannotFailInThisContext() catch unreachable;

    std.debug.print("If you see this, cannotFailInThisContext() did not error.\n", .{});
}

```

NOTE: This code will not compile.
This code

```zig
fn cannotFailInThisContext() DemoError!void {
    // Imagine this can only fail if some invariant is broken.
    return DemoError.ShouldNeverHappen;
}
```


The function returns either:
- a void value (success case)
- OR
- one of the errors in the DemoError error set

This code
```zig 
return DemoError.ShouldNeverHappen;
```

This means:

"I am returning an ERROR value from this function."

So the function is not returning normally - 
it's returning a specific error variant from the error set.

What's going on here?


- catch unreachable tells Zig:
 "If this ever returns an error, that's a bug. Treat it as impossible."
- In Debug and ReleaseSafe builds:
  If an error happens, the program crashes with a panic at runtime.
  Which is good - it means your "this can't happen" assumption was wrong.
- In more aggressive builds (ReleaseFast / ReleaseSmall), unreachable may be optimized as undefined behavior - so this is for true invariants, not casual laziness.

## 5.6 defer in Zig vs Other languages
For 
- JS devs:
 → "defer is like finally { ... } but without wrapping everything in try/catch."
- Go devs:
 → "defer works almost exactly like Go's defer, but it's per-scope (blocks matter) and you also get errdefer."
- Rust devs:
 → "Instead of RAII drops, you explicitly attach cleanup to scopes. No hidden destructors."
- Python devs:
 → "Think of defer like a manual with block, where you decide explicitly what to do at exit."

### From the zig doc

A couple of other tidbits about error handling:
- These primitives give enough expressiveness that it's completely practical to have failing to check for an error be a compile error. If you really want to ignore the error, you can add catch unreachable and get the added benefit of crashing in Debug and ReleaseSafe modes if your assumption was wrong.
- Since Zig understands error types, it can pre-weight branches in favor of errors not occurring. Just a small optimization benefit that is not available in other languages.

