const std = @import("std");

fn asF64(x: anytype) f64 {
    return @as(f64, @floatFromInt(x));
}

fn colorByte(f: f64) u8 {
    return @as(u8, @intFromFloat(255.999 * f));
}

// https://raytracing.github.io/books/RayTracingInOneWeekend.html (2.2)
// .\zig-out\bin\ray_tracing.exe > image.ppm
pub fn main(init: std.process.Init) !void {
    var buf: [1024]u8 = undefined;

    var writer = std.Io.File.stdout().writer(init.io, &buf);
    const stdout = &writer.interface;

    const image_width = 256;
    const image_height = 256;

    try stdout.print("P3\n{} {}\n255\n", .{ image_width, image_height });
    try stdout.flush();

    for (0..image_height) |j| {
        std.log.info("\rScanlines remaining {}", .{image_height - j});
        for (0..image_width) |i| {
            const r = asF64(i) / asF64(image_width - 1);
            const g = asF64(j) / asF64(image_height - 1);
            const b = 0.0;

            const ir = colorByte(r);
            const ig = colorByte(g);
            const ib = colorByte(b);

            try stdout.print("{} {} {}\n", .{ ir, ig, ib });
            try stdout.flush();
        }
    }

    std.log.info("\rDone.\n", .{});
}
