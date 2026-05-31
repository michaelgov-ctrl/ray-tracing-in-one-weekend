const BBox = @import("bbox.zig").BBox;
const HitRecord = @import("hittable.zig").HitRecord;
const Hittable = @import("hittable.zig").Hittable;
const Interval = @import("interval.zig").Interval;
const Material = @import("material.zig").Material;
const Point3 = @import("vec3.zig").Point3;
const Ray = @import("ray.zig").Ray;
const Vec3 = @import("vec3.zig").Vec3;

pub const Quad = struct {
    const Self = @This();

    Q: Point3,
    u: Vec3,
    v: Vec3,
    w: Vec3,
    normal: Vec3,
    D: f64,
    mat: Material,
    bbox: BBox,

    pub fn init(
        Q: Point3,
        u: Vec3,
        v: Vec3,
        mat: Material,
    ) Self {
        const n = u.cross(v);
        const normal = n.unitVector();

        const bbox_diagonal1 = BBox.fromPoints(Q, Q.add(u).add(v));
        const bbox_diagonal2 = BBox.fromPoints(Q.add(u), Q.add(v));

        return .{
            .Q = Q,
            .u = u,
            .v = v,
            .w = n.div(n.dot(n)),
            .normal = normal,
            .D = normal.dot(Q),
            .mat = mat,
            .bbox = BBox.fromBoxes(
                bbox_diagonal1,
                bbox_diagonal2,
            ),
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

        const denom = self.normal.dot(r.direction);

        // no hit if the ray is parallel to the plane.
        if (@abs(denom) <= 1e-8)
            return false;

        // return false if the hit point parameter t is outside the ray interval.
        const t = (self.D - self.normal.dot(r.origin)) / denom;
        if (!ray_t.contains(t))
            return false;

        // determine if the hit point lies within the planar shape using its plane coordinates.
        const intersection = r.at(t);

        const planar_hitpt_vector = intersection.sub(self.Q);
        const alpha = self.w.dot(planar_hitpt_vector.cross(self.v));
        const beta = self.w.dot(self.u.cross(planar_hitpt_vector));

        if (!isInterior(alpha, beta, rec))
            return false;

        // ray hits the 2D shape; set the rest of the hit record and return true.
        rec.t = t;
        rec.p = intersection;
        rec.mat = self.mat;
        rec.setFaceNormal(r, self.normal);

        return true;
    }

    fn isInterior(a: f64, b: f64, rec: *HitRecord) bool {
        const unit_interval = Interval.init(0.0, 1.0);
        // given the hit point in plane coordinates, return false if it is oustide the
        // primitive, otherwise set the hit record UV coordinates and return true.

        if (!unit_interval.contains(a) or !unit_interval.contains(b))
            return false;

        rec.u = a;
        rec.v = b;

        return true;
    }

    fn boundingBox(ptr: *const anyopaque) BBox {
        const self: *const Self = @ptrCast(@alignCast(ptr));

        return self.bbox;
    }
};
