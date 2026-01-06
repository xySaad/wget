pub const parser = @import("parser");
const std = @import("std");

pub const Options = struct {
    const str = [:0]const u8;
    directoryPrefix: str,
    outputDocument: str,
    limitRate: str,
    inputFile: str,

    background: bool,
    mirror: bool,

    pub const short = .{
        .background = 'b',
        .outputDocument = 'O',
        .directoryPrefix = 'P',
        .limitRate = null,
        .mirror = 'm',
        .inputFile = 'i',
    };
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var argParser = try parser.ArgumentParser(Options).init(allocator);
    const options = argParser.parse() catch |err| {
        std.debug.print("{any}\n", .{err});
        return;
    };

    if (options.background) {
        // run in background
    }

    std.debug.print("{any}\n", .{options});
}
