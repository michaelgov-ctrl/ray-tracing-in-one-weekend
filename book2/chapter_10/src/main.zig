const std = @import("std");
const hittable = @import("hittable.zig");
const material = @import("material.zig");
const quad = @import("quad.zig");
const tex = @import("texture.zig");
const vec3 = @import("vec3.zig");

const BVHNode = @import("bvh.zig").BVHNode;
const Camera = @import("camera.zig").Camera;
const Color = @import("color.zig").Color;
const HittableList = @import("hittable.zig").HittableList;
const Perlin = @import("perlin.zig").Perlin;
const Point3 = @import("vec3.zig").Point3;
const Quad = @import("quad.zig").Quad;
const RotateY = @import("hittable.zig").RotateY;
const RtwImage = @import("rtw_image.zig").RtwImage;
const Sphere = @import("sphere.zig").Sphere;
const Translate = @import("hittable.zig").Translate;
const Vec3 = @import("vec3.zig").Vec3;

// .\zig-out\bin\*.exe > image.ppm
// zig build -Doptimize=ReleaseFast
pub fn main(init: std.process.Init) !void {
    const arena = init.arena;
    const io = init.io;

    switch (10) {
        1 => return bouncingSpheres(arena.allocator(), io),
        2 => return checkeredSpheres(arena.allocator(), io),
        3 => return earth(arena.allocator(), io),
        4 => return perlinSpheres(arena.allocator(), io),
        5 => return quads(arena.allocator(), io),
        6 => return simpleLight(arena.allocator(), io),
        7 => return cornellBox(arena.allocator(), io),
        8 => return cornellSmoke(arena.allocator(), io),
        9 => return finalScene(
            arena.allocator(),
            io,
            400,
            250,
            4,
        ),
        10 => return finalScene(
            arena.allocator(),
            io,
            800,
            10000,
            40,
        ),
        else => unreachable,
    }
}

