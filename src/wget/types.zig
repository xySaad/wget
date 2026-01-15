const std = @import("std");
const File = std.fs.File;
const Writer = std.io.Writer;

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

pub const FileWriter = struct {
    file: File,

    pub fn write(self: *@This(), bytes: []const u8) Writer.Error!usize {
        return self.file.write(bytes) catch {
            return Writer.Error.WriteFailed;
        };
    }
};
