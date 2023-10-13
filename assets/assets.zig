const std = @import("std");

// TODO: Make better and comptime known values?
fn rootPath() []const u8 {
    comptime {
        return std.fs.path.dirname(@src().file).?;
    }
}

const root_path = rootPath();

pub const fonts = struct {
    pub const roboto_medium = struct {
        pub const path = root_path ++ "/fonts/Roboto-Medium.ttf";
        pub const bytes = @embedFile(path);
    };
};
