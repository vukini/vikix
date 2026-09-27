// main.zig — the ten most common words in a text file.
//
// A word is a run of letters, compared in lower case. A StringHashMap
// counts them; std.mem.sort puts the most common first. Zig has no hidden
// allocations: every function that needs memory is handed an allocator,
// here an arena, freed all at once at the end.
//
//   zig build run -- text.txt
const std = @import("std");

const Entry = struct { word: []const u8, count: usize };

// The higher count first; the same count in alphabetical order.
fn before(_: void, a: Entry, b: Entry) bool {
    if (a.count != b.count) return a.count > b.count;
    return std.mem.lessThan(u8, a.word, b.word);
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const args = try std.process.argsAlloc(alloc);
    if (args.len != 2) {
        std.debug.print("usage: wordfreq FILE\n", .{});
        std.process.exit(2);
    }
    const text = try std.fs.cwd().readFileAlloc(alloc, args[1], 64 * 1024 * 1024);
    for (text) |*c| c.* = std.ascii.toLower(c.*);

    // One pass over the text: a word starts at the first letter after a
    // non-letter, and ends at the next non-letter.
    var counts = std.StringHashMap(usize).init(alloc);
    var start: ?usize = null;
    for (text, 0..) |c, i| {
        const letter = c >= 'a' and c <= 'z';
        if (letter and start == null) start = i;
        if (!letter) if (start) |s| {
            try bump(&counts, text[s..i]);
            start = null;
        };
    }
    if (start) |s| try bump(&counts, text[s..]);

    var list = std.ArrayList(Entry).init(alloc);
    var it = counts.iterator();
    while (it.next()) |e| try list.append(.{ .word = e.key_ptr.*, .count = e.value_ptr.* });
    std.mem.sort(Entry, list.items, {}, before);

    const out = std.io.getStdOut().writer();
    for (list.items[0..@min(10, list.items.len)]) |e| {
        try out.print("{d:>4} {s}\n", .{ e.count, e.word });
    }
}

fn bump(counts: *std.StringHashMap(usize), word: []const u8) !void {
    const slot = try counts.getOrPut(word);
    if (!slot.found_existing) slot.value_ptr.* = 0;
    slot.value_ptr.* += 1;
}
