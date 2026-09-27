// main.zig — the smallest Zig program. Printing can fail (the output may
// be closed), so main returns an error union, !void, and `try` passes a
// failure up.
const std = @import("std");

pub fn main() !void {
    const out = std.io.getStdOut().writer();
    try out.print("Hello from Zig\n", .{});
}
