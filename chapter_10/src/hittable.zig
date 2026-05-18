const std = @import("std");

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
};

pub const HittableList = struct {
    const Self = @This();

    objects: std.ArrayList(Hittable),

    pub fn init(
        allocator: std.mem.Allocator,
    ) !Self {
        return .{
            .objects = try std.ArrayList(Hittable).initCapacity(
                allocator,
                10,
            ),
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
    }

    pub fn hittable(self: *const Self) Hittable {
        return .{
            .ptr = self,
            .hitFn = hit,
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
};
