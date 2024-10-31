//! Sort functions.
//!
//! This is a collection of sorting functions
//! used to sort the tree view.

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

/// Sorts by files, then directories, alphabetically
pub fn defaultCompare(context: void, a: *TreeNode, b: *TreeNode) bool {
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