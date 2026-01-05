pub const parser = @import("parser");
const std = @import("std");

const Options: []const [2][]const u8 = &.{
    .{ "b", "background" },
    .{ "O", "output-document" },
    .{ "P", "directory-prefix" },
    .{ "\x00", "limit-rate" },
    .{ "m", "mirror" },
    .{ "i", "input-file" },
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const args, const options = try parser.parseArgs(allocator, Options);
    var i: usize = 0;
    std.debug.print("args:\n", .{});
    while (i < args.items.len) : (i += 1) {
        std.debug.print("{s}\n", .{args.items[i]});
    }
    std.debug.print("options:\n", .{});
    for (options) |option| {
        std.debug.print("{s}\n", .{option});
    }
}
