const std = @import("std");

const BBox = @import("bbox.zig").BBox;
const Ray = @import("ray.zig").Ray;
const Vec3 = @import("vec3.zig").Vec3;
const Point3 = @import("vec3.zig").Point3;
const Interval = @import("interval.zig").Interval;
const Material = @import("material.zig").Material;

pub const HitRecord = struct {
    const Self = @This();

    p: Point3,
    normal: Vec3,
    t: f64,
    u: f64,
    v: f64,
    frontFace: bool,
    mat: Material,

    pub fn setFaceNormal(
        self: *Self,
        r: Ray,
        outwardNormal: Vec3,
    ) void {
        // sets the hit record normal vector.
        // NOTE: the parameter `outwardNormal` is assumed to have unit length.

        self.frontFace = r.direction.dot(outwardNormal) < 0.0;
        self.normal = if (self.frontFace) outwardNormal else outwardNormal.neg();
    }
};

pub const Hittable = struct {
    const Self = @This();

    ptr: *const anyopaque,

    hitFn: *const fn (
        ptr: *const anyopaque,
        r: Ray,
        ray_t: Interval,
        rec: *HitRecord,
    ) bool,

    boundingBoxFn: *const fn (
        ptrh: *const anyopaque,
    ) BBox,

    pub fn hit(
        self: Self,
        r: Ray,
        ray_t: Interval,
        rec: *HitRecord,
    ) bool {
        return self.hitFn(
            self.ptr,
            r,
            ray_t,
            rec,
        );
    }

    pub fn boundingBox(self: Self) BBox {
        return self.boundingBoxFn(self.ptr);
    }
};

pub const HittableList = struct {
    const Self = @This();

    objects: std.ArrayList(Hittable),
    bbox: BBox,

    pub fn init(
        allocator: std.mem.Allocator,
    ) !Self {
        return .{
            .objects = try std.ArrayList(Hittable).initCapacity(
                allocator,
                10,
            ),
            .bbox = BBox.empty(),
        };
    }

    pub fn deinit(
        self: *Self,
        allocator: std.mem.Allocator,
    ) void {
        self.objects.deinit(allocator);
    }

    pub fn clear(self: *Self) void {
        self.objects.clearRetainingCapacity();
    }

    pub fn add(
        self: *Self,
        allocator: std.mem.Allocator,
        obj: Hittable,
    ) !void {
        try self.objects.append(allocator, obj);
        self.bbox = BBox.fromBoxes(self.bbox, obj.boundingBox());
    }

    pub fn hittable(self: *const Self) Hittable {
        return .{
            .ptr = self,
            .hitFn = hit,
            .boundingBoxFn = boundingBox,
        };
    }

    pub fn hit(
        ptr: *const anyopaque,
        r: Ray,
        ray_t: Interval,
        rec: *HitRecord,
    ) bool {
        const self: *const Self = @ptrCast(@alignCast(ptr));

        var temp_rec: HitRecord = undefined;
        var hit_anything = false;
        var closest = ray_t.max;

        for (self.objects.items) |obj| {
            if (obj.hit(
                r,
                Interval.init(ray_t.min, closest),
                &temp_rec,
            )) {
                hit_anything = true;
                closest = temp_rec.t;
                rec.* = temp_rec;
            }
        }

        return hit_anything;
    }

    pub fn boundingBox(ptr: *const anyopaque) BBox {
        const self: *const Self = @ptrCast(@alignCast(ptr));

        return self.bbox;
    }
};

