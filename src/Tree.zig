const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const Allocator = mem.Allocator;
const io = std.io;
const tty = io.tty;
const print = std.debug.print;
const ArrayList = std.ArrayList;
const builtin = @import("builtin");
const native_os = builtin.os.tag;
const Args = @import("args.zig");
const TreeNode = @import("TreeNode.zig");
const Sort = @import("Sort.zig");

const Tree = @This();

allocator: Allocator,
args: Args,
walker: fs.Dir.Walker,
root: *TreeNode,
stdout: std.fs.File,
config: tty.Config,
out: std.fs.File.Writer,

pub fn init(allocator: Allocator, dir: fs.Dir, base_path: []const u8, args: Args) !Tree {
    return .{
        .allocator = allocator,
        .args = args,
        .walker = try dir.walk(allocator),
        .root = try TreeNode.init(allocator, base_path, .directory),
        .stdout = std.io.getStdOut(),
        .config = tty.detectConfig(std.io.getStdOut()),
        .out = std.io.getStdOut().writer(),
    };
}

pub fn deinit(self: *Tree) void {
    self.walker.deinit();
    self.root.deinit();
}

pub fn constructTree(self: *Tree) !void {
    while (try self.walker.next()) |entry| {
        if (mem.eql(u8, entry.path, "")) continue;

        // Based on args, skip certain files/directories
        if (!self.args.all) {
            if (mem.startsWith(u8, entry.path, ".")) continue;
        }

        if (self.args.dir) {
            if (entry.kind != .directory) continue;
        }

        // Split the path into components
        var path_components = std.ArrayList([]const u8).init(self.allocator);
        defer path_components.deinit();

        var it = switch (native_os) {
            .windows => std.mem.splitSequence(u8, entry.path, "\\"),
            else => std.mem.splitSequence(u8, entry.path, "/"),
        };
        while (it.next()) |component| {
            try path_components.append(component);
        }


        // Traverse or create nodes
        var current_node = self.root;
        for (path_components.items[0 .. path_components.items.len - 1]) |component| {
            var found = false;
            for (current_node.children.items) |child| {
                if (std.mem.eql(u8, child.name, component)) {
                    current_node = child;
                    found = true;
                    break;
                }
            }
            if (!found) {
                const new_node = try TreeNode.init(self.allocator, component, .directory);
                try current_node.children.append(new_node);
                current_node = new_node;
            }
        }

        // TODO: Implement full paths for each TreeNode
        if (self.args.full) {
            // try path_components.append("./");
            // const new_name = "./" ++ current_node.name;
            // self.allocator.free(current_node.name);
            // const new_name = self.allocator.dupe(u8, "./" ++ current_node.name);
            // std.mem.copyForwards(u8, current_node.name, new_name);
        }

        // Add the final component
        const leaf_node = try TreeNode.init(self.allocator, path_components.items[path_components.items.len - 1], entry.kind);
        try current_node.children.append(leaf_node);

        // Sort the current directory's children
        std.mem.sort(*TreeNode, current_node.children.items, {}, Sort.defaultCompare);
    }

    // Sort by files, then directories
    std.mem.sort(*TreeNode, self.root.children.items, {}, Sort.defaultCompare);
}

pub fn printFull(self: *Tree, positional: []const u8) !void {
    // print the positional
    try self.config.setColor(self.out, .bold);
    try self.config.setColor(self.out, .blue);
    try self.out.print("{s}\n", .{positional});

    try self.config.setColor(self.out, .reset);
    try self.config.setColor(self.out, .white);
    // Skip the root node's children and print them directly
    for (self.root.children.items, 0..) |child, i| {
        try self.printTree(child, "", i == self.root.children.items.len - 1);
    }
}

pub fn printTree(self: *Tree, node: *TreeNode, prefix: []const u8, is_last: bool) !void {
    // Print the current node, will always be white
    const icon = node.getIcon();
    const connector = if (is_last) "└──" else "├──";
    try self.out.print("{s}{s}{s}", .{ prefix, connector, icon });

    if (node.kind == .directory) {
        try self.config.setColor(self.out, .bold);
        try self.config.setColor(self.out, .blue);
    }
    // Sets executables as green
    if (node.kind == .file) {
        if (native_os != .windows and !mem.containsAtLeast(u8, node.name, 1, ".")) {
            try self.config.setColor(self.out, .green);
        }

        if (native_os == .windows and mem.endsWith(u8, node.name, ".exe")) {
            try self.config.setColor(self.out, .green);
        }
    }
    try self.out.print("{s}\n", .{ node.name });

    // Reset color always
    try self.config.setColor(self.out, .reset);
    try self.config.setColor(self.out, .white);

    // Prepare prefix for children
    var new_prefix = std.ArrayList(u8).init(node.allocator);
    defer new_prefix.deinit();
    try new_prefix.appendSlice(prefix);
    try new_prefix.appendSlice(if (is_last) "   " else "│  ");

    // Print children
    for (node.children.items, 0..) |child, i| {
        try self.printTree(child, new_prefix.items, i == node.children.items.len - 1);
    }
}