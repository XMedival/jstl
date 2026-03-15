const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .optimize = optimize,
        .target = target,
    });

    const exe = b.addExecutable(.{
        .name = "jstl",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .optimize = optimize,
            .target = target,
            .imports = &.{.{.name = "jstl", .module = lib}},
            .link_libc = true,
        })
    });

    exe.addIncludePath(b.path("include/"));
    exe.addCSourceFile(.{
        .language = .c,
        .file = b.path("src/gl.c"),
    });
    exe.linkSystemLibrary("GL");
    exe.linkSystemLibrary("glfw");

    const run_step = b.step("run", "run");
    const run = b.addRunArtifact(exe);
    run_step.dependOn(&run.step);

    const test_step = b.step("test", "test");
    const unit_tests = b.addTest(.{
        .root_module = lib,
    });
    test_step.dependOn(&unit_tests.step);
}
