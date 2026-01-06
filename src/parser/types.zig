pub const OptionInfo = struct {
    shortFormat: ?u8,
    longFormat: []const u8,
    isBool: bool,
};

pub fn OptionsArray(comptime T: type) type {
    const strct = @typeInfo(T).@"struct";
    const fields = strct.fields;
    return [fields.len]OptionInfo;
}

pub fn optionsToArray(comptime T: type) OptionsArray(T) {
    if (!@hasDecl(T, "short")) {
        @compileError("short tuple must be declared in the options type");
    }

    const strct = @typeInfo(T).@"struct";
    const fields = strct.fields;
    var array: OptionsArray(T) = undefined;

    inline for (fields, 0..) |fld, i| {
        array[i] = OptionInfo{
            .isBool = fld.type == bool,
            .longFormat = fld.name,
            .shortFormat = @field(T.short, fld.name),
        };
    }
    return array;
}
