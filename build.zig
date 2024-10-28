const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    _ = b.addModule("iterator", .{ .root_source_file = .{ .path = "src/iterator/lib.zig" }, .optimize = optimize, .target = target });

    const test_step = b.step("test", "run all tests");

    try SetupTestDir(b, test_step, .{ .path = "testing", .config = .{ .module_deps = &.{"iterator"} } });
}

fn SetupModules(b: *std.Build, parent_mod: *std.Build.Module, mods: []const Module) !void {
    for (mods) |m| {
        const mod = b.addModule(m.name, .{
            .root_source_file = m.path,
        });

        parent_mod.addImport(m.name, mod);

        for (m.module_deps) |dep| {
            mod.addImport(dep, b.modules.get(dep).?);
        }
    }
}

fn SetupTests(b: *std.Build, step: *std.Build.Step, list: []const Test) void {
    for (list) |t| {
        SetupTest(b, step, t);
    }
}

fn SetupTest(b: *std.Build, step: *std.Build.Step, t: Test) void {
    const c = b.addTest(.{
        .name = t.name,
        .root_source_file = t.path,
        .test_runner = b.path("test_runner.zig"),
    });

    if (t.config.useLibC) {
        c.linkLibC();
    }

    for (t.config.system_libs) |lib| {
        c.linkSystemLibrary(lib);
    }

    for (t.config.module_deps) |dep| {
        c.root_module.addImport(dep, b.modules.get(dep).?);
    }

    const run = b.addRunArtifact(c);
    run.has_side_effects = true;
    step.dependOn(&run.step);
}

fn SetupTestDir(b: *std.Build, step: *std.Build.Step, test_dir: TestDir) !void {
    const lazy_path = b.path(test_dir.path);
    const dir_path = lazy_path.getPath(b);
    const dir = try std.fs.openDirAbsolute(dir_path, .{ .iterate = true });
    var iter = dir.iterate();
    while (try iter.next()) |f| {
        switch (f.kind) {
            .file => {
                if (!std.mem.eql(u8, std.fs.path.extension(f.name), ".zig")) {
                    continue;
                }
                SetupTest(b, step, .{
                    .name = f.name,
                    .path = b.path(b.pathJoin(&.{ test_dir.path, f.name })),
                    .config = test_dir.config,
                });
            },
            .directory => {
                try SetupTestDir(b, step, TestDir{
                    .path = b.pathJoin(&.{ test_dir.path, f.name }),
                    .config = test_dir.config,
                });
            },
            else => {},
        }
    }
}

fn SetupTestDirs(b: *std.Build, step: *std.Build.Step, list: []const TestDir) !void {
    for (list) |d| {
        try SetupTestDir(b, step, d);
    }
}

const Module = struct {
    name: []const u8,
    path: std.Build.LazyPath,
    module_deps: []const []const u8 = &.{},
};

const Test = struct {
    name: []const u8,
    path: std.Build.LazyPath,
    config: TestConfig,
};

const TestDir = struct {
    path: []const u8,
    config: TestConfig = .{},
};

const TestConfig = struct {
    module_deps: []const []const u8 = &.{},
    system_libs: []const []const u8 = &.{},
    useLibC: bool = false,
};
