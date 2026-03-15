const std = @import("std");

pub fn build(b: *std.Build) !void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const module = b.addModule("jstl", .{
        .root_source_file = b.path("src/root.zig"),
        .optimize = optimize,
        .target = target,
    });

    const test_step = b.step("test", "Run tests");
    const unit_tests = b.addTest(.{
        .name = "jstl",
        .root_module = module,
    });
    test_step.dependOn(&unit_tests.step);
}
