const std = @import("std");
const material = @import("material.zig");
const vec3 = @import("vec3.zig");

const Camera = @import("camera.zig").Camera;
const Color = @import("color.zig").Color;
const HittableList = @import("hittable.zig").HittableList;
const Point3 = @import("vec3.zig").Point3;
const Sphere = @import("sphere.zig").Sphere;
const Vec3 = @import("vec3.zig").Vec3;

// https://raytracing.github.io/books/RayTracingInOneWeekend.html (14)
// .\zig-out\bin\chapter_14.exe > image.ppm
// zig build -Doptimize=ReleaseFast
pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;

    var buf: [1024]u8 = undefined;
    var writer = std.Io.File.stdout().writer(io, &buf);
    const stdout = &writer.interface;

    const seed: u64 = @intCast(std.Io.Clock.real.now(io).toMilliseconds());
    var prng = std.Random.DefaultPrng.init(seed);
    const rng = prng.random();

    var world = try HittableList.init(gpa);
    defer world.deinit(gpa);

    const materialGround = material.Lambertian.init(
        Color.init(0.5, 0.5, 0.5),
    );

    try world.add(
        gpa,
        Sphere.init(
            Point3.init(0.0, -1000.0, 0.0),
            1000.0,
            materialGround.material(),
        ).hittable(),
    );

    for (0..22) |i| {
        const a: f64 = @as(f64, @floatFromInt(i)) - 11.0;

        for (0..22) |j| {
            const b: f64 = @as(f64, @floatFromInt(j)) - 11.0;

            const chooseMat = rng.float(f64);
            const center = Point3.init(
                a + 0.9 * rng.float(f64),
                0.2,
                b + 0.9 * rng.float(f64),
            );

            if (center.sub(Point3.init(4.0, 0.2, 0.0)).length() > 0.9) {
                if (chooseMat < 0.8) {
                    // diffuse

                    // we have to make sure that these objects live on the heap
                    // and are available for the lifetime of the program
                    // in C++:
                    //    std::make_shared<sphere>(...)
                    // in Zig:
                    //    const sphere = try allocator.create(Sphere);
                    //    sphere.* = Sphere.init(...);
                    const albedo = Color.random(rng).mul(Color.random(rng));
                    const mat = try gpa.create(material.Lambertian);
                    mat.* = material.Lambertian.init(albedo);

                    const sphere = try gpa.create(Sphere);
                    sphere.* = Sphere.init(
                        center,
                        0.2,
                        mat.material(),
                    );

                    try world.add(
                        gpa,
                        sphere.hittable(),
                    );
                } else if (chooseMat < 0.95) {
                    // metal
                    const albedo = Color.randomRange(rng, 0.5, 1);
                    const fuzz = vec3.randomDouble(rng, 0, 0.5);
                    const mat = try gpa.create(material.Metal);
                    mat.* = material.Metal.init(albedo, fuzz);

                    const sphere = try gpa.create(Sphere);
                    sphere.* = Sphere.init(
                        center,
                        0.2,
                        mat.material(),
                    );

                    try world.add(
                        gpa,
                        sphere.hittable(),
                    );
                } else {
                    // glass
                    const mat = try gpa.create(material.Dielectric);
                    mat.* = material.Dielectric.init(1.5);

                    const sphere = try gpa.create(Sphere);
                    sphere.* = Sphere.init(
                        center,
                        0.2,
                        mat.material(),
                    );

                    try world.add(
                        gpa,
                        sphere.hittable(),
                    );
                }
            }
        }
    }

    // the below repetition should be broken out to a generic addObject
    // that asserts to Sphere in this case, and add the object to the HittableList.

    const dm = try gpa.create(material.Dielectric);
    dm.* = material.Dielectric.init(1.5);

    const dmSphere = try gpa.create(Sphere);
    dmSphere.* = Sphere.init(
        Point3.init(0.0, 1.0, 0.0),
        1.0,
        dm.material(),
    );

    try world.add(
        gpa,
        dmSphere.hittable(),
    );

    const lm = try gpa.create(material.Lambertian);
    lm.* = material.Lambertian.init(
        Color.init(0.4, 0.2, 0.1),
    );

    const lmSphere = try gpa.create(Sphere);
    lmSphere.* = Sphere.init(
        Point3.init(-4.0, 1.0, 0.0),
        1.0,
        lm.material(),
    );

    try world.add(
        gpa,
        lmSphere.hittable(),
    );

    const mm = try gpa.create(material.Metal);
    mm.* = material.Metal.init(
        Color.init(0.7, 0.6, 0.5),
        0.0,
    );

    const mmSphere = try gpa.create(Sphere);
    mmSphere.* = Sphere.init(
        Point3.init(4.0, 1.0, 0.0),
        1.0,
        mm.material(),
    );

    try world.add(
        gpa,
        mmSphere.hittable(),
    );

    var cam: Camera = undefined;
    cam.prng = prng; // keep prng alive for the rng interface
    cam.rng = rng; // this should probably be reduced just to prng...?

    cam.aspectRatio = 16.0 / 9.0;
    cam.imageWidth = 1200;
    cam.samplesPerPixel = 50;
    cam.maxDepth = 50;

    cam.vfov = 20;
    cam.lookfrom = Point3.init(13.0, 20.0, 20.0);
    cam.lookat = Point3.init(0.0, 0.0, 0.0);
    cam.vup = Vec3.init(0.0, 1.0, 0.0);

    cam.defocusAngle = 0.6;
    cam.focusDist = 10.0;

    try cam.render(
        stdout,
        &world.hittable(),
    );
}
