const HitRecord = @import("hittable.zig").HitRecord;
const Hittable = @import("hittable.zig").Hittable;
const Interval = @import("interval.zig").Interval;
const Point3 = @import("vec3.zig").Point3;
const Ray = @import("ray.zig").Ray;

pub const Sphere = struct {
    center: Point3,
    radius: f64,

    pub fn init(center: Point3, radius: f64) Sphere {
        return .{
            .center = center,
            .radius = @max(0, radius),
        };
    }

    pub fn hittable(self: *const Sphere) Hittable {
        return .{
            .ptr = self,
            .hitFn = hit,
        };
    }

    fn hit(
        ptr: *const anyopaque,
        r: Ray,
        ray_t: Interval,
        rec: *HitRecord,
    ) bool {
        const self: *const Sphere = @ptrCast(@alignCast(ptr));

        const oc = self.center.sub(r.origin);
        const a = r.direction.lengthSquared();
        const h = r.direction.dot(oc);
        const c = oc.lengthSquared() - self.radius * self.radius;

        const discriminant = h * h - a * c;
        if (discriminant < 0) return false;

        const sqrtd = @sqrt(discriminant);

        // Find the nearest root within the acceptable range
        var root = (h - sqrtd) / a;
        if (!ray_t.surrounds(root)) {
            root = (h + sqrtd) / a;
            if (!ray_t.surrounds(root)) return false;
        }

        rec.t = root;
        rec.p = r.at(root);
        const outwardNormal = rec.p.sub(self.center).div(self.radius);
        rec.setFaceNormal(r, outwardNormal);

        return true;
    }
};
