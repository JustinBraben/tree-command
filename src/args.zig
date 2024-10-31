const std = @import("std");
const io = std.io;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const builtin = @import("builtin");
const clap = @import("clap");

const Args = @This(); 

allocator: Allocator,
/// Display help
help: bool = false,
/// List all files
all: bool = false,
/// List directories only
dir: bool = false,
/// Print the full path prefix for each file.
full: bool = false,
/// Descend only level directories deep
level: usize = 1,
/// Directories given
positionals: ArrayList([]const u8),

pub fn parse_args(allocator: Allocator) !Args {

    const params = comptime clap.parseParamsComptime(
        \\-h, --help                Display this help and exit.
        \\-a, --all                 All Files are listed.
        \\-d, --dir                 List directories only.
        \\-f, --full                Print the full path prefix for each file.
        \\-L, --level <USIZE>       Descend only level directories deep.
        \\<DIR>...
        \\
    );

    const parsers = comptime .{
        .STR = clap.parsers.string,
        .DIR = clap.parsers.string,
        .USIZE = clap.parsers.int(usize, 10),
    };

    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, parsers, .{
        .diagnostic = &diag,
        .allocator = allocator,
    }) catch |err| {
        diag.report(io.getStdErr().writer(), err) catch {};
        return err;
    };
    defer res.deinit();

    // Write help if -h was passed
    if (res.args.help != 0) {
        try clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
    }

    var level: usize = 1;
    if (res.args.level) |lvl| {
        if (lvl > 0) { 
            level = lvl;
        }
    }

    var positionals = ArrayList([]const u8).init(allocator);
    for (res.positionals[0..]) |pos| {
        const positional = try allocator.dupe(u8, pos);
        try positionals.append(positional);
    }

    return .{
        .allocator = allocator,
        .help = res.args.help != 0,
        .all = res.args.all != 0,
        .dir = res.args.dir != 0,
        .full = res.args.full != 0,
        .level = level,
        .positionals = positionals,
    };
}

pub fn deinit(self: *Args) void {
    for (self.positionals.items) |item| {
        self.allocator.free(item);
    }
    self.positionals.deinit();
}

pub fn debug_args(self: *Args) void {
    std.log.debug(
        \\
        \\       help:            {any}
        \\       all:             {any}
        \\       dir:             {any}
        \\       level:           {d}
        , .{
            self.help,
            self.all,
            self.dir,
            self.level
            });
    std.log.debug("positionals: ", .{});
    for (self.positionals.items) |item| {
        std.log.debug("\t\t\t{s}", .{item});
    }
    // inline for (std.meta.fields(@TypeOf(self.*))) |f| {
    //     std.log.debug(f.name ++ " {any}", .{@as(f.type, @field(self.*, f.name))});
    // }
}