pub const parser = @import("parser");
const std = @import("std");
const iface = @import("iface");
const wget = @import("wget");
const zeit = @import("zeit");

pub fn logTimed(comptime fmt: []const u8, args: anytype) void {
    const out = std.fs.File.stdout();
    var outwr = out.writer(&.{});

    const local = zeit.local(std.heap.page_allocator, null) catch zeit.utc;
    if (zeit.instant(.{ .timezone = &local })) |now| {
        now.time().strftime(&outwr.interface, "[%Y-%m-%d %H:%M:%S] ") catch {};
    } else |_| {}

    std.io.Writer.print(&outwr.interface, fmt ++ "\n", args) catch {};
}

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
        wget.ParseError.MissingURL => return std.log.err("wget: {t}\n{s}", .{ err, wget.USAGE }),
        else => return std.log.err("{t}", .{err}),
    };

    while (true) {
        const next = wgetter.next() catch |err| std.log.err("'{?f}' {t}", .{ wgetter.current(), err });
        next orelse break;
    }
}
