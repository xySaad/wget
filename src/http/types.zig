const std = @import("std");
const Client = std.http.Client;
const iface = @import("iface");
const Writer = std.io.Writer;

pub const ResponseWriter = struct {
    ptr: *anyopaque,
    vtable: struct {
        write: *const fn (*anyopaque, []const u8) Writer.Error!usize,
    },

    pub fn write(self: *@This(), bytes: []const u8) Writer.Error!usize {
        return self.vtable.write(self.ptr, bytes);
    }

    pub fn from(ptr: anytype) @This() {
        return iface.asInterface(@This(), ptr);
    }
};

pub const FetchResult = struct {
    client: *Client,
    response: Client.Response,
    request: Client.Request,

    pub fn body(self: *@This(), response_writer: *ResponseWriter, decompress_buffer: ?[]u8) Client.FetchError!void {
        defer self.request.deinit();
        var response = self.response;
        response.request = &self.request;
        const client = self.client;

        const decompress_buf: []u8 = switch (response.head.content_encoding) {
            .identity => &.{},
            .zstd => decompress_buffer orelse try client.allocator.alloc(u8, std.compress.zstd.default_window_len),
            .deflate, .gzip => decompress_buffer orelse try client.allocator.alloc(u8, std.compress.flate.max_window_len),
            .compress => return error.UnsupportedCompressionMethod,
        };
        defer if (decompress_buffer == null) client.allocator.free(decompress_buf);

        var transfer_buffer: [64]u8 = undefined;
        var decompress: std.http.Decompress = undefined;
        const reader = response.readerDecompressing(&transfer_buffer, &decompress, decompress_buf);
        var buf: [1024]u8 = undefined;

        var written: usize = 0;
        while (true) {
            const n = try reader.readSliceShort(&buf);
            written += n;
            _ = try response_writer.write(buf[0..n]);
            if (n == 0) break;
            if (response.head.content_length) |len| if (written >= len) break;
        }
    }

    pub fn discard(self: @This()) Client.FetchError!void {
        defer self.request.deinit();
        var response = self.response;
        response.request = &self.request;

        const reader = response.reader(&.{});
        _ = reader.discardRemaining() catch |err| switch (err) {
            error.ReadFailed => return response.bodyErr().?,
        };
    }
};
