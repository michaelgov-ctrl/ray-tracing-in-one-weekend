const std = @import("std");
const hittable = @import("hittable.zig");
const material = @import("material.zig");
const tex = @import("texture.zig");
const vec3 = @import("vec3.zig");

const Camera = @import("camera.zig").Camera;
const Color = @import("color.zig").Color;
const HittableList = @import("hittable.zig").HittableList;
const Point3 = @import("vec3.zig").Point3;
const RotateY = @import("hittable.zig").RotateY;
const RtwImage = @import("rtw_image.zig").RtwImage;
const Sphere = @import("sphere.zig").Sphere;
const Vec3 = @import("vec3.zig").Vec3;

// .\zig-out\bin\*.exe > image.ppm
// zig build -Doptimize=ReleaseFast
pub fn main(init: std.process.Init) !void {
    const arena = init.arena;
    const io = init.io;

    try chocoverse(
        arena.allocator(),
        io,
        800,
        20000,
        120,
    );
}

fn chocoverse(
    allocator: std.mem.Allocator,
    io: std.Io,
    imageWidth: usize,
    samplesPerPixel: usize,
    maxDepth: i64,
) !void {
    var buf: [1024]u8 = undefined;
    var writer = std.Io.File.stdout().writer(io, &buf);
    const stdout = &writer.interface;

    const seed: u64 = @intCast(std.Io.Clock.real.now(io).toMilliseconds());
    const prng = std.Random.DefaultPrng.init(seed);
    //const rng = prng.random();

    var world = try HittableList.init(allocator);
    defer world.deinit(allocator);

    // sun light source
    const sun_tex = try tex.ImageTexture.initFromFile(
        allocator,
        "sun.jpg",
    );

    const sun_light = material.DiffuseLight.initFromTexture(
        sun_tex.texture(),
    );

    try world.add(
        allocator,
        Sphere.initStationary(
            Point3.init(500.0, 600.0, 100.0),
            65.0,
            sun_light.material(),
        ).hittable(),
    );

    // chocolatey earth sphere
    const choco_tex = try tex.ImageTexture.initFromFile(
        allocator,
        "choco.png",
    );
    const choco_mat = material.Lambertian.initFromTexture(choco_tex.texture());
    const choco_sphere = Sphere.initStationary(
        Point3.init(0.0, 0.0, 0.0),
        300.0,
        choco_mat.material(),
    );

    const choco_sphere_roty = try allocator.create(RotateY);
    choco_sphere_roty.* = RotateY.init(choco_sphere.hittable(), 140.0);

    try world.add(
        allocator,
        choco_sphere_roty.hittable(),
    );

    // moon
    const moon_tex = try tex.ImageTexture.initFromFile(
        allocator,
        "moon.jpg",
    );
    const moon_mat = material.Lambertian.initFromTexture(moon_tex.texture());

    try world.add(
        allocator,
        Sphere.initStationary(
            Point3.init(-650.0, 200.0, -350.0),
            38.0,
            moon_mat.material(),
        ).hittable(),
    );

    // backlight
    const back_light = material.DiffuseLight.initFromTexture(
        tex.SolidColor.initFromAlbedo(
            Color.init(1.0, 1.0, 1.0),
        ).texture(),
    );

    try world.add(
        allocator,
        Sphere.initStationary(
            Point3.init(-1000.0, 400.0, -6000.0),
            5000.0,
            back_light.material(),
        ).hittable(),
    );

    // camera
    var cam: Camera = undefined;
    cam.prng = prng; // keep prng alive for the rng interface
    cam.rng = cam.prng.random(); // this should probably be reduced just to prng...?

    cam.aspectRatio = 1.0;
    cam.imageWidth = imageWidth;
    cam.samplesPerPixel = samplesPerPixel;
    cam.maxDepth = maxDepth;
    cam.background = Color.init(0.0, 0.0, 0.03);

    cam.vfov = 40.0;
    cam.lookfrom = Point3.init(-1000.0, 200.0, -1000.0);
    cam.lookat = Point3.init(0.0, 200.0, 0.0);
    cam.vup = Vec3.init(0.0, 1.0, 0.0);

    cam.defocusAngle = 0.0;
    cam.focusDist = 10.0;

    try cam.render(
        stdout,
        &world.hittable(),
    );
}
