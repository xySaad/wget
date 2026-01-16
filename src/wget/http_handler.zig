const std = @import("std");
const fmt = @import("fmt");
const mem = std.mem;
const http = @import("http");
const iface = @import("iface");
const FileWriter = @import("types.zig").FileWriter;
const ProgressWriter = @import("progress_writer.zig").ProgressWriter;
const FetchResult = @import("http").FetchResult;
const types = @import("types.zig");

fn getComponent(comp: std.Uri.Component) []const u8 {
    return switch (comp) {
        .percent_encoded => |v| v,
        .raw => |v| v,
    };
}

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

    pub fn download(self: *@This(), uri: std.Uri, options: types.Options) !void {
        if (options.background) {
            const file = try std.fs.cwd().createFile("wget-log", .{});
            defer file.close();
            const pid = try std.posix.fork();
            if (pid > 0) {
                std.process.exit(0);
            }
            try std.posix.dup2(file.handle, std.fs.File.stdout().handle);
        }

        fmt.log("{f}", .{uri});

        const dst_str = blk: {
            if (options.outputDocument.len > 0) {
                break :blk options.outputDocument;
            }
            var dst = try std.ArrayList(u8).initCapacity(self.alc, 0);
            try dst.appendSlice(self.alc, getDestination(getComponent(uri.path)));
            if (uri.query) |q| {
                try dst.appendSlice(self.alc, getComponent(q));
            }
            break :blk dst.items;
        };

        fmt.logTimed("sending request, awaiting response...", .{});
        var result = try http.fetch(&self.client, .{ .location = .{ .uri = uri } });
        post_read(result.response.head, dst_str);

        const file = try std.fs.cwd().createFile(dst_str, .{});
        defer file.close();

        if (options.background) {
            try bgSave(file, &result, dst_str);
        } else {
            try save(file, &result, dst_str);
        }
    }

    pub fn save(file: std.fs.File, result: *FetchResult, dst_str: []const u8) !void {
        var body = ProgressWriter.init(file, result.response.head.content_length);
        var wr = iface.asInterface(http.ResponseWriter, &body);
        try result.body(&wr, null);
        fmt.log("", .{});
        fmt.logTimed("succesfully downloaded '{s}'", .{dst_str});
    }

    pub fn bgSave(file: std.fs.File, result: *FetchResult, dst_str: []const u8) !void {
        var body = FileWriter{ .file = file };
        var wr = iface.asInterface(http.ResponseWriter, &body);
        try result.body(&wr, null);
        fmt.logTimed("succesfully downloaded '{s}'", .{dst_str});
    }

    fn post_read(head: std.http.Client.Response.Head, dst: []const u8) void {
        const status = head.status;
        fmt.logTimed("response received. status: {d} {?s}", .{ @intFromEnum(status), status.phrase() });
        if (status.class() != .success) return; // TODO: return error

        const size = head.content_length;
        fmt.log("content size: {?d} [~{?B:.2}]", .{ size, size });
        const ctype = head.content_type;
        fmt.log("content type: {?s}", .{ctype});
        fmt.logTimed("saving file to: {s}", .{dst});
    }
};
