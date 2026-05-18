const std = @import("std");
const material = @import("material.zig");

const Camera = @import("camera.zig").Camera;
const Color = @import("color.zig").Color;
const HittableList = @import("hittable.zig").HittableList;
const Point3 = @import("vec3.zig").Point3;
const Sphere = @import("sphere.zig").Sphere;

// https://raytracing.github.io/books/RayTracingInOneWeekend.html (10)
// .\zig-out\bin\chapter_10.exe > image.ppm
pub fn main(init: std.process.Init) !void {
    var buf: [1024]u8 = undefined;
    var writer = std.Io.File.stdout().writer(init.io, &buf);
    const stdout = &writer.interface;

    var world = try HittableList.init(init.gpa);

    const materialGround = material.Labertian.init(Color.init(0.8, 0.8, 0.0));
    const materialCenter = material.Labertian.init(Color.init(0.1, 0.2, 0.5));
    const materialLeft = material.Metal.init(Color.init(0.8, 0.8, 0.8), 0.3);
    const materialRight = material.Metal.init(Color.init(0.8, 0.6, 0.2), 1.0);

    try world.add(
        init.gpa,
        Sphere.init(
            Point3.init(0.0, -100.5, -1.0),
            100.0,
            materialGround.material(),
        ).hittable(),
    );

    try world.add(
        init.gpa,
        Sphere.init(
            Point3.init(0.0, 0.0, -1.2),
            0.5,
            materialCenter.material(),
        ).hittable(),
    );

    try world.add(
        init.gpa,
        Sphere.init(
            Point3.init(-1.0, 0.0, -1.0),
            0.5,
            materialLeft.material(),
        ).hittable(),
    );

    try world.add(
        init.gpa,
        Sphere.init(
            Point3.init(1.0, 0.0, -1.0),
            0.5,
            materialRight.material(),
        ).hittable(),
    );

    var cam: Camera = undefined;
    cam.aspectRatio = 16.0 / 9.0;
    cam.imageWidth = 400;
    cam.samplesPerPixel = 100;
    cam.maxDepth = 50;

    try cam.render(
        init.io,
        stdout,
        &world.hittable(),
    );
}
