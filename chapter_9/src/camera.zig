const std = @import("std");
const color = @import("color.zig");

const Color = color.Color;
const Ray = @import("ray.zig").Ray;
const Interval = @import("interval.zig").Interval;
const Hittable = @import("hittable.zig").Hittable;
const HitRecord = @import("hittable.zig").HitRecord;
const Point3 = @import("vec3.zig").Point3;
const Vec3 = @import("vec3.zig").Vec3;

pub const Camera = struct {
    const Self = @This();

    aspectRatio: f64 = 1.0, // Ratio of image width over height
    imageWidth: usize = 100, // Rendered image width in pixel count
    samplesPerPixel: usize = 10, // Count of random samples for each pixel
    imageHeight: usize, // Rendered image height
    pixelSamplesScale: f64, // Color scale factor for a sum of pixel samples
    center: Point3, // Camera center
    pixel100Loc: Point3, // Location of pixel(0, 0)
    pixelDeltaU: Vec3, // Offset to pixel to the right
    pixelDeltaV: Vec3, // Offset to pixel below
    prng: std.Random.DefaultPrng, // Pseudo random number generator

    pub fn render(self: *Self, io: std.Io, writer: *std.Io.Writer, world: *const Hittable) !void {
        self.init(io);

        try writer.print("P3\n{} {}\n255\n", .{ self.imageWidth, self.imageHeight });
        try writer.flush();

        for (0..self.imageHeight) |j| {
            std.log.info("\rScanlines remaining {}", .{self.imageHeight - j});

            for (0..self.imageWidth) |i| {
                var pixelColor = Color.init(0, 0, 0);
                for (0..self.samplesPerPixel) |_| {
                    const r = self.getRay(i, j);
                    pixelColor = pixelColor.add(rayColor(r, world));
                }

                try color.writeColor(
                    writer,
                    pixelColor.scale(self.pixelSamplesScale),
                );
            }
        }

        std.log.info("\rDone.\n", .{});
    }

    fn init(self: *Self, io: std.Io) void {
        const seed: u64 = @intCast(std.Io.Clock.real.now(io).toMilliseconds());
        self.prng = std.Random.DefaultPrng.init(seed);

        self.center = Point3.init(0, 0, 0);

        const height: usize = @intFromFloat(
            @as(f64, @floatFromInt(self.imageWidth)) / self.aspectRatio,
        );
        self.imageHeight = if (height < 1) 1 else height;

        self.pixelSamplesScale = 1.0 / @as(f64, @floatFromInt(self.samplesPerPixel));

        // Determine viewport dimensions
        const focalLength = 1.0;
        const viewportHeight = 2.0;
        const viewportWidth = viewportHeight *
            (@as(f64, @floatFromInt(self.imageWidth)) /
                @as(f64, @floatFromInt(self.imageHeight)));

        // calculate the vectors across the horizontal and down the vertical viewport edges.
        // starting at top left(Q) of viewport.

        // across
        const viewportU = Vec3.init(viewportWidth, 0, 0);

        // down
        const viewportV = Vec3.init(0, -viewportHeight, 0);

        // calculate the horizontal and vertical delta vectors from pixel to pixel.
        self.pixelDeltaU = viewportU.div(@floatFromInt(self.imageWidth));
        self.pixelDeltaV = viewportV.div(@floatFromInt(self.imageHeight));

        // calculate the location of the upper left pixel
        const viewportUpperLeft = self.center
            .sub(Vec3.init(0, 0, focalLength))
            .sub(viewportU.div(2.0))
            .sub(viewportV.div(2.0));

        self.pixel100Loc = viewportUpperLeft
            .add(self.pixelDeltaU.add(self.pixelDeltaV).scale(0.5));
    }

    fn getRay(self: *Self, i: usize, j: usize) Ray {
        // construct a camaera ray originating from the origin and directed at randomly sampled
        // point around the pixel location i, j.
        const offset = self.sampleSquare();

        const pixelSample = self.pixel100Loc
            .add(self.pixelDeltaU.scale(@as(f64, @floatFromInt(i)) + offset.x))
            .add(self.pixelDeltaV.scale(@as(f64, @floatFromInt(j)) + offset.y));

        const origin = self.center;
        const direction = pixelSample.sub(origin);

        return Ray.init(origin, direction);
    }

    fn sampleSquare(self: *Self) Vec3 {
        // returns the vector to a random point in the [-.5, -.5]-[+.5, +.5] unit square.
        var random = self.prng.random();

        return Vec3.init(
            random.float(f64) - 0.5,
            random.float(f64) - 0.5,
            0,
        );
    }

    fn rayColor(r: Ray, world: *const Hittable) Color {
        var rec = std.mem.zeroes(HitRecord);
        if (world.hit(
            r,
            Interval.init(0, std.math.inf(f64)),
            &rec,
        )) {
            return rec.normal.add(Color.init(1, 1, 1)).scale(0.5);
        }

        const unitDirection = r.direction.unitVector();
        const a = (unitDirection.y + 1.0) * 0.5;

        // lerp
        // blendedValue=(1−a)⋅startValue+a⋅endValue
        return Color.init(1.0, 1.0, 1.0).scale(1.0 - a)
            .add(Color.init(0.5, 0.7, 1.0).scale(a));
    }
};
