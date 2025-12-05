pub const packages = struct {
    pub const @"1220d1b4dec4b6c15f527212306173fdcb94dbe87843390eaf78b04975b52ff1194e" = struct {
        pub const build_root = "C:\\Users\\Admin\\AppData\\Local\\zig\\p\\raylib-5.6.0-dev-whq8uE4nCQXRtN7EtsFfUnISMGFz_cuU2-h4QzkOr3iw";
        pub const build_zig = @import("1220d1b4dec4b6c15f527212306173fdcb94dbe87843390eaf78b04975b52ff1194e");
        pub const deps: []const struct { []const u8, []const u8 } = &.{
            .{ "xcode_frameworks", "N-V-__8AABHMqAWYuRdIlflwi8gksPnlUMQBiSxAqQAAZFms" },
            .{ "emsdk", "N-V-__8AAJl1DwBezhYo_VE6f53mPVm00R-Fk28NPW7P14EQ" },
            .{ "zemscripten", "zemscripten-0.2.0-dev-sRlDqApRAACspTbAZnuNKWIzfWzSYgYkb2nWAXZ-tqqt" },
        };
    };
    pub const @"N-V-__8AABHMqAWYuRdIlflwi8gksPnlUMQBiSxAqQAAZFms" = struct {
        pub const available = false;
    };
    pub const @"N-V-__8AAJl1DwBezhYo_VE6f53mPVm00R-Fk28NPW7P14EQ" = struct {
        pub const build_root = "C:\\Users\\Admin\\AppData\\Local\\zig\\p\\N-V-__8AAJl1DwBezhYo_VE6f53mPVm00R-Fk28NPW7P14EQ";
        pub const deps: []const struct { []const u8, []const u8 } = &.{};
    };
    pub const @"zemscripten-0.2.0-dev-sRlDqApRAACspTbAZnuNKWIzfWzSYgYkb2nWAXZ-tqqt" = struct {
        pub const build_root = "C:\\Users\\Admin\\AppData\\Local\\zig\\p\\zemscripten-0.2.0-dev-sRlDqApRAACspTbAZnuNKWIzfWzSYgYkb2nWAXZ-tqqt";
        pub const build_zig = @import("zemscripten-0.2.0-dev-sRlDqApRAACspTbAZnuNKWIzfWzSYgYkb2nWAXZ-tqqt");
        pub const deps: []const struct { []const u8, []const u8 } = &.{
        };
    };
};

pub const root_deps: []const struct { []const u8, []const u8 } = &.{
    .{ "raylib", "1220d1b4dec4b6c15f527212306173fdcb94dbe87843390eaf78b04975b52ff1194e" },
};
