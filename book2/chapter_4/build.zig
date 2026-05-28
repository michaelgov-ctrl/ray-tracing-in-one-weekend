const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    var mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    mod.addIncludePath(b.path("external"));
    mod.addCSourceFile(.{
        .file = b.path("external/stb_image_impl.c"),
        .flags = &.{},
    });

    const exe = b.addExecutable(.{
        .name = "chapter_4",
        .root_module = mod,
    });

    b.installArtifact(exe);
}
