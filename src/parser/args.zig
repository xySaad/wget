const std = @import("std");
const utils = @import("root").utils;
const mem = std.mem;

pub fn parseArgs(alloc: std.mem.Allocator, comptime options: []const [2][]const u8) !struct { std.array_list.Aligned([:0]const u8, null), [][:0]const u8 } {
    var argsIterator = std.process.args();
    var args = try std.ArrayList([:0]const u8).initCapacity(alloc, 0);
    const foundOptions = try alloc.alloc([:0]const u8, options.len);

    _ = argsIterator.skip();
    outer: while (argsIterator.next()) |arg| {
        if (mem.startsWith(u8, arg, "--")) {
            const trimmed = arg[2..];
            var i: usize = 0;
            while (i < options.len) : (i += 1) {
                const option = options[i][1];
                if (mem.eql(u8, trimmed, option)) {
                    foundOptions[i] = "true";
                    continue :outer;
                }

                const concated = try mem.concat(alloc, u8, &.{ option, "=" });
                if (mem.startsWith(u8, trimmed, concated)) {
                    foundOptions[i] = trimmed[concated.len..];
                    continue :outer;
                }
            }
            // return error invalid option
        } else if (mem.startsWith(u8, arg, "-")) {
            const trimmed = arg[1..];
            var i: usize = 0;
            while (i < options.len) : (i += 1) {
                const option = options[i][0];
                if (mem.eql(u8, trimmed, option)) {
                    //TODO: skip if next argument is an option
                    if (argsIterator.next()) |nextArg| {
                        foundOptions[i] = nextArg;
                    }
                    continue :outer;
                }
            }
            // return error invalid option
        }

        try args.append(alloc, arg);
    }
    return .{ args, foundOptions };
}
