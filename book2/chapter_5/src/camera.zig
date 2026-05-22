const std = @import("std");
const color = @import("color.zig");
const vec3 = @import("vec3.zig");

const Color = color.Color;
const Ray = @import("ray.zig").Ray;
const Material = @import("material.zig").Material;
const Interval = @import("interval.zig").Interval;
const Hittable = @import("hittable.zig").Hittable;
const HitRecord = @import("hittable.zig").HitRecord;
const Point3 = vec3.Point3;
const Vec3 = vec3.Vec3;

pub const Camera = struct {
    const Self = @This();

    // prng is necessary because the rng interface needs the backing object to remain.
    prng: std.Random.DefaultPrng = undefined, // Pseudo random number generator
    rng: std.Random = undefined, // Pseudo random number generator interface
    aspectRatio: f64 = 1.0, // Ratio of image width over height
    imageWidth: usize = 100, // Rendered image width in pixel count
    samplesPerPixel: usize = 10, // Count of random samples for each pixel
    maxDepth: i64 = 10, // Maximum number of ray bounces into scene
    vfov: f64 = 90.0, // Vertical view angle (field of view)
    lookfrom: Point3 = Point3.init(0.0, 0.0, 0.0), // Point camera is looking from
    lookat: Point3 = Point3.init(0.0, 0.0, -1.0), // Point camera is looking at
    vup: Vec3 = Vec3.init(0.0, 1.0, 0.0), // Camera-relative "up" direction
    defocusAngle: f64 = 0.0, // Variation angle of rays through each pixel
    focusDist: f64 = 10.0, // Distance from camera lookfrom point to plan of perfect focus
    u: Vec3, // Camera frame basis vector
    v: Vec3, // Camera frame basis vector
    w: Vec3, // Camera frame basis vector
    defocusDiskU: Vec3, // Defocus disk horizonal radius
    defocusDiskV: Vec3, // Defocus disk vertical radius
    imageHeight: usize, // Rendered image height
    pixelSamplesScale: f64, // Color scale factor for a sum of pixel samples
    center: Point3, // Camera center
    pixel100Loc: Point3, // Location of pixel(0, 0)
    pixelDeltaU: Vec3, // Offset to pixel to the right
    pixelDeltaV: Vec3, // Offset to pixel below

    pub fn render(self: *Self, writer: *std.Io.Writer, world: *const Hittable) !void {
        self.init();

        try writer.print("P3\n{} {}\n255\n", .{ self.imageWidth, self.imageHeight });
        try writer.flush();

        for (0..self.imageHeight) |j| {
            std.log.info("\rScanlines remaining {}", .{self.imageHeight - j});

            for (0..self.imageWidth) |i| {
                var pixelColor = Color.init(0, 0, 0);
                for (0..self.samplesPerPixel) |_| {
                    const r = self.getRay(i, j);
                    pixelColor = pixelColor.add(rayColor(
                        self.rng,
                        r,
                        self.maxDepth,
                        world,
                    ));
                }

                try color.writeColor(
                    writer,
                    pixelColor.scale(self.pixelSamplesScale),
                );
            }
        }

        std.log.info("\rDone.\n", .{});
    }

    fn init(self: *Self) void {
        self.center = self.lookfrom;

        const height: usize = @intFromFloat(
            @as(f64, @floatFromInt(self.imageWidth)) / self.aspectRatio,
        );
        self.imageHeight = if (height < 1) 1 else height;

        self.pixelSamplesScale = 1.0 / @as(f64, @floatFromInt(self.samplesPerPixel));

        // Determine viewport dimensions
        const theta = std.math.degreesToRadians(self.vfov);
        const h = std.math.tan(theta / 2);
        const viewportHeight = 2 * h * self.focusDist;
        const viewportWidth = viewportHeight *
            (@as(f64, @floatFromInt(self.imageWidth)) /
                @as(f64, @floatFromInt(self.imageHeight)));

        // Calculate the u,v,w unit basis vectors for the camera coordinate frame.
        self.w = self.lookfrom.sub(self.lookat).unitVector();
        self.u = self.vup.cross(self.w).unitVector();
        self.v = self.w.cross(self.u);

        // calculate the vectors across the horizontal and down the vertical viewport edges.
        // starting at top left(Q) of viewport.
        const viewportU = self.u.scale(viewportWidth); // Vector across viewport horizontal edge
        const viewportV = self.v.neg().scale(viewportHeight); // Vector across viewport vertical edge

        // calculate the horizontal and vertical delta vectors from pixel to pixel.
        self.pixelDeltaU = viewportU.div(@floatFromInt(self.imageWidth));
        self.pixelDeltaV = viewportV.div(@floatFromInt(self.imageHeight));

        // calculate the location of the upper left pixel
        const viewportUpperLeft = self.center
            .sub(self.w.scale(self.focusDist))
            .sub(viewportU.div(2.0))
            .sub(viewportV.div(2.0));

        self.pixel100Loc = viewportUpperLeft
            .add(self.pixelDeltaU.add(self.pixelDeltaV).scale(0.5));

        // calculate the camera defocus disk basis vectors
        const defocusRadius = self.focusDist * std.math.tan(
            std.math.degreesToRadians(self.defocusAngle / 2.0),
        );
        self.defocusDiskU = self.u.scale(defocusRadius);
        self.defocusDiskV = self.v.scale(defocusRadius);
    }

    fn getRay(self: *Self, i: usize, j: usize) Ray {
        // construct a camaera ray originating from the defocus disk and directed at
        // a randomly sampled point around the pixel location i, j.
        const offset = self.sampleSquare();

        const pixelSample = self.pixel100Loc
            .add(self.pixelDeltaU.scale(@as(f64, @floatFromInt(i)) + offset.x))
            .add(self.pixelDeltaV.scale(@as(f64, @floatFromInt(j)) + offset.y));

        const origin = if (self.defocusAngle <= 0)
            self.center
        else
            self.defocusDiskSample();

        const direction = pixelSample.sub(origin);

        const time = self.rng.float(f64);

        return Ray.init(
            origin,
            direction,
            time,
        );
    }

    fn sampleSquare(self: *Self) Vec3 {
        // returns the vector to a random point in the [-.5, -.5]-[+.5, +.5] unit square.
        return Vec3.init(
            self.rng.float(f64) - 0.5,
            self.rng.float(f64) - 0.5,
            0,
        );
    }

    fn rayColor(rng: std.Random, r: Ray, depth: i64, world: *const Hittable) Color {
        // if we've exceeded the ray bounce limit, no more light is gathered.
        if (depth <= 0) return Color.init(0.0, 0.0, 0.0);

        var rec: HitRecord = undefined;

        // ignore hits within 0.001 of the calculated intersection point
        if (world.hit(
            r,
            Interval.init(0.001, std.math.inf(f64)),
            &rec,
        )) {
            if (rec.mat.scatter(rng, r, rec)) |scatter| {
                return scatter.attenuation.mul(
                    rayColor(rng, scatter.scattered, depth - 1, world),
                );
            }
        }

        const unitDirection = r.direction.unitVector();
        const a = (unitDirection.y + 1.0) * 0.5;

        // lerp
        // blendedValue=(1−a)⋅startValue+a⋅endValue
        return Color.init(1.0, 1.0, 1.0).scale(1.0 - a)
            .add(Color.init(0.5, 0.7, 1.0).scale(a));
    }

    fn defocusDiskSample(self: Self) Point3 {
        // returns a random point in the camera defocus disk
        const p = Vec3.randomInUnitDisk(self.rng);
        return self.center
            .add(self.defocusDiskU.scale(p.x))
            .add(self.defocusDiskV.scale(p.y));
    }
};
