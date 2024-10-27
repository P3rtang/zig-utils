const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    _ = b.addModule("iterator", .{ .root_source_file = .{ .path = "src/iterator/lib.zig" }, .optimize = optimize, .target = target });
}
