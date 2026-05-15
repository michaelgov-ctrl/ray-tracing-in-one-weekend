const std = @import("std");
const color = @import("color.zig");

// https://raytracing.github.io/books/RayTracingInOneWeekend.html (3)
// .\zig-out\bin\chapter_3.exe > image.ppm
pub fn main(init: std.process.Init) !void {
    var buf: [1024]u8 = undefined;

    var writer = std.Io.File.stdout().writer(init.io, &buf);
    const stdout = &writer.interface;

    const imageWidth = 256;
    const imageHeight = 256;

    try stdout.print("P3\n{} {}\n255\n", .{ imageWidth, imageHeight });
    try stdout.flush();

    for (0..imageHeight) |j| {
        std.log.info("\rScanlines remaining {}", .{imageHeight - j});
        for (0..imageWidth) |i| {
            var pixelColor = color.Color.init(
                color.colorConvert(i, imageWidth - 1),
                color.colorConvert(j, imageHeight - 1),
                0,
            );

            try color.writeColor(stdout, &pixelColor);
        }
    }

    std.log.info("\rDone.\n", .{});
}
