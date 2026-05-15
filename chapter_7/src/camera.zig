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
    aspectRatio: f64 = 1.0, // Ratio of image width over height
    imageWidth: usize = 100, // Rendered image width in pixel count
    imageHeight: usize, // Rendered image height
    center: Point3, // Camera center
    pixel100Loc: Point3, // Location of pixel(0, 0)
    pixelDeltaU: Vec3, // Offset to pixel to the right
    pixelDeltaV: Vec3, // Offset to pixel below

    pub fn render(self: *Camera, writer: *std.Io.Writer, world: *const Hittable) !void {
        self.init();

        try writer.print("P3\n{} {}\n255\n", .{ self.imageWidth, self.imageHeight });
        try writer.flush();

        for (0..self.imageHeight) |j| {
            std.log.info("\rScanlines remaining {}", .{self.imageHeight - j});
            for (0..self.imageWidth) |i| {
                const pixelCenter = self.pixel100Loc
                    .add(self.pixelDeltaU.scale(@floatFromInt(i)))
                    .add(self.pixelDeltaV.scale(@floatFromInt(j)));

                const rayDirection = pixelCenter.sub(self.center);

                var pixelColor = rayColor(
                    Ray.init(self.center, rayDirection),
                    world,
                );
                try color.writeColor(writer, &pixelColor);
            }
        }

        std.log.info("\rDone.\n", .{});
    }

    fn init(self: *Camera) void {
        self.center = Point3.init(0, 0, 0);

        const height: usize = @intFromFloat(
            @as(f64, @floatFromInt(self.imageWidth)) / self.aspectRatio,
        );
        self.imageHeight = if (height < 1) 1 else height;

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
