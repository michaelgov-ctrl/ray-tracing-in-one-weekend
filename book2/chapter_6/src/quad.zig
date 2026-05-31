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
    mat: Material,
    bbox: BBox,

    pub fn init(
        Q: Point3,
        u: Vec3,
        v: Vec3,
        mat: Material,
    ) Self {
        const bbox_diagonal1 = BBox.fromPoints(Q, Q.add(u).add(v));
        const bbox_diagonal2 = BBox.fromPoints(Q.add(u), Q.add(v));

        return .{
            .Q = Q,
            .u = u,
            .v = v,
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
        // TODO: implement this
        const self: *const Self = @ptrCast(@alignCast(ptr));

        _ = self;
        _ = r;
        _ = ray_t;
        _ = rec;

        return false;
    }

    fn boundingBox(ptr: *const anyopaque) BBox {
        const self: *const Self = @ptrCast(@alignCast(ptr));

        return self.bbox;
    }
};
