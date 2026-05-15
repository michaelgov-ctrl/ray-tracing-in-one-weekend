const std = @import("std");
const Camera = @import("camera.zig").Camera;
const HittableList = @import("hittable.zig").HittableList;
const Point3 = @import("vec3.zig").Point3;
const Sphere = @import("sphere.zig").Sphere;

// https://raytracing.github.io/books/RayTracingInOneWeekend.html (7)
// .\zig-out\bin\chapter_7.exe > image.ppm
pub fn main(init: std.process.Init) !void {
    var buf: [1024]u8 = undefined;
    var writer = std.Io.File.stdout().writer(init.io, &buf);
    const stdout = &writer.interface;

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

    var cam = std.mem.zeroes(Camera);
    cam.aspectRatio = 16.0 / 9.0;
    cam.imageWidth = 400;
    try cam.render(stdout, &world.hittable());
}