fn finalScene(
    gpa: std.mem.Allocator,
    io: std.Io,
    imageWidth: usize,
    samplesPerPixel: usize,
    maxDepth: i64,
) !void {
    var buf: [1024]u8 = undefined;
    var writer = std.Io.File.stdout().writer(io, &buf);
    const stdout = &writer.interface;

    const seed: u64 = @intCast(std.Io.Clock.real.now(io).toMilliseconds());
    var prng = std.Random.DefaultPrng.init(seed);
    const rng = prng.random();

    var world = try HittableList.init(gpa);
    defer world.deinit(gpa);

    // ground
    var boxes1 = try HittableList.init(gpa);
    const solidGreen = tex.SolidColor.initFromAlbedo(
        Color.init(0.48, 0.83, 0.53),
    );
    const ground = material.Lambertian.initFromTexture(solidGreen.texture());

    const boxesPerSide = 20;
    for (0..boxesPerSide) |i| {
        for (0..boxesPerSide) |j| {
            const di: f64 = @floatFromInt(i);
            const dj: f64 = @floatFromInt(j);

            const w = 100.0;
            const x0 = -1000.0 + di * w;
            const z0 = -1000.0 + dj * w;
            const y0 = 0.0;
            const x1 = x0 + w;
            const y1 = vec3.randomDouble(rng, 1.0, 101.0);
            const z1 = z0 + w;

            const box = try gpa.create(HittableList);
            box.* = try HittableList.init(gpa);

            try quad.box(
                gpa,
                box,
                Point3.init(x0, y0, z0),
                Point3.init(x1, y1, z1),
                ground.material(),
            );

            try boxes1.add(gpa, box.hittable());
        }
    }

    const groundbvh = try gpa.create(BVHNode);
    groundbvh.* = try BVHNode.initFromList(gpa, boxes1, rng);

    try world.add(gpa, groundbvh.hittable());

    const light = material.DiffuseLight.initFromTexture(
        tex.SolidColor.initFromAlbedo(
            Color.init(7.0, 7.0, 7.0),
        ).texture(),
    );

    try world.add(
        gpa,
        Quad.init(
            Point3.init(123.0, 554.0, 147.0),
            Vec3.init(300.0, 0.0, 0.0),
            Vec3.init(0.0, 0.0, 265.0),
            light.material(),
        ).hittable(),
    );

    const center1 = Point3.init(400.0, 400.0, 200.0);
    const center2 = center1.add(Vec3.init(30.0, 0.0, 0.0));
    const solidColor = tex.SolidColor.initFromAlbedo(
        Color.init(0.7, 0.3, 0.1),
    );
    const lamber = material.Lambertian.initFromTexture(solidColor.texture());

    try world.add(
        gpa,
        Sphere.initMoving(
            center1,
            center2,
            50.0,
            lamber.material(),
        ).hittable(),
    );

    const dielec = material.Dielectric.init(1.5);
    try world.add(
        gpa,
        Sphere.initStationary(
            Point3.init(260.0, 150.0, 45.0),
            50.0,
            dielec.material(),
        ).hittable(),
    );

    const met = material.Metal.init(Color.init(0.8, 0.8, 0.9), 1.0);
    try world.add(
        gpa,
        Sphere.initStationary(
            Point3.init(0.0, 150.0, 145.0),
            50.0,
            met.material(),
        ).hittable(),
    );

    const boundary1 = Sphere.initStationary(
        Point3.init(360.0, 150.0, 145.0),
        70.0,
        dielec.material(),
    );
    try world.add(gpa, boundary1.hittable());

    const boundarySolid1 = tex.SolidColor.initFromAlbedo(
        Color.init(0.2, 0.4, 0.9),
    );

    const medium1 = try hittable.ConstantMedium.init(
        gpa,
        rng,
        boundary1.hittable(),
        0.2,
        boundarySolid1.texture(),
    );
    try world.add(gpa, medium1.hittable());

    const boundary2 = Sphere.initStationary(
        Point3.init(0.0, 0.0, 0.0),
        5000.0,
        dielec.material(),
    );

    const boundarySolid2 = tex.SolidColor.initFromAlbedo(
        Color.init(1.0, 1.0, 1.0),
    );

    const medium2 = try hittable.ConstantMedium.init(
        gpa,
        rng,
        boundary2.hittable(),
        0.0001,
        boundarySolid2.texture(),
    );
    try world.add(gpa, medium2.hittable());

    const etex = try tex.ImageTexture.initFromFile(
        gpa,
        "earthmap.jpg",
    );
    const emat = material.Lambertian.initFromTexture(etex.texture());
    try world.add(
        gpa,
        Sphere.initStationary(
            Point3.init(400.0, 200.0, 400.0),
            100.0,
            emat.material(),
        ).hittable(),
    );

    const noise = Perlin.init(prng.random());
    const pertext = tex.NoiseTexture.init(noise, 0.2);
    const pertextLambertian = material.Lambertian.initFromTexture(
        pertext.texture(),
    );
    try world.add(
        gpa,
        Sphere.initStationary(
            Point3.init(220.0, 280.0, 300.0),
            80.0,
            pertextLambertian.material(),
        ).hittable(),
    );

    var boxes2 = try HittableList.init(gpa);
    const solidWhite = tex.SolidColor.initFromAlbedo(
        Color.init(0.73, 0.73, 0.73),
    );
    const cloud = material.Lambertian.initFromTexture(solidWhite.texture());

    const ns = 1000;
    for (0..ns) |_| {
        const tinySphere = try gpa.create(Sphere);
        tinySphere.* = Sphere.initStationary(
            Point3.randomRange(rng, 0.0, 165.0),
            10.0,
            cloud.material(),
        );
        try boxes2.add(
            gpa,
            tinySphere.hittable(),
        );
    }

    const cloudbvh = try gpa.create(BVHNode);
    cloudbvh.* = try BVHNode.initFromList(gpa, boxes2, rng);

    const boxes2RotateY = try gpa.create(RotateY);
    boxes2RotateY.* = RotateY.init(cloudbvh.hittable(), 15.0);

    const boxes2Translate = try gpa.create(Translate);
    boxes2Translate.* = Translate.init(
        boxes2RotateY.hittable(),
        Vec3.init(-100.0, 270.0, 395.0),
    );

    try world.add(gpa, boxes2Translate.hittable());

    // camera
    var cam: Camera = undefined;
    cam.prng = prng; // keep prng alive for the rng interface
    cam.rng = cam.prng.random(); // this should probably be reduced just to prng...?

    cam.aspectRatio = 1.0;
    cam.imageWidth = imageWidth;
    cam.samplesPerPixel = samplesPerPixel;
    cam.maxDepth = maxDepth;
    cam.background = Color.init(0.0, 0.0, 0.0);

    cam.vfov = 40.0;
    cam.lookfrom = Point3.init(478.0, 278.0, -600.0);
    cam.lookat = Point3.init(278.0, 278.0, 0.0);
    cam.vup = Vec3.init(0.0, 1.0, 0.0);

    cam.defocusAngle = 0.0;
    cam.focusDist = 10.0;

    try cam.render(
        stdout,
        &world.hittable(),
    );
}

