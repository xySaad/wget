const std = @import("std");
const Writer = std.io.Writer;
const fmt = @import("fmt");
const File = std.fs.File;
const time = std.time;

// report write progress to stdout
pub const ProgressWriter = struct {
    file: File,
    expected_size: ?u64,
    written: u64 = 0,
    bar: [100]u8 = ".".* ** 100,
    start_time: ?time.Instant = null,

    const MAX_ETA = "999 day 24h 60m 60s";

    pub fn init(file: File, expected_size: ?u64) @This() {
        return ProgressWriter{ .file = file, .expected_size = expected_size };
    }
    pub fn write(self: *@This(), bytes: []const u8) Writer.Error!usize {
        self.progess_bar(bytes.len);

        self.written += bytes.len;
        return self.file.write(bytes) catch {
            return Writer.Error.WriteFailed;
        };
    }

    fn bytes_per_second(self: *@This()) u64 {
        if (self.start_time) |start| {
            const now = time.Instant.now() catch std.mem.zeroes(time.Instant);
            const seconds_passed = now.since(start) / time.ns_per_s;
            if (seconds_passed > 0) {
                return self.written / seconds_passed;
            }
        } else {
            self.start_time = time.Instant.now() catch std.mem.zeroes(time.Instant);
        }

        return 0;
    }

    /// estimated time
    ///
    /// `bps`: bytes per second
    fn get_eta(self: *@This(), bps: usize) u64 {
        if (bps < 1) return 0;

        if (self.expected_size) |size| {
            const remaining = size - self.written;
            return remaining / bps;
        }

        return 0;
    }

    fn formated_eta(self: *@This(), bps: u64) []const u8 {
        var eta = self.get_eta(bps);
        var buf: [MAX_ETA.len]u8 = " ".* ** MAX_ETA.len;
        var eta_srt = &buf;

        var n: usize = 0;

        if (eta > time.s_per_day) {
            n += fmt.formatBuf(eta_srt[n..], "{d}{s}", .{ eta / time.s_per_day, "day" });
            eta = eta % time.s_per_day;
        }

        if (eta > time.s_per_hour) {
            n += fmt.formatBuf(eta_srt[n..], "{d}{s}", .{ eta / time.s_per_hour, "h" });
            eta = eta % time.s_per_hour;
        }

        if (eta > time.s_per_min) {
            n += fmt.formatBuf(eta_srt[n..], "{d}{s}", .{ eta / time.s_per_min, "m" });
            eta = eta % time.s_per_min;
        }

        n += fmt.formatBuf(eta_srt[n..], "{d}{s}", .{ eta, "s" });

        return eta_srt[0..n];
    }

    fn progess_bar(self: *@This(), new: u64) void {
        if (self.expected_size) |size| {
            const size_f: f64 = @floatFromInt(size);
            const written_f: f64 = @floatFromInt(self.written);
            const new_f: f64 = @floatFromInt(new);

            const unit = size_f / 100.0;
            const percent_total = (written_f + new_f) / unit;
            const percent_written = written_f / unit;

            @memset(self.bar[@intFromFloat(percent_written)..@intFromFloat(percent_total)], '|');
            const bps = self.bytes_per_second();
            const eta = self.formated_eta(bps);
            fmt.log("{Bi:.2} / {?Bi:.2} [{s}] {d:.2}% {Bi:.2}/s {s}\x1B[K\x1B[F", .{
                self.written,
                self.expected_size,
                self.bar,
                percent_total,
                bps,
                eta,
            });
        }
    }
};
