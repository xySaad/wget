const std = @import("std");
const Client = std.http.Client;
const iface = @import("iface");
const Writer = std.io.Writer;

const FetchResult = struct {
    client: *Client,
    response: Client.Response,
    request: Client.Request,

    pub fn body(self: *@This(), response_writer: *std.io.Writer, decompress_buffer: ?[]u8) Client.FetchError!void {
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

        _ = reader.streamRemaining(response_writer) catch |err| switch (err) {
            error.ReadFailed => return response.bodyErr().?,
            else => |e| return e,
        };
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

/// caller must either call `FetchResult.discard` or `FetchResult.body` to cleanup ressources
///
/// `FetchOptions.response_writer` and `FetchOptions.decompress_buffer` are not used
pub fn fetch(client: *Client, options: Client.FetchOptions) Client.FetchError!FetchResult {
    const uri = switch (options.location) {
        .url => |u| try std.Uri.parse(u),
        .uri => |u| u,
    };
    const method: std.http.Method = options.method orelse
        if (options.payload != null) .POST else .GET;

    const redirect_behavior: Client.Request.RedirectBehavior = options.redirect_behavior orelse
        if (options.payload == null) @enumFromInt(3) else .unhandled;

    var req = try Client.request(client, method, uri, .{
        .redirect_behavior = redirect_behavior,
        .headers = options.headers,
        .extra_headers = options.extra_headers,
        .privileged_headers = options.privileged_headers,
        .keep_alive = options.keep_alive,
    });
    errdefer req.deinit();

    if (options.payload) |payload| {
        req.transfer_encoding = .{ .content_length = payload.len };
        var body = try req.sendBodyUnflushed(&.{});
        try body.writer.writeAll(payload);
        try body.end();
        try req.connection.?.flush();
    } else {
        try req.sendBodiless();
    }

    const redirect_buffer: []u8 = if (redirect_behavior == .unhandled) &.{} else options.redirect_buffer orelse
        try client.allocator.alloc(u8, 8 * 1024);
    defer if (options.redirect_buffer == null) client.allocator.free(redirect_buffer);

    const response = try req.receiveHead(redirect_buffer);

    return .{
        .client = client,
        .response = response,
        .request = req,
    };
}
