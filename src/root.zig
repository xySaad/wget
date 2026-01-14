pub const main = @import("main.zig").main;
pub const iface = @import("iface");
pub const http = @import("http");

const std = @import("std");
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
