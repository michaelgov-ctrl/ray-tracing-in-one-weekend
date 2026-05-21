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
        rec.mat = self.mat;

        return true;
    }

    fn boundingBox(ptr: *const anyopaque) BBox {
        const self: *const Self = @ptrCast(@alignCast(ptr));

        return self.bbox;
    }
};