pub const Translate = struct {
    const Self = @This();

    object: Hittable,
    offset: Vec3,
    bbox: BBox,

    pub fn init(object: Hittable, offset: Vec3) Self {
        return .{
            .object = object,
            .offset = offset,
            .bbox = object.boundingBox().addOffset(offset),
        };
    }

    pub fn hittable(self: *const Self) Hittable {
        return .{
            .ptr = self,
            .hitFn = hit,
            .boundingBoxFn = boundingBox,
        };
    }

    pub fn hit(
        ptr: *const anyopaque,
        r: Ray,
        ray_t: Interval,
        rec: *HitRecord,
    ) bool {
        const self: *const Self = @ptrCast(@alignCast(ptr));

        // move the ray backwards by the offset
        const offset_r = Ray.init(
            r.origin.sub(self.offset),
            r.direction,
            r.time,
        );

        // determine whether an intersection exists along the offset ray (and if so, where)
        if (!self.object.hit(offset_r, ray_t, rec))
            return false;

        // move the intersection point forwards by the offset
        rec.p = rec.p.add(self.offset);

        return true;
    }

    pub fn boundingBox(ptr: *const anyopaque) BBox {
        const self: *const Self = @ptrCast(@alignCast(ptr));

        return self.bbox;
    }
};

pub const RotateY = struct {
    const Self = @This();

    object: Hittable,
    cosTheta: f64,
    sinTheta: f64,
    bbox: BBox,

    pub fn init(object: Hittable, angle: f64) Self {
        const radians = std.math.degreesToRadians(angle);
        const cosTheta = std.math.cos(radians);
        const sinTheta = std.math.sin(radians);

        const bbox = object.boundingBox();

        var min = Point3.init(
            std.math.inf(f64),
            std.math.inf(f64),
            std.math.inf(f64),
        );
        var max = Point3.init(
            -std.math.inf(f64),
            -std.math.inf(f64),
            -std.math.inf(f64),
        );

        for (0..2) |i| {
            for (0..2) |j| {
                for (0..2) |k| {
                    const di: f64 = @floatFromInt(i);
                    const dj: f64 = @floatFromInt(j);
                    const dk: f64 = @floatFromInt(k);

                    const x = di * bbox.x.max + (1.0 - di) * bbox.x.min;
                    const y = dj * bbox.y.max + (1.0 - dj) * bbox.y.min;
                    const z = dj * bbox.z.max + (1.0 - dk) * bbox.z.min;

                    const newx = cosTheta * x + sinTheta * z;
                    const newz = -sinTheta * x + cosTheta * z;

                    const tester = Vec3.init(newx, y, newz);

                    for (0..3) |c| {
                        min.axisAssign(c, @min(min.axisInterval(c), tester.axisInterval(c)));
                        max.axisAssign(c, @max(max.axisInterval(c), tester.axisInterval(c)));
                    }
                }
            }
        }

        return .{
            .object = object,
            .sinTheta = std.math.sin(radians),
            .cosTheta = std.math.cos(radians),
            .bbox = BBox.fromPoints(min, max),
        };
    }

    pub fn hittable(self: *const Self) Hittable {
        return .{
            .ptr = self,
            .hitFn = hit,
            .boundingBoxFn = boundingBox,
        };
    }

    pub fn hit(
        ptr: *const anyopaque,
        r: Ray,
        ray_t: Interval,
        rec: *HitRecord,
    ) bool {
        const self: *const Self = @ptrCast(@alignCast(ptr));

        const origin = Point3.init(
            self.cosTheta * r.origin.x - self.sinTheta * r.origin.z,
            r.origin.y,
            self.sinTheta * r.origin.x + self.cosTheta * r.origin.z,
        );

        const direction = Vec3.init(
            self.cosTheta * r.direction.x - self.sinTheta * r.direction.z,
            r.direction.y,
            self.sinTheta * r.direction.x + self.cosTheta * r.direction.z,
        );

        const rotated_r = Ray.init(origin, direction, r.time);

        if (!self.object.hit(rotated_r, ray_t, rec))
            return false;

        rec.p = Point3.init(
            self.cosTheta * rec.p.x + self.sinTheta * rec.p.z,
            rec.p.y,
            -self.sinTheta * rec.p.x + self.cosTheta * rec.p.z,
        );

        rec.normal = Vec3.init(
            self.cosTheta * rec.normal.x + self.sinTheta * rec.normal.z,
            rec.normal.y,
            -self.sinTheta * rec.normal.x + self.cosTheta * rec.normal.z,
        );

        return true;
    }

    pub fn boundingBox(ptr: *const anyopaque) BBox {
        const self: *const Self = @ptrCast(@alignCast(ptr));

        return self.bbox;
    }
};
