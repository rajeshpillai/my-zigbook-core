# PART 8 — Allocators: How Zig Does Memory (And Why It’s Beautiful)
(The part where memory stops being scary and starts making sense)

Most languages hide memory from you:
- Node.js / Python: “Don’t worry, I’ll clean it. Maybe. Eventually.”
- Go: “I’m garbage collected but pretend I’m not.”
- Rust: “You shall recite the sacred lifetimes scroll before compiling.”
- C: “malloc()? free()? Good luck, mortal.”

Zig takes a radically different stance:

🧠 The Big Idea:

You always know who owns memory, who allocates it, who frees it.
- Nothing happens behind your back.
- No GC.
- No lifetimes.
- No leaks (if you follow the rules).

Everything goes through an Allocator object, which you explicitly provide.

🎯 In one sentence:

Allocators are objects that hand out memory and later take it back.
You choose them. You control them.

