const h = @import("hittable.zig");

const Interval = @import("interval.zig").Interval;
const Ray = @import("ray.zig").Ray;

pub const BBox = struct {
    const Self = @This();

    x: Interval,
    y: Interval,
    z: Interval,

    pub fn init(x: Interval, y: Interval, z: Interval) Self {
        return .{
            .x = x,
            .y = y,
            .z = z,
        };
    }

    pub fn axisInterval(self: Self, n: usize) Interval {
        return switch (n) {
            0 => self.x,
            1 => self.y,
            2 => self.z,
            else => unreachable,
        };
    }

    pub fn hittable(self: *const Self) h.Hittable {
        return .{
            .ptr = self,
            .hitFn = hit,
        };
    }

    fn hit(
        ptr: *const anyopaque,
        r: Ray,
        ray_t: Interval,
        rec: *h.HitRecord,
    ) bool {
        _ = rec;

        const self: *const Self = @ptrCast(@alignCast(ptr));

        const rayOrig = r.origin;
        const rayDir = r.direction;

        var intervalMin = ray_t.min;
        var intervalMax = ray_t.max;

        for (0..3) |axis| {
            const ax = self.axisInterval(axis);
            const adinv = 1.0 / rayDir.axisInterval(axis);

            const t0 = (ax.min - rayOrig.axis(axis)) * adinv;
            const t1 = (ax.max - rayOrig.axis(axis)) * adinv;

            if (t0 < t1) {
                if (t0 > intervalMin) intervalMin = t0;
                if (t1 < intervalMax) intervalMax = t1;
            } else {
                if (t1 > intervalMin) intervalMin = t1;
                if (t0 < intervalMax) intervalMax = t0;
            }

            if (intervalMax <= intervalMin) return false;
        }

        return true;
    }
};
