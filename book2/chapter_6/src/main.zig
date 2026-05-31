const std = @import("std");
const material = @import("material.zig");
const tex = @import("texture.zig");
const vec3 = @import("vec3.zig");

const BVHNode = @import("bvh.zig").BVHNode;
const Camera = @import("camera.zig").Camera;
const Color = @import("color.zig").Color;
const HittableList = @import("hittable.zig").HittableList;
const Perlin = @import("perlin.zig").Perlin;
const Point3 = @import("vec3.zig").Point3;
const Quad = @import("quad.zig").Quad;
const RtwImage = @import("rtw_image.zig").RtwImage;
const Sphere = @import("sphere.zig").Sphere;
const Vec3 = @import("vec3.zig").Vec3;

// .\zig-out\bin\*.exe > image.ppm
// zig build -Doptimize=ReleaseFast
pub fn main(init: std.process.Init) !void {
    const arena = init.arena;
    const io = init.io;

    switch (5) {
        1 => return bouncingSpheres(arena.allocator(), io),
        2 => return checkeredSpheres(arena.allocator(), io),
        3 => return earth(arena.allocator(), io),
        4 => return perlinSpheres(arena.allocator(), io),
        5 => return quads(arena.allocator(), io),
        else => unreachable,
    }
}

fn quads(gpa: std.mem.Allocator, io: std.Io) !void {
    var buf: [1024]u8 = undefined;
    var writer = std.Io.File.stdout().writer(io, &buf);
    const stdout = &writer.interface;

    var world = try HittableList.init(gpa);
    defer world.deinit(gpa);

    // Materials
    const red = material.Lambertian.initFromTexture(
        tex.SolidColor.initFromAlbedo(
            Color.init(1.0, 0.2, 0.2),
        ).texture(),
    );

    const green = material.Lambertian.initFromTexture(
        tex.SolidColor.initFromAlbedo(
            Color.init(0.2, 1.0, 0.2),
        ).texture(),
    );

    const blue = material.Lambertian.initFromTexture(
        tex.SolidColor.initFromAlbedo(
            Color.init(0.2, 0.2, 1.0),
        ).texture(),
    );

    const orange = material.Lambertian.initFromTexture(
        tex.SolidColor.initFromAlbedo(
            Color.init(1.0, 0.5, 0.0),
        ).texture(),
    );

    const teal = material.Lambertian.initFromTexture(
        tex.SolidColor.initFromAlbedo(
            Color.init(0.2, 0.8, 0.8),
        ).texture(),
    );

    // Quads
    const left_quad = Quad.init(
        Point3.init(-3.0, -2.0, 5.0),
        Vec3.init(0.0, 0.0, -4.0),
        Vec3.init(0.0, 4.0, 0.0),
        red.material(),
    );
    try world.add(
        gpa,
        left_quad.hittable(),
    );

    const back_quad = Quad.init(
        Point3.init(-2.0, -2.0, 0.0),
        Vec3.init(4.0, 0.0, 0.0),
        Vec3.init(0.0, 4.0, 0.0),
        green.material(),
    );
    try world.add(
        gpa,
        back_quad.hittable(),
    );

    const right_quad = Quad.init(
        Point3.init(3.0, -2.0, 1.0),
        Vec3.init(0.0, 0.0, 4.0),
        Vec3.init(0.0, 4.0, 0.0),
        blue.material(),
    );
    try world.add(
        gpa,
        right_quad.hittable(),
    );

    const upper_quad = Quad.init(
        Point3.init(-2.0, 3.0, 1.0),
        Vec3.init(4.0, 0.0, 0.0),
        Vec3.init(0.0, 0.0, 4.0),
        orange.material(),
    );
    try world.add(
        gpa,
        upper_quad.hittable(),
    );

    const lower_quad = Quad.init(
        Point3.init(-2.0, -3.0, 5.0),
        Vec3.init(4.0, 0.0, 0.0),
        Vec3.init(0.0, 0.0, -4.0),
        teal.material(),
    );
    try world.add(
        gpa,
        lower_quad.hittable(),
    );

    // Camera
    const seed: u64 = @intCast(std.Io.Clock.real.now(io).toMilliseconds());
    const prng = std.Random.DefaultPrng.init(seed);

    var cam: Camera = undefined;
    cam.prng = prng; // keep prng alive for the rng interface
    cam.rng = cam.prng.random(); // this should probably be reduced just to prng...?

    cam.aspectRatio = 1.0;
    cam.imageWidth = 800;
    cam.samplesPerPixel = 200;
    cam.maxDepth = 100;

    cam.vfov = 80.0;
    cam.lookfrom = Point3.init(0.0, 0.0, 9.0);
    cam.lookat = Point3.init(0.0, 0.0, 0.0);
    cam.vup = Vec3.init(0.0, 1.0, 0.0);

    cam.defocusAngle = 0.0;
    cam.focusDist = 10.0;

    try cam.render(
        stdout,
        &world.hittable(),
    );
}

fn perlinSpheres(gpa: std.mem.Allocator, io: std.Io) !void {
    var buf: [1024]u8 = undefined;
    var writer = std.Io.File.stdout().writer(io, &buf);
    const stdout = &writer.interface;

    const seed: u64 = @intCast(std.Io.Clock.real.now(io).toMilliseconds());
    var prng = std.Random.DefaultPrng.init(seed);

    var world = try HittableList.init(gpa);
    defer world.deinit(gpa);

    const noise = Perlin.init(prng.random());

    const noise_texture = try gpa.create(tex.NoiseTexture);
    noise_texture.* = tex.NoiseTexture.init(noise, 4.0);

    const noise_material = try gpa.create(material.Lambertian);
    noise_material.* = material.Lambertian.initFromTexture(noise_texture.texture());

    const bottom_sphere = try gpa.create(Sphere);
    bottom_sphere.* = Sphere.initStationary(
        Point3.init(0.0, -1000.0, 0.0),
        1000.0,
        noise_material.material(),
    );

    try world.add(
        gpa,
        bottom_sphere.hittable(),
    );

    const top_sphere = try gpa.create(Sphere);
    top_sphere.* = Sphere.initStationary(
        Point3.init(0.0, 2.0, 1.0),
        2.0,
        noise_material.material(),
    );

    try world.add(
        gpa,
        top_sphere.hittable(),
    );

    var cam: Camera = undefined;
    cam.prng = prng; // keep prng alive for the rng interface
    cam.rng = cam.prng.random(); // this should probably be reduced just to prng...?

    cam.aspectRatio = 16.0 / 9.0;
    cam.imageWidth = 800;
    cam.samplesPerPixel = 200;
    cam.maxDepth = 100;

    cam.vfov = 20.0;
    cam.lookfrom = Point3.init(13.0, 2.0, 3.0);
    cam.lookat = Point3.init(0.0, 0.0, 0.0);
    cam.vup = Vec3.init(0.0, 1.0, 0.0);

    cam.defocusAngle = 0.0;
    cam.focusDist = 10.0;

    try cam.render(
        stdout,
        &world.hittable(),
    );
}

fn earth(gpa: std.mem.Allocator, io: std.Io) !void {
    var buf: [1024]u8 = undefined;
    var writer = std.Io.File.stdout().writer(io, &buf);
    const stdout = &writer.interface;

    var world = try HittableList.init(gpa);
    defer world.deinit(gpa);

    const earth_texture = try gpa.create(tex.ImageTexture);
    earth_texture.* = try tex.ImageTexture.initFromFile(gpa, "earthmap.jpg");

    const earth_surface = try gpa.create(material.Lambertian);
    earth_surface.* = material.Lambertian.initFromTexture(earth_texture.texture());

    const globe = try gpa.create(Sphere);
    globe.* = Sphere.initStationary(
        Point3.init(0.0, 0.0, 0.0),
        2.0,
        earth_surface.material(),
    );

    try world.add(
        gpa,
        globe.hittable(),
    );

    const seed: u64 = @intCast(std.Io.Clock.real.now(io).toMilliseconds());

    var cam: Camera = undefined;
    cam.prng = std.Random.DefaultPrng.init(seed); // keep prng alive for the rng interface
    cam.rng = cam.prng.random(); // this should probably be reduced just to prng...?

    cam.aspectRatio = 16.0 / 9.0;
    cam.imageWidth = 400;
    cam.samplesPerPixel = 100;
    cam.maxDepth = 50;

    cam.vfov = 20.0;
    cam.lookfrom = Point3.init(0.0, 0.0, 12.0);
    cam.lookat = Point3.init(0.0, 0.0, 0.0);
    cam.vup = Vec3.init(0.0, 1.0, 0.0);

    cam.defocusAngle = 0.0;
    cam.focusDist = 10.0;

    try cam.render(
        stdout,
        &world.hittable(),
    );
}

fn checkeredSpheres(gpa: std.mem.Allocator, io: std.Io) !void {
    var buf: [1024]u8 = undefined;
    var writer = std.Io.File.stdout().writer(io, &buf);
    const stdout = &writer.interface;

    const seed: u64 = @intCast(std.Io.Clock.real.now(io).toMilliseconds());
    var prng = std.Random.DefaultPrng.init(seed);
    const rng = prng.random();

    var world = try HittableList.init(gpa);
    defer world.deinit(gpa);

    const checker = try gpa.create(tex.CheckerTexture);
    checker.* = tex.CheckerTexture.initFromColors(
        0.32,
        Color.init(
            0.2,
            0.3,
            0.1,
        ),
        Color.init(
            0.9,
            0.9,
            0.9,
        ),
    );

    const checkerMaterial = try gpa.create(material.Lambertian);
    checkerMaterial.* = material.Lambertian.initFromTexture(checker.texture());

    const bottomSphere = try gpa.create(Sphere);
    bottomSphere.* = Sphere.initStationary(
        Point3.init(0.0, -10.0, 0.0),
        10.0,
        checkerMaterial.material(),
    );

    try world.add(
        gpa,
        bottomSphere.hittable(),
    );

    const topSphere = try gpa.create(Sphere);
    topSphere.* = Sphere.initStationary(
        Point3.init(0.0, 10.0, 0.0),
        10.0,
        checkerMaterial.material(),
    );

    try world.add(
        gpa,
        topSphere.hittable(),
    );

    var cam: Camera = undefined;
    cam.prng = prng; // keep prng alive for the rng interface
    cam.rng = rng; // this should probably be reduced just to prng...?

    cam.aspectRatio = 16.0 / 9.0;
    cam.imageWidth = 400;
    cam.samplesPerPixel = 100;
    cam.maxDepth = 50;

    cam.vfov = 20;
    cam.lookfrom = Point3.init(13.0, 2.0, 3.0);
    cam.lookat = Point3.init(0.0, 0.0, 0.0);
    cam.vup = Vec3.init(0.0, 1.0, 0.0);

    cam.defocusAngle = 0.6;
    cam.focusDist = 10.0;

    try cam.render(
        stdout,
        &world.hittable(),
    );
}

fn bouncingSpheres(gpa: std.mem.Allocator, io: std.Io) !void {
    var buf: [1024]u8 = undefined;
    var writer = std.Io.File.stdout().writer(io, &buf);
    const stdout = &writer.interface;

    const seed: u64 = @intCast(std.Io.Clock.real.now(io).toMilliseconds());
    var prng = std.Random.DefaultPrng.init(seed);
    const rng = prng.random();

    var world = try HittableList.init(gpa);
    defer world.deinit(gpa);

    const checker = try gpa.create(tex.CheckerTexture);
    checker.* = tex.CheckerTexture.initFromColors(
        0.32,
        Color.init(
            0.2,
            0.3,
            0.1,
        ),
        Color.init(
            0.9,
            0.9,
            0.9,
        ),
    );

    const materialGround = try gpa.create(material.Lambertian);
    materialGround.* = material.Lambertian.initFromTexture(checker.texture());

    const primarySphere = try gpa.create(Sphere);
    primarySphere.* = Sphere.initStationary(
        Point3.init(0.0, -1000.0, 0.0),
        1000.0,
        materialGround.material(),
    );

    try world.add(
        gpa,
        primarySphere.hittable(),
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

            // we have to make sure that these objects live on the heap
            // and are available for the lifetime of the program
            // in C++:
            //    std::make_shared<sphere>(...)
            // in Zig:
            //    const sphere = try allocator.create(Sphere);
            //    sphere.* = Sphere.initStationary(...);

            if (center.sub(Point3.init(4.0, 0.2, 0.0)).length() > 0.9) {
                if (chooseMat < 0.8) {
                    // diffuse

                    const albedo = Color.random(rng).mul(Color.random(rng));

                    const solid = try gpa.create(tex.SolidColor);
                    solid.* = tex.SolidColor.initFromAlbedo(albedo);

                    const mat = try gpa.create(material.Lambertian);
                    mat.* = material.Lambertian.initFromTexture(solid.texture());

                    const center2 = center.add(
                        Vec3.init(
                            0.0,
                            vec3.randomDouble(
                                rng,
                                0.0,
                                0.5,
                            ),
                            0,
                        ),
                    );

                    const sphere = try gpa.create(Sphere);
                    sphere.* = Sphere.initMoving(
                        center,
                        center2,
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
                    sphere.* = Sphere.initStationary(
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
                    sphere.* = Sphere.initStationary(
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
    dmSphere.* = Sphere.initStationary(
        Point3.init(0.0, 1.0, 0.0),
        1.0,
        dm.material(),
    );

    try world.add(
        gpa,
        dmSphere.hittable(),
    );

    const lmTexture = try gpa.create(tex.SolidColor);
    lmTexture.* = tex.SolidColor.initFromAlbedo(
        Color.init(0.4, 0.2, 0.1),
    );

    const lm = try gpa.create(material.Lambertian);
    lm.* = material.Lambertian.initFromTexture(lmTexture.texture());

    const lmSphere = try gpa.create(Sphere);
    lmSphere.* = Sphere.initStationary(
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
    mmSphere.* = Sphere.initStationary(
        Point3.init(4.0, 1.0, 0.0),
        1.0,
        mm.material(),
    );

    try world.add(
        gpa,
        mmSphere.hittable(),
    );

    const bvh = try gpa.create(BVHNode);
    bvh.* = try BVHNode.initFromList(gpa, world, rng);

    world.clear();
    try world.add(gpa, bvh.hittable());

    var cam: Camera = undefined;
    cam.prng = prng; // keep prng alive for the rng interface
    cam.rng = rng; // this should probably be reduced just to prng...?

    cam.aspectRatio = 16.0 / 9.0;
    cam.imageWidth = 600;
    cam.samplesPerPixel = 200;
    cam.maxDepth = 25;

    cam.vfov = 20;
    cam.lookfrom = Point3.init(13.0, 2.0, 3.0);
    cam.lookat = Point3.init(0.0, 0.0, 0.0);
    cam.vup = Vec3.init(0.0, 1.0, 0.0);

    cam.defocusAngle = 0.6;
    cam.focusDist = 10.0;

    try cam.render(
        stdout,
        &world.hittable(),
    );
}
