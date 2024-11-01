const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const Allocator = mem.Allocator;
const io = std.io;
const tty = io.tty;
const print = std.debug.print;
const ArrayList = std.ArrayList;
const Args = @import("args.zig");
const TreeNode = @import("TreeNode.zig");
const Tree = @import("Tree.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var args = try Args.parse_args(allocator);
    defer args.deinit();

    // If -h was passed help will be displayed
    // program will exit gracefully
    if (args.help) {
        return;
    }

    // No positionals passed, just do cwd which is "."
    if (args.positionals.items.len < 1) {
        const sub_path = ".";
        var current_dir = try fs.cwd().openDir(sub_path, .{ .iterate = true });
        defer current_dir.close();

        var tree = try Tree.init(allocator, current_dir, sub_path, args);
        defer tree.deinit();

        try tree.constructTree();

        try tree.printFull(sub_path);

        try tree.writeToStdout();
    }
    // Do each dir passed
    else {
        for (args.positionals.items) |sub_path| {
            var current_dir = try fs.cwd().openDir(sub_path, .{ .iterate = true });
            defer current_dir.close();

            var tree = try Tree.init(allocator, current_dir, sub_path, args);
            defer tree.deinit();

            try tree.constructTree();

            try tree.printFull(sub_path);

            try tree.writeToStdout();
        }
    }
}

test {
    _ = @import("Tree.zig");
}