const std = @import("std");
const root = @import("root");
const mem = std.mem;
const http = @import("root").http;
const iface = @import("root").iface;

const ProgressWriter = @import("progress_writer.zig").ProgressWriter;

fn getDestination(raw: []const u8) []const u8 {
    if (raw.len == 0 or mem.eql(u8, raw, "/")) {
        return "index.html";
    }

    var last: []const u8 = undefined;
    const trimmed = mem.trimEnd(u8, raw, "/");
    var iter = mem.splitScalar(u8, trimmed, '/');
    while (iter.next()) |part| {
        last = part;
    }
    return last;
}

pub const HttpHandler = struct {
    alc: mem.Allocator,
    client: std.http.Client,

    pub fn init(alc: mem.Allocator, client: std.http.Client) @This() {
        return HttpHandler{ .alc = alc, .client = client };
    }

    pub fn download(self: *@This(), uri: std.Uri) !void {
        root.log("{f}", .{uri});
        const raw = try uri.path.toRawMaybeAlloc(self.alc);
        const dst = getDestination(raw);
        root.logTimed("sending request, awaiting response...", .{});
        var result = try http.fetch(&self.client, .{ .location = .{ .uri = uri } });
        post_read(result.response.head);

        root.logTimed("saving file to: {s}", .{dst});
        const file = try std.fs.cwd().createFile(dst, .{});
        defer file.close();
        var body = ProgressWriter.init(file, result.response.head.content_length);
        var wr = iface.asInterface(http.ResponseWriter, &body);
        try result.body(&wr, null);
        root.log("", .{});
    }

    fn post_read(head: std.http.Client.Response.Head) void {
        const status = head.status;
        root.logTimed("response received. status: {d} {?s}", .{ @intFromEnum(status), status.phrase() });
        if (status.class() != .success) return; // TODO: return error

        const size = head.content_length;
        root.log("content size: {?d} [~{?B:.2}]", .{ size, size });
        const ctype = head.content_type;
        root.log("content type: {?s}", .{ctype});
    }
};
