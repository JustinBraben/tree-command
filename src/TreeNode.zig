const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const Allocator = mem.Allocator;
const print = std.debug.print;
const ArrayList = std.ArrayList;
const UnicodeIcons = @import("UnicodeIcons.zig");

const TreeNode = @This();

name: []const u8,
kind: fs.Dir.Entry.Kind,
children: ArrayList(*TreeNode),
allocator: Allocator,

pub fn init(allocator: Allocator, name: []const u8, kind: fs.Dir.Entry.Kind) !*TreeNode {
    const node = try allocator.create(TreeNode);
    node.* = TreeNode{
        .name = try allocator.dupe(u8, name),
        .kind = kind,
        .children = ArrayList(*TreeNode).init(allocator),
        .allocator = allocator,
    };
    return node;
}

pub fn deinit(self: *TreeNode) void {
    for (self.children.items) |child| {
        child.deinit();
    }
    self.children.deinit();
    self.allocator.free(self.name);
    self.allocator.destroy(self);
}

pub fn getIcon(self: *TreeNode) []const u8 {
    if (self.kind == .directory) return UnicodeIcons.folder;
    
    if (mem.endsWith(u8, self.name, ".zig")) return UnicodeIcons.zig;

    return UnicodeIcons.file;
}