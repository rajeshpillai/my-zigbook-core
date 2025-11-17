# 2. Philosophy: "No Hidden Control Flow" (Why This Matters)
Here is the golden rule of Zig:

If the compiler generates code that you didn't explicitly write, Zig considers that a crime.

So:
- No implicit allocations
- No exceptions
- No automatic conversions
- No catching failures silently
- No "oh here's an invisible destructor running in the background"

If something could take your CPU on a surprise vacation → Zig forces you to write it.

This is why many developers say:
- Zig is the first language that trusts me enough to fail loudly.