pub const types = @import("types.zig");
pub const HttpHandler = @import("http.zig").HttpHandler;
pub const FtpHandler = @import("ftp.zig").FtpHandler;

const std = @import("std");
const mem = std.mem;
pub const USAGE =
    \\Usage: wget [OPTION]... [URL]...
    \\
    \\Try `wget --help' for more options.
;

const ALLOWED_SCHEMAS: [2][:0]const u8 = .{ "http://", "https://" };
pub const Error = error{
    MissingURL,
    UnsupportedScheme,
};

pub const Wget = struct {
    urls: []std.Uri, //http urls
    alc: mem.Allocator,

    pub fn init(alc: mem.Allocator, options: types.Options, operands: [][:0]const u8) !Wget {
        _ = options;
        if (operands.len == 0) {
            return Error.MissingURL;
        }

        const urls: []std.Uri = try alc.alloc(std.Uri, operands.len);

        for (operands, 0..) |url, i| {
            urls[i] = parseUri(url) catch |err| {
                std.log.err("{s}: {t}", .{ url, err });
                continue;
            };
        }

        return Wget{
            .urls = urls,
            .alc = alc,
        };
    }

    pub fn parseUri(str: []const u8) !std.Uri {
        const uri = std.Uri.parse(str) catch e: {
            std.log.info("Prepended http:// to '{s}'", .{str});
            break :e try std.Uri.parseAfterScheme("http://", str);
        };

        for (ALLOWED_SCHEMAS) |scheme| if (mem.eql(u8, scheme, uri.scheme)) return uri;
        return Error.UnsupportedScheme;
    }
};
