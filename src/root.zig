const parser = @import("parser");
const std = @import("std");
const iface = @import("iface");
const wget = @import("wget");

const USAGE =
    \\Usage: wget [OPTION]... [URL]...
    \\
    \\Try `wget --help' for more options.
;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var args = std.process.args();
    _ = args.skip(); // skip program path

    var argParser = try parser.ArgumentParser(wget.types.Options).init(allocator);
    const options = argParser.parse(iface.asInterface(iface.types.Iterator([:0]const u8), &args)) catch |err| {
        std.log.err("{?s}: {t}", .{ argParser.lastArg, err });
        return;
    };

    var wgetter = wget.Wget.init(allocator, options, argParser.operands.items) catch |err| switch (err) {
        wget.ParseError.MissingURL => return std.log.err("wget: {t}\n{s}", .{ err, USAGE }),
        else => return std.log.err("{t}", .{err}),
    };

    while (true) {
        const next = wgetter.next() catch |err| std.log.err("'{?f}' {t}", .{ wgetter.current(), err });
        next orelse break;
    }
}
