const std = @import("std");
const testing = std.testing;
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
lines: ArrayList([]const u8),

pub fn init(allocator: Allocator, dir: fs.Dir, base_path: []const u8, args: Args) !Tree {
    return .{
        .allocator = allocator,
        .args = args,
        .walker = try dir.walk(allocator),
        .root = try TreeNode.init(allocator, base_path, .directory),
        .stdout = std.io.getStdOut(),
        .config = tty.detectConfig(std.io.getStdOut()),
        .out = std.io.getStdOut().writer(),
        .lines = ArrayList([]const u8).init(allocator),
    };
}

pub fn deinit(self: *Tree) void {
    self.walker.deinit();
    self.root.deinit();
    for (self.lines.items) |line| {
        self.allocator.free(line);
    }
    self.lines.deinit();
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

        if (self.args.reverse) {
            std.mem.sort(*TreeNode, current_node.children.items, {}, Sort.defaultCompareReverse);
        }
        else {
            // Sort the current directory's children
            std.mem.sort(*TreeNode, current_node.children.items, {}, Sort.defaultCompare);
        }
    }

    if (self.args.reverse) {
        std.mem.sort(*TreeNode, self.root.children.items, {}, Sort.defaultCompareReverse);
    } else {
        // Sort by files, then directories
        std.mem.sort(*TreeNode, self.root.children.items, {}, Sort.defaultCompare);
    }
}

pub fn formatLine(self: *Tree, line: []const u8, is_dir: bool, is_executable: bool) ![]const u8 {
    var formatted = ArrayList(u8).init(self.allocator);
    errdefer formatted.deinit();

    if (is_dir) {
        try formatted.appendSlice("\x1b[1m\x1b[34m"); // bold blue
    } else if (is_executable) {
        try formatted.appendSlice("\x1b[32m"); // green
    }
    
    try formatted.appendSlice(line);
    
    if (is_dir or is_executable) {
        try formatted.appendSlice("\x1b[0m"); // reset
    }

    return try formatted.toOwnedSlice();
}

pub fn printFull(self: *Tree, positional: []const u8) !void {
    // Create the root line
    var root_line = ArrayList(u8).init(self.allocator);
    defer root_line.deinit();
    try root_line.appendSlice(positional);
    
    const formatted_root = try self.formatLine(root_line.items, true, false);
    try self.lines.append(formatted_root);

    // Process children
    for (self.root.children.items, 0..) |child, i| {
        try self.printTree(child, "", i == self.root.children.items.len - 1);
    }
}

pub fn printTree(self: *Tree, node: *TreeNode, prefix: []const u8, is_last: bool) !void {
    // Create the base line without formatting
    var line = ArrayList(u8).init(self.allocator);
    defer line.deinit();

    const icon = node.getIcon();
    const connector = if (is_last) "└──" else "├──";
    
    try line.appendSlice(prefix);
    try line.appendSlice(connector);
    try line.appendSlice(icon);

    const is_executable = if (native_os != .windows) 
        node.kind == .file and !mem.containsAtLeast(u8, node.name, 1, ".")
    else 
        node.kind == .file and mem.endsWith(u8, node.name, ".exe");

    // Add color codes only around the name if needed
    if (node.kind == .directory) {
        try line.appendSlice("\x1b[1m\x1b[34m"); // bold blue
        try line.appendSlice(node.name);
        try line.appendSlice("\x1b[0m");
    } else if (is_executable) {
        try line.appendSlice("\x1b[32m"); // green
        try line.appendSlice(node.name);
        try line.appendSlice("\x1b[0m");
    } else {
        try line.appendSlice(node.name);
    }

    const final_line = try self.allocator.dupe(u8, line.items);
    try self.lines.append(final_line);

    // Create new prefix for children
    var new_prefix = ArrayList(u8).init(self.allocator);
    defer new_prefix.deinit();
    try new_prefix.appendSlice(prefix);
    try new_prefix.appendSlice(if (is_last) "   " else "│  ");

    // Process children
    for (node.children.items, 0..) |child, i| {
        try self.printTree(child, new_prefix.items, i == node.children.items.len - 1);
    }
}

pub fn writeToStdout(self: *Tree) !void {
    const stdout = std.io.getStdOut().writer();
    for (self.lines.items) |line| {
        try stdout.print("{s}\n", .{line});
    }
}

test "tree output format" {
    const test_allocator = std.testing.allocator;

    var args = Args.init_empty(test_allocator);
    defer args.deinit();

    const sub_path = "./src/";

    var current_dir = try fs.cwd().openDir(sub_path, .{ .iterate = true });
    defer current_dir.close();
    var tree = try Tree.init(test_allocator, current_dir, ".", args);
    defer tree.deinit();
    
    try tree.constructTree();
    try tree.printFull(".");
    
    // Now you can check the lines
    try testing.expectEqual(tree.lines.items.len, 7);
    // try testing.expectEqualStrings(tree.lines.items[0], ".");
    try testing.expectEqualStrings(tree.lines.items[1], "├──⚡Sort.zig");
    try testing.expectEqualStrings(tree.lines.items[2], "├──⚡Tree.zig");
    try testing.expectEqualStrings(tree.lines.items[3], "├──⚡TreeNode.zig");
    // ... more assertions ...
}