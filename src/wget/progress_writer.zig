const std = @import("std");
const Writer = std.io.Writer;
const root = @import("root");

// report write progress to stdout
pub const ProgressWriter = struct {
    allocating: Writer.Allocating,

    pub fn init(allocator: std.mem.Allocator) @This() {
        return ProgressWriter{ .allocating = Writer.Allocating.init(allocator) };
    }
    pub fn write(self: *@This(), bytes: []const u8) Writer.Error!usize {
        return self.allocating.writer.write(bytes);
    }
    pub fn deinit(self: *@This()) void {
        self.allocating.deinit();
    }

    pub fn toOwnedSlice(self: *@This()) error{OutOfMemory}![]u8 {
        return self.allocating.toOwnedSlice();
    }
};
