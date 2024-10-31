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

const Tree = @This();

allocator: Allocator,
args: Args,
walker: fs.Dir.Walker,
root: *TreeNode,

pub fn init(allocator: Allocator, dir: fs.Dir, base_path: []const u8, args: Args) !Tree {
    return .{
        .allocator = allocator,
        .args = args,
        .walker = try dir.walk(allocator),
        .root = try TreeNode.init(allocator, base_path, .directory),
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
        if (mem.startsWith(u8, entry.path, ".")) continue;

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

        // Add the final component
        const leaf_node = try TreeNode.init(self.allocator, path_components.items[path_components.items.len - 1], entry.kind);
        try current_node.children.append(leaf_node);

        // Sort the current directory's children
        std.mem.sort(*TreeNode, current_node.children.items, {}, compareNodes);
    }

    // Sort by files, then directories
    std.mem.sort(*TreeNode, self.root.children.items, {}, compareNodes);
}

pub fn printFull(self: *Tree, positional: []const u8) !void {
    const stdout = std.io.getStdOut();
    const config = tty.detectConfig(stdout);
    const out = stdout.writer();

    // print the positional
    try config.setColor(out, .blue);
    try out.print("{s}\n", .{positional});

    try config.setColor(out, .white);
    // Skip the root node's children and print them directly
    for (self.root.children.items, 0..) |child, i| {
        try printTree(child, "", i == self.root.children.items.len - 1);
    }
}

pub fn printTree(node: *TreeNode, prefix: []const u8, is_last: bool) !void {
    const stdout = std.io.getStdOut();
    const config = tty.detectConfig(stdout);
    const out = stdout.writer();

    // Print the current node
    const icon = if (node.kind == .directory) "📁" else "📄";
    const connector = if (is_last) "└──" else "├──";
    try out.print("{s}{s}{s}", .{ prefix, connector, icon });
    if (node.kind == .directory) {
        try config.setColor(out, .blue);
    }
    try out.print("{s}\n", .{ node.name });

    // Reset color always
    try config.setColor(out, .white);

    // Prepare prefix for children
    var new_prefix = std.ArrayList(u8).init(node.allocator);
    defer new_prefix.deinit();
    try new_prefix.appendSlice(prefix);
    try new_prefix.appendSlice(if (is_last) "   " else "│  ");

    // Print children
    for (node.children.items, 0..) |child, i| {
        try printTree(child, new_prefix.items, i == node.children.items.len - 1);
    }
}

/// Sorts by files, then directories, alphabetically
fn compareNodes(context: void, a: *TreeNode, b: *TreeNode) bool {
    _ = context;
    // If one is a file and the other is a directory, files come first
    if (a.kind != b.kind) {
        return a.kind != .directory;
    }
    // If both are the same type (files or directories), sort alphabetically
    return std.mem.order(u8, a.name, b.name) == .lt;
}

fn filesThenDirectories(context: void, a: *TreeNode, b: *TreeNode) bool {
    _ = context;
    return dirKindToInt(a.kind) < dirKindToInt(b.kind);
}

fn dirKindToInt(kind: std.fs.Dir.Entry.Kind) u8 {
    return switch (kind) {
        .block_device => 0,
        .character_device => 1,
        .directory => 2,
        .door => 3,
        .event_port => 4,
        .file => 5,
        .named_pipe => 6,
        .sym_link => 7,
        .unix_domain_socket => 8,
        .unknown => 9,
        .whiteout => 10,
    };
}