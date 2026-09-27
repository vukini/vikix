// build.zig — how `zig build` builds this: Zig's build system is a Zig
// program. `zig build run` runs it, `zig build test` runs its tests.
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "comptime",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(exe); // into zig-out/bin/

    const run = b.addRunArtifact(exe);
    run.step.dependOn(b.getInstallStep());
    if (b.args) |args| run.addArgs(args); // zig build run -- ARGS
    b.step("run", "Run the program").dependOn(&run.step);

    const tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.step("test", "Run the tests").dependOn(&b.addRunArtifact(tests).step);
}
