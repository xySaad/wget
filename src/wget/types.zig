pub const Options = struct {
    const str = [:0]const u8;
    directoryPrefix: str,
    outputDocument: str,
    limitRate: str,
    inputFile: str,

    background: bool,
    mirror: bool,

    pub const short = .{
        .background = 'b',
        .outputDocument = 'O',
        .directoryPrefix = 'P',
        .limitRate = null,
        .mirror = 'm',
        .inputFile = 'i',
    };
};
