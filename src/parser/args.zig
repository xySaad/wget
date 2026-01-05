const std = @import("std");
const utils = @import("root").utils;
const mem = std.mem;
const Error = error{ InvalidOption, MissingOptionArgument } || mem.Allocator.Error;

pub const Options = []const struct {
    u8,
    []const u8,
};

pub const ArgumentParser = struct {
    allocator: std.mem.Allocator,
    processArguments: std.process.ArgIterator,
    options: Options,
    parameters: [][:0]const u8,
    arguments: std.ArrayList([:0]const u8),

    pub fn init(alc: std.mem.Allocator, comptime options: Options) !ArgumentParser {
        const params = try alc.alloc([:0]const u8, options.len);
        @memset(params, "");
        return ArgumentParser{
            .allocator = alc,
            .processArguments = std.process.args(),
            .options = options,
            .parameters = params,
            .arguments = try std.ArrayList([:0]const u8).initCapacity(alc, 0),
        };
    }

    pub fn parse(self: *ArgumentParser) !void {
        while (self.processArguments.next()) |arg| {
            // match long and short format according to posix (one hyphen for short and two for long format)
            if (mem.startsWith(u8, arg, "--")) {
                try self.matchOptionLong(arg);
                continue;
            }

            if (mem.startsWith(u8, arg, "-")) {
                try self.matchOptionShort(arg);
                continue;
            }

            try self.arguments.append(self.allocator, arg);
        }
    }

    fn mustNextArg(self: *ArgumentParser) ![:0]const u8 {
        return self.processArguments.next() orelse {
            return Error.MissingOptionArgument;
        };
    }

    fn matchOptionShort(self: *ArgumentParser, arg: [:0]const u8) !void {
        const trimmed = arg[1..];

        outer: for (trimmed, 0..) |char, charIdx| {
            var i: usize = 0;
            while (i < self.options.len) : (i += 1) {
                const option = self.options[i][0];
                if (char != option) continue;
                const longOption = self.options[i][1];
                //option doesn't supports option-argument
                if (longOption[longOption.len - 1] != '=') {
                    self.parameters[i] = "true";
                    continue :outer;
                }

                //the argument itself doesn't contain the option-argument (e.g. wget -O somefile)
                if (charIdx == trimmed.len - 1) {
                    self.parameters[i] = try self.mustNextArg();
                    return;
                }

                //the argument does contain the option-argument (e.g. wget -Osomefile)
                self.parameters[i] = trimmed[charIdx + 1 ..];
                return;
            }
            // failed to match this character with any available options
            return Error.InvalidOption;
        }
    }

    fn matchOptionLong(self: *ArgumentParser, arg: [:0]const u8) !void {
        const trimmed = arg[2..];
        var i: usize = 0;
        while (i < self.options.len) : (i += 1) {
            const option = self.options[i][1];
            //option doesn't supports option-argument
            if (option[option.len - 1] != '=') {
                if (mem.eql(u8, trimmed, option)) {
                    self.parameters[i] = "true";
                    return;
                }
                continue;
            }

            //the argument itself doesn't contain the option-argument (e.g. wget --output-document somefile)
            if (mem.eql(u8, trimmed, option[0 .. option.len - 1])) {
                self.parameters[i] = try self.mustNextArg();
                return;
            }

            //the argument does contain the option-argument (e.g. wget --output-document=somefile)
            if (mem.startsWith(u8, trimmed, option)) {
                self.parameters[i] = trimmed[option.len..];
                return;
            }
        }

        return Error.InvalidOption;
    }
};
