pub const types = @import("types.zig");

const HttpHandler = @import("http_handler.zig").HttpHandler;
const FtpHandler = @import("ftp.zig").FtpHandler;
const std = @import("std");
const Client = std.http.Client;
const mem = std.mem;
const fs = std.fs;

const ALLOWED_SCHEMAS: [2][:0]const u8 = .{ "http", "https" };
pub const ParseError = error{
    MissingURL,
    UnsupportedScheme,
};
const Error = Client.RequestError || fs.File.OpenError || std.Io.Writer.Error || std.fs.File.WriteError || Client.Request.ReceiveHeadError || Client.Request.ReceiveHeadError || std.Io.Reader.LimitedAllocError || std.Io.Reader.ReadAllocError;

pub const Wget = struct {
    uris: []std.Uri, //http urls
    alc: mem.Allocator,
    pos: usize = 0,
    client: Client,
    httpHandler: HttpHandler,

    pub fn init(alc: mem.Allocator, options: types.Options, operands: [][:0]const u8) !Wget {
        _ = options;
        if (operands.len == 0) {
            return ParseError.MissingURL;
        }

        const urls: []std.Uri = try alc.alloc(std.Uri, operands.len);

        var i: usize = 0;
        for (operands) |url| {
            urls[i] = parseUri(alc, url) catch |err| {
                std.log.err("{s}: {t}", .{ url, err });
                continue;
            };
            i += 1;
        }

        const client = Client{ .allocator = alc };
        return Wget{
            .uris = urls[0..i],
            .alc = alc,
            .client = client,
            .httpHandler = HttpHandler.init(alc, client),
        };
    }

    pub fn next(self: *@This()) !?void {
        if (self.pos >= self.uris.len) return null;
        defer self.pos += 1;
        const uri = self.uris[self.pos];

        try self.httpHandler.download(uri);
    }

    pub fn current(self: *@This()) ?std.Uri {
        if (self.pos == 0) return null;
        return self.uris[self.pos - 1];
    }
    pub fn parseUri(alc: mem.Allocator, str: []const u8) !std.Uri {
        const uri = std.Uri.parse(str) catch e: {
            const concatenated = try mem.concat(alc, u8, &[2][]const u8{ "//", str });
            break :e try std.Uri.parseAfterScheme("http", concatenated);
        };

        for (ALLOWED_SCHEMAS) |scheme| if (mem.eql(u8, scheme, uri.scheme)) return uri;
        return ParseError.UnsupportedScheme;
    }
};
