const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const test_runner = std.Build.Step.Compile.TestRunner{
        .path = b.path("test_runner.zig"),
        .mode = .simple,
    };

    const iterator = b.addModule("iterator", .{
        .root_source_file = b.path("src/iterator/lib.zig"),
        .optimize = optimize,
        .target = target,
    });

    const test_step = b.step("test", "run all tests");

    const test_module = b.addModule("tests", .{
        .root_source_file = b.path("tests/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    test_module.addImport("iterator", iterator);

    const iterator_test = b.addTest(.{
        .name = "iterator",
        .root_module = test_module,
        .test_runner = test_runner,
    });

    const iterator_test_run = b.addRunArtifact(iterator_test);
    test_step.dependOn(&iterator_test_run.step);
}
