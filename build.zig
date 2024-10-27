const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const iterator_module = b.addStaticLibrary(.{
        .name = "iterator",
        .optimize = optimize,
        .target = target,
        .root_source_file = .{ .cwd_relative = "iterator/lib.zig" },
    });
    b.installArtifact(iterator_module);
}
