const std = @import("std");
const Client = std.http.Client;
const iface = @import("iface");
const Writer = std.io.Writer;
const types = @import("types.zig");

/// caller must either call `FetchResult.discard` or `FetchResult.body` to cleanup ressources
///
/// `FetchOptions.response_writer` and `FetchOptions.decompress_buffer` are not used
pub fn fetch(client: *Client, options: Client.FetchOptions) Client.FetchError!types.FetchResult {
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
