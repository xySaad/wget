pub const parser = @import("parser");
const std = @import("std");

const OPTIONS: parser.Options = &.{
    .{ 'b', "background" },
    .{ 'O', "output-document=" },
    .{ 'P', "directory-prefix=" },
    .{ '\x00', "limit-rate=" },
    .{ 'm', "mirror" },
    .{ 'i', "input-file=" },
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var argParser = try parser.ArgumentParser.init(allocator, OPTIONS);
    argParser.parse() catch |err| {
        std.debug.print("{any}\n", .{err});
        return;
    };

    std.debug.print("args: ", .{});
    for (1..argParser.arguments.items.len) |i| {
        std.debug.print("{s}", .{argParser.arguments.items[i]});
        if (i == argParser.arguments.items.len - 1) continue;
        std.debug.print(", ", .{});
    }
    std.debug.print("\n", .{});

    std.debug.print("===options===\n", .{});
    for (argParser.parameters, OPTIONS) |parameter, option| {
        if (parameter.len == 0) continue;
        std.debug.print("{s}: {s}", .{ option[1], parameter });
        std.debug.print("\n", .{});
    }
}
