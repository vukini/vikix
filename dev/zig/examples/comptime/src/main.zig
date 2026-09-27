// main.zig — comptime: code that runs while the program compiles.
//
// Zig can run ordinary Zig code at compile time. Here that builds a table
// of squares into the program itself (no work at run time), and makes a
// function that works for any number type: the type is just a parameter
// known at compile time. Tests live beside the code; `zig build test`
// (make check) runs them.
const std = @import("std");

// Run at compile time: the table is baked into the executable.
const squares = blk: {
    var table: [10]u32 = undefined;
    for (&table, 0..) |*slot, i| slot.* = @intCast(i * i);
    break :blk table;
};

// T is a type, passed like any other argument, but at compile time; the
// compiler makes one version of the function for each type it is used with.
fn biggest(comptime T: type, items: []const T) T {
    var best = items[0];
    for (items[1..]) |x| {
        if (x > best) best = x;
    }
    return best;
}

pub fn main() !void {
    const out = std.io.getStdOut().writer();
    try out.print("squares, computed while compiling: {any}\n", .{squares});
    try out.print("biggest u8:  {d}\n", .{biggest(u8, &[_]u8{ 3, 250, 7 })});
    try out.print("biggest f64: {d}\n", .{biggest(f64, &[_]f64{ 2.5, -1.0, 9.75 })});
}

test "the table holds squares" {
    try std.testing.expectEqual(@as(u32, 81), squares[9]);
}

test "biggest works for any number type" {
    try std.testing.expectEqual(@as(i32, 5), biggest(i32, &[_]i32{ -3, 5, 2 }));
    try std.testing.expectEqual(@as(f32, 0.5), biggest(f32, &[_]f32{ 0.25, 0.5 }));
}
