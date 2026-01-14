const std = @import("std");
const Writer = std.io.Writer;
const root = @import("root");
const File = std.fs.File;

// report write progress to stdout
pub const ProgressWriter = struct {
    file: File,

    pub fn init(file: File) @This() {
        return ProgressWriter{ .file = file };
    }
    pub fn write(self: *@This(), bytes: []const u8) Writer.Error!usize {
        return self.file.write(bytes) catch {
            return Writer.Error.WriteFailed;
        };
    }
};