fn cornellSmoke(gpa: std.mem.Allocator, io: std.Io) !void {
    var buf: [1024]u8 = undefined;
    var writer = std.Io.File.stdout().writer(io, &buf);
    const stdout = &writer.interface;

    const seed: u64 = @intCast(std.Io.Clock.real.now(io).toMilliseconds());
    var prng = std.Random.DefaultPrng.init(seed);

    var world = try HittableList.init(gpa);
    defer world.deinit(gpa);

    // Materials
    const red = material.Lambertian.initFromTexture(
        tex.SolidColor.initFromAlbedo(
            Color.init(0.65, 0.05, 0.05),
        ).texture(),
    );

    const white = material.Lambertian.initFromTexture(
        tex.SolidColor.initFromAlbedo(
            Color.init(0.73, 0.73, 0.73),
        ).texture(),
    );

    const green = material.Lambertian.initFromTexture(
        tex.SolidColor.initFromAlbedo(
            Color.init(0.12, 0.45, 0.15),
        ).texture(),
    );

    const light = material.DiffuseLight.initFromTexture(
        tex.SolidColor.initFromAlbedo(
            Color.init(7.0, 7.0, 7.0),
        ).texture(),
    );

    // walls
    try world.add(
        gpa,
        Quad.init(
            Point3.init(555.0, 0.0, 0.0),
            Vec3.init(0.0, 555.0, 0.0),
            Vec3.init(0.0, 0.0, 555.0),
            green.material(),
        ).hittable(),
    );

    try world.add(
        gpa,
        Quad.init(
            Point3.init(0.0, 0.0, 0.0),
            Vec3.init(0.0, 555.0, 0.0),
            Vec3.init(0.0, 0.0, 555.0),
            red.material(),
        ).hittable(),
    );

    try world.add(
        gpa,
        Quad.init(
            Point3.init(113.0, 554.0, 127.0),
            Vec3.init(330.0, 0.0, 0.0),
            Vec3.init(0.0, 0.0, 305.0),
            light.material(),
        ).hittable(),
    );

    try world.add(
        gpa,
        Quad.init(
            Point3.init(0.0, 0.0, 0.0),
            Vec3.init(555.0, 0.0, 0.0),
            Vec3.init(0.0, 0.0, 555.0),
            white.material(),
        ).hittable(),
    );

    try world.add(
        gpa,
        Quad.init(
            Point3.init(555.0, 555.0, 555.0),
            Vec3.init(-555.0, 0.0, 0.0),
            Vec3.init(0.0, 0.0, -555.0),
            white.material(),
        ).hittable(),
    );

    try world.add(
        gpa,
        Quad.init(
            Point3.init(0.0, 0.0, 555.0),
            Vec3.init(555.0, 0.0, 0.0),
            Vec3.init(0.0, 555.0, 0.0),
            white.material(),
        ).hittable(),
    );

    // internal boxes
    const box1 = try gpa.create(HittableList);
    box1.* = try HittableList.init(gpa);

    try quad.box(
        gpa,
        box1,
        Point3.init(0.0, 0.0, 0.0),
        Point3.init(165.0, 330.0, 165.0),
        white.material(),
    );

    const box1RotateY = try gpa.create(RotateY);
    box1RotateY.* = RotateY.init(box1.hittable(), 15.0);

    const box1Translate = try gpa.create(Translate);
    box1Translate.* = Translate.init(
        box1RotateY.hittable(),
        Vec3.init(265.0, 0.0, 295.0),
    );

    const zeroesSolid = try gpa.create(tex.SolidColor);
    zeroesSolid.* = tex.SolidColor.initFromAlbedo(Color.init(0.0, 0.0, 0.0));

    const box1Medium = try gpa.create(hittable.ConstantMedium);
    box1Medium.* = try hittable.ConstantMedium.init(
        gpa,
        prng.random(),
        box1Translate.hittable(),
        0.01,
        zeroesSolid.texture(),
    );

    try world.add(gpa, box1Medium.hittable());

    const box2 = try gpa.create(HittableList);
    box2.* = try HittableList.init(gpa);

    try quad.box(
        gpa,
        box2,
        Point3.init(0.0, 0.0, 0.0),
        Point3.init(165.0, 165.0, 165.0),
        white.material(),
    );

    const box2RotateY = try gpa.create(RotateY);
    box2RotateY.* = RotateY.init(box2.hittable(), 18.0);

    const box2Translate = try gpa.create(Translate);
    box2Translate.* = Translate.init(
        box2RotateY.hittable(),
        Vec3.init(130.0, 0.0, 65.0),
    );

    const onesSolid = try gpa.create(tex.SolidColor);
    onesSolid.* = tex.SolidColor.initFromAlbedo(Color.init(1.0, 1.0, 1.0));

    const box2Medium = try gpa.create(hittable.ConstantMedium);
    box2Medium.* = try hittable.ConstantMedium.init(
        gpa,
        prng.random(),
        box2Translate.hittable(),
        0.01,
        onesSolid.texture(),
    );

    try world.add(gpa, box2Medium.hittable());

    // camera
    var cam: Camera = undefined;
    cam.prng = prng; // keep prng alive for the rng interface
    cam.rng = cam.prng.random(); // this should probably be reduced just to prng...?

    cam.aspectRatio = 1.0;
    cam.imageWidth = 600;
    cam.samplesPerPixel = 200;
    cam.maxDepth = 50;
    cam.background = Color.init(0.0, 0.0, 0.0);

    cam.vfov = 40.0;
    cam.lookfrom = Point3.init(278.0, 278.0, -800.0);
    cam.lookat = Point3.init(278.0, 278.0, 0.0);
    cam.vup = Vec3.init(0.0, 1.0, 0.0);

    cam.defocusAngle = 0.0;
    cam.focusDist = 10.0;

    try cam.render(
        stdout,
        &world.hittable(),
    );
}

fn cornellBox(gpa: std.mem.Allocator, io: std.Io) !void {
    var buf: [1024]u8 = undefined;
    var writer = std.Io.File.stdout().writer(io, &buf);
    const stdout = &writer.interface;

    var world = try HittableList.init(gpa);
    defer world.deinit(gpa);

    // Materials
    const red = material.Lambertian.initFromTexture(
        tex.SolidColor.initFromAlbedo(
            Color.init(0.65, 0.05, 0.05),
        ).texture(),
    );

    const white = material.Lambertian.initFromTexture(
        tex.SolidColor.initFromAlbedo(
            Color.init(0.73, 0.73, 0.73),
        ).texture(),
    );

    const green = material.Lambertian.initFromTexture(
        tex.SolidColor.initFromAlbedo(
            Color.init(0.12, 0.45, 0.15),
        ).texture(),
    );

    const light = material.DiffuseLight.initFromTexture(
        tex.SolidColor.initFromAlbedo(
            Color.init(15.0, 15.0, 15.0),
        ).texture(),
    );

    // walls
    try world.add(
        gpa,
        Quad.init(
            Point3.init(555.0, 0.0, 0.0),
            Vec3.init(0.0, 555.0, 0.0),
            Vec3.init(0.0, 0.0, 555.0),
            green.material(),
        ).hittable(),
    );

    try world.add(
        gpa,
        Quad.init(
            Point3.init(0.0, 0.0, 0.0),
            Vec3.init(0.0, 555.0, 0.0),
            Vec3.init(0.0, 0.0, 555.0),
            red.material(),
        ).hittable(),
    );

    try world.add(
        gpa,
        Quad.init(
            Point3.init(343.0, 554.0, 332.0),
            Vec3.init(-130.0, 0.0, 0.0),
            Vec3.init(0.0, 0.0, -105.0),
            light.material(),
        ).hittable(),
    );

    try world.add(
        gpa,
        Quad.init(
            Point3.init(0.0, 0.0, 0.0),
            Vec3.init(555.0, 0.0, 0.0),
            Vec3.init(0.0, 0.0, 555.0),
            white.material(),
        ).hittable(),
    );

    try world.add(
        gpa,
        Quad.init(
            Point3.init(555.0, 555.0, 555.0),
            Vec3.init(-555.0, 0.0, 0.0),
            Vec3.init(0.0, 0.0, -555.0),
            white.material(),
        ).hittable(),
    );

    try world.add(
        gpa,
        Quad.init(
            Point3.init(0.0, 0.0, 555.0),
            Vec3.init(555.0, 0.0, 0.0),
            Vec3.init(0.0, 555.0, 0.0),
            white.material(),
        ).hittable(),
    );

    // internal boxes
    const box1 = try gpa.create(HittableList);
    box1.* = try HittableList.init(gpa);

    try quad.box(
        gpa,
        box1,
        Point3.init(0.0, 0.0, 0.0),
        Point3.init(165.0, 330.0, 165.0),
        white.material(),
    );

    const box1RotateY = try gpa.create(RotateY);
    box1RotateY.* = RotateY.init(box1.hittable(), 15.0);

    const box1Translate = try gpa.create(Translate);
    box1Translate.* = Translate.init(
        box1RotateY.hittable(),
        Vec3.init(265.0, 0.0, 295.0),
    );

    try world.add(gpa, box1Translate.hittable());

    const box2 = try gpa.create(HittableList);
    box2.* = try HittableList.init(gpa);

    try quad.box(
        gpa,
        box2,
        Point3.init(0.0, 0.0, 0.0),
        Point3.init(165.0, 165.0, 165.0),
        white.material(),
    );

    const box2RotateY = try gpa.create(RotateY);
    box2RotateY.* = RotateY.init(box2.hittable(), 18.0);

    const box2Translate = try gpa.create(Translate);
    box2Translate.* = Translate.init(
        box2RotateY.hittable(),
        Vec3.init(130.0, 0.0, 65.0),
    );

    try world.add(gpa, box2Translate.hittable());

    // Camera
    const seed: u64 = @intCast(std.Io.Clock.real.now(io).toMilliseconds());
    const prng = std.Random.DefaultPrng.init(seed);

    var cam: Camera = undefined;
    cam.prng = prng; // keep prng alive for the rng interface
    cam.rng = cam.prng.random(); // this should probably be reduced just to prng...?

    cam.aspectRatio = 1.0;
    cam.imageWidth = 600;
    cam.samplesPerPixel = 200;
    cam.maxDepth = 50;
    cam.background = Color.init(0.0, 0.0, 0.0);

    cam.vfov = 40.0;
    cam.lookfrom = Point3.init(278.0, 278.0, -800.0);
    cam.lookat = Point3.init(278.0, 278.0, 0.0);
    cam.vup = Vec3.init(0.0, 1.0, 0.0);

    cam.defocusAngle = 0.0;
    cam.focusDist = 10.0;

    try cam.render(
        stdout,
        &world.hittable(),
    );
}

