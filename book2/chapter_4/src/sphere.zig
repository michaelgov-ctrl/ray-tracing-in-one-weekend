const std = @import("std");

const BBox = @import("bbox.zig").BBox;
const HitRecord = @import("hittable.zig").HitRecord;
const Hittable = @import("hittable.zig").Hittable;
const Interval = @import("interval.zig").Interval;
const Material = @import("material.zig").Material;
const Point3 = @import("vec3.zig").Point3;
const Ray = @import("ray.zig").Ray;
const Vec3 = @import("vec3.zig").Vec3;

pub const Sphere = struct {
    const Self = @This();

    centerPath: Ray,
    radius: f64,
    mat: Material,
    bbox: BBox,

    pub fn initStationary(
        center: Point3,
        radius: f64,
        mat: Material,
    ) Self {
        const rvec = Vec3.init(
            radius,
            radius,
            radius,
        );

        return .{
            .centerPath = Ray.init(
                center,
                Vec3.init(0.0, 0.0, 0.0),
                0,
            ),
            .radius = radius,
            .mat = mat,
            .bbox = BBox.fromPoints(
                center.sub(rvec),
                center.add(rvec),
            ),
        };
    }

    pub fn initMoving(
        startCenter: Point3,
        endCenter: Point3,
        radius: f64,
        mat: Material,
    ) Self {
        const rvec = Vec3.init(
            radius,
            radius,
            radius,
        );

        const center = Ray.init(
            startCenter,
            endCenter.sub(startCenter),
            0,
        );

        const box1 = BBox.fromPoints(
            center.at(0.0).sub(rvec),
            center.at(0.0).add(rvec),
        );

        const box2 = BBox.fromPoints(
            center.at(1.0).sub(rvec),
            center.at(1.0).add(rvec),
        );

        return .{
            .centerPath = center,
            .radius = @max(0, radius),
            .mat = mat,
            .bbox = BBox.fromBoxes(box1, box2),
        };
    }

    fn calculateUandV(p: Point3, u: *f64, v: *f64) void {
        // p: a given point on the sphere of radius one, centered at the origin.
        // u: returned value [0,1] of angle around the Y axis from X=-1.
        // v: returned value [0,1] of angle from Y=-1 to Y=+1.
        //     <1 0 0> yields <0.50 0.50>       <-1  0  0> yields <0.00 0.50>
        //     <0 1 0> yields <0.50 1.00>       < 0 -1  0> yields <0.50 0.00>
        //     <0 0 1> yields <0.25 0.50>       < 0  0 -1> yields <0.75 0.50>

        const pi = std.math.pi;
        const theta = std.math.acos(-p.y);
        const phi = std.math.atan2(-p.z, p.x) + pi;

        u.* = phi / (2.0 * pi);
        v.* = theta / pi;
    }

    pub fn hittable(self: *const Self) Hittable {
        return .{
            .ptr = self,
            .hitFn = hit,
            .boundingBoxFn = boundingBox,
        };
    }

    fn hit(
        ptr: *const anyopaque,
        r: Ray,
        ray_t: Interval,
        rec: *HitRecord,
    ) bool {
        const self: *const Self = @ptrCast(@alignCast(ptr));

        const currentCenter = self.centerPath.at(r.time);
        const oc = currentCenter.sub(r.origin);
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
        const outwardNormal = rec.p.sub(currentCenter).div(self.radius);
        rec.setFaceNormal(r, outwardNormal);
        calculateUandV(outwardNormal, &rec.u, &rec.v);
        rec.mat = self.mat;

        return true;
    }

    fn boundingBox(ptr: *const anyopaque) BBox {
        const self: *const Self = @ptrCast(@alignCast(ptr));

        return self.bbox;
    }
};
