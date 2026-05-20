const std = @import("std");
const color = @import("color.zig");
const Color = color.Color;
const Ray = @import("ray.zig").Ray;
const Vec3 = @import("vec3.zig").Vec3;
const Point3 = @import("vec3.zig").Point3;
const Sphere = @import("sphere.zig").Sphere;
const Hittable = @import("hittable.zig").Hittable;
const HitRecord = @import("hittable.zig").HitRecord;
const HittableList = @import("hittable.zig").HittableList;
const Interval = @import("interval.zig").Interval;

fn rayColor(r: Ray, world: Hittable) Color {
    var rec = std.mem.zeroes(HitRecord);
    if (world.hit(
        r,
        Interval.init(0, std.math.inf(f64)),
        &rec,
    )) {
        return rec.normal.add(Color.init(1, 1, 1)).scale(0.5);
    }

    const unitDirection = r.direction.unitVector();
    const a = 0.5 * (unitDirection.y + 1.0);

    // lerp
    // blendedValue=(1−a)⋅startValue+a⋅endValue
    return Color.init(1.0, 1.0, 1.0).scale(1.0 - a)
        .add(Color.init(0.5, 0.7, 1.0).scale(a));
}

// https://raytracing.github.io/books/RayTracingInOneWeekend.html (6)
// .\zig-out\bin\chapter_6.exe > image.ppm
pub fn main(init: std.process.Init) !void {
    var buf: [1024]u8 = undefined;

    var writer = std.Io.File.stdout().writer(init.io, &buf);
    const stdout = &writer.interface;

    // image

    const aspectRatio = 16.0 / 9.0;
    const imageWidth = 400;

    const height: comptime_int = @intFromFloat(
        @as(f64, @floatFromInt(imageWidth)) / aspectRatio,
    );
    const imageHeight = if (height < 1) 1 else height;

    // world

    var world = try HittableList.init(init.gpa);

    try world.add(
        init.gpa,
        Sphere.init(
            Point3.init(0, 0, -1),
            0.5,
        ).hittable(),
    );

    try world.add(
        init.gpa,
        Sphere.init(
            Point3.init(0, -100.5, -1),
            100,
        ).hittable(),
    );

    // camera

    const focalLength = 1.0;
    const viewportHeight = 2.0;
    const viewportWidth = viewportHeight * (@as(f64, @floatFromInt(imageWidth)) / @as(f64, @floatFromInt(imageHeight)));
    const cameraCenter = Point3.init(0, 0, 0);

    // calculate the vectors across the horizontal and down the vertical viewport edges.
    // starting at top left(Q) of viewport

    // across
    const viewportU = Vec3.init(viewportWidth, 0, 0);

    // down
    const viewportV = Vec3.init(0, -viewportHeight, 0);

    // calculate the horizontal and vertical delta vectors from pixel to pixel.

    const pixelDeltaU = viewportU.div(@floatFromInt(imageWidth));
    const pixelDeltaV = viewportV.div(@floatFromInt(imageHeight));

    // calculate the location of the upper left pixel with a half inter-pixel distance buffer from viewport edge.

    const viewportUpperLeft = cameraCenter
        .sub(Vec3.init(0, 0, focalLength))
        .sub(viewportU.div(2.0))
        .sub(viewportV.div(2.0));

    const piexl00Loc = viewportUpperLeft
        .add(pixelDeltaU.add(pixelDeltaV).scale(0.5));

    // render

    try stdout.print("P3\n{} {}\n255\n", .{ imageWidth, imageHeight });
    try stdout.flush();

    for (0..imageHeight) |j| {
        std.log.info("\rScanlines remaining {}", .{imageHeight - j});
        for (0..imageWidth) |i| {
            const pixelCenter = piexl00Loc
                .add(pixelDeltaU.scale(@floatFromInt(i)))
                .add(pixelDeltaV.scale(@floatFromInt(j)));

            const rayDirection = pixelCenter.sub(cameraCenter);

            var pixelColor = rayColor(
                Ray.init(cameraCenter, rayDirection),
                world.hittable(),
            );
            try color.writeColor(stdout, &pixelColor);
        }
    }

    std.log.info("\rDone.\n", .{});
}