fn simpleLight(gpa: std.mem.Allocator, io: std.Io) !void {
    var buf: [1024]u8 = undefined;
    var writer = std.Io.File.stdout().writer(io, &buf);
    const stdout = &writer.interface;

    const seed: u64 = @intCast(std.Io.Clock.real.now(io).toMilliseconds());
    var prng = std.Random.DefaultPrng.init(seed);

    var world = try HittableList.init(gpa);
    defer world.deinit(gpa);

    const noise = Perlin.init(prng.random());
    const pertext = tex.NoiseTexture.init(noise, 4.0);

    const noise_material = material.Lambertian.initFromTexture(pertext.texture());

    const bottom_sphere = Sphere.initStationary(
        Point3.init(0.0, -1000.0, 0.0),
        1000.0,
        noise_material.material(),
    );
    try world.add(
        gpa,
        bottom_sphere.hittable(),
    );

    const top_sphere = Sphere.initStationary(
        Point3.init(0.0, 2.0, 0.0),
        2.0,
        noise_material.material(),
    );
    try world.add(
        gpa,
        top_sphere.hittable(),
    );

    const diff_light = material.DiffuseLight.initFromTexture(
        tex.SolidColor.initFromAlbedo(
            Color.init(4.0, 4.0, 4.0),
        ).texture(),
    );
    const light_quad = Quad.init(
        Point3.init(3.0, 1.0, -2.0),
        Vec3.init(2.0, 0.0, 0.0),
        Vec3.init(0.0, 2.0, 0.0),
        diff_light.material(),
    );
    try world.add(
        gpa,
        light_quad.hittable(),
    );

    var cam: Camera = undefined;
    cam.prng = std.Random.DefaultPrng.init(seed); // keep prng alive for the rng interface
    cam.rng = cam.prng.random(); // this should probably be reduced just to prng...?

    cam.aspectRatio = 16.0 / 9.0;
    cam.imageWidth = 400;
    cam.samplesPerPixel = 100;
    cam.maxDepth = 50;
    cam.background = Color.init(0.0, 0.0, 0.0);

    cam.vfov = 20.0;
    cam.lookfrom = Point3.init(26.0, 3.0, 6.0);
    cam.lookat = Point3.init(0.0, 2.0, 0.0);
    cam.vup = Vec3.init(0.0, 1.0, 0.0);

    cam.defocusAngle = 0.0;
    cam.focusDist = 10.0;

    try cam.render(
        stdout,
        &world.hittable(),
    );
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
    cam.background = Color.init(0.70, 0.80, 1.00);

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
    cam.background = Color.init(0.70, 0.80, 1.00);

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
    cam.background = Color.init(0.70, 0.80, 1.00);

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
    cam.background = Color.init(0.70, 0.80, 1.00);

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
    cam.background = Color.init(0.70, 0.80, 1.00);

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
