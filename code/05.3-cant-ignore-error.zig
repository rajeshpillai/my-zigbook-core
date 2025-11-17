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
