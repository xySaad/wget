const std = @import("std");
const types = @import("types.zig");
const mem = std.mem;
const Error = error{ InvalidOption, MissingOptionArgument } || mem.Allocator.Error;
const iface = @import("root").iface;

pub fn ArgumentParser(comptime T: type) type {
    const options = types.optionsToArray(T);
    return struct {
        const Self = @This();
        parameters: T = std.mem.zeroes(T),
        allocator: std.mem.Allocator,
        arguments: iface.types.Iterator([:0]const u8),
        operands: std.ArrayList([:0]const u8),
        lastArg: ?[:0]const u8,
        end_of_options: bool,

        pub fn init(alc: std.mem.Allocator) !Self {
            return Self{
                .allocator = alc,
                .arguments = undefined,
                .lastArg = null,
                .end_of_options = false,
                .operands = try std.ArrayList([:0]const u8).initCapacity(alc, 0),
            };
        }

        pub fn parse(self: *Self, arguments: iface.types.Iterator([:0]const u8)) !T {
            self.arguments = arguments;
            while (self.arguments.next()) |arg| {
                if (self.end_of_options) {
                    try self.operands.append(self.allocator, arg);
                    continue;
                }

                if (mem.eql(u8, arg, "--")) {
                    self.end_of_options = true;
                    continue;
                }

                self.lastArg = arg;
                // match long and short format according to posix (one hyphen for short and two for long format)
                if (mem.startsWith(u8, arg, "--")) {
                    try self.matchOptionLong(arg);
                    continue;
                }

                if (mem.startsWith(u8, arg, "-")) {
                    try self.matchOptionShort(arg);
                    continue;
                }

                try self.operands.append(self.allocator, arg);
            }
            return self.parameters;
        }

        fn mustNextArg(self: *Self) ![:0]const u8 {
            return self.arguments.next() orelse {
                return Error.MissingOptionArgument;
            };
        }

        fn matchOptionShort(self: *Self, arg: [:0]const u8) !void {
            const trimmed = arg[1..];

            outer: for (trimmed, 0..) |char, charIdx| {
                inline for (options) |opt| {
                    if (char == opt.shortFormat) {
                        //option doesn't supports option-argument
                        const field = &@field(self.parameters, opt.longFormat);
                        if (opt.isBool) {
                            field.* = true;
                            continue :outer; // don't break because to not trigger error;
                        } else if (charIdx == trimmed.len - 1) { //the argument itself doesn't contain the option-argument (e.g. wget -O somefile)
                            const nextArg = try self.mustNextArg();
                            self.lastArg = self.lastArg;
                            field.* = nextArg;
                        } else { //the argument does contain the option-argument (e.g. wget -Osomefile)
                            field.* = trimmed[charIdx + 1 ..];
                        }
                        return;
                    }
                }
                // failed to match this character with any available options
                return Error.InvalidOption;
            }
        }
        fn matchOptionLong(self: *Self, arg: [:0]const u8) !void {
            const trimmed = arg[2..];
            inline for (options) |opt| {
                const field = &@field(self.parameters, opt.longFormat);
                const optionLong = opt.longFormat;
                //option doesn't supports option-argument
                if (opt.isBool) {
                    if (mem.eql(u8, trimmed, optionLong)) {
                        field.* = true;
                        return;
                    }
                    continue;
                }

                //the argument itself doesn't contain the option-argument (e.g. wget --output-document somefile)
                if (mem.eql(u8, trimmed, optionLong)) {
                    const nextArg = try self.mustNextArg();
                    self.lastArg = self.lastArg;
                    field.* = nextArg;
                    return;
                }

                //the argument does contain the option-argument (e.g. wget --output-document=somefile)
                if (mem.startsWith(u8, trimmed, optionLong)) {
                    field.* = trimmed[optionLong.len..];
                    return;
                }
            }

            return Error.InvalidOption;
        }
    };
}
