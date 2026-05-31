const std = @import("std");
const h = @import("hittable.zig");

const BBox = @import("bbox.zig").BBox;
const Interval = @import("interval.zig").Interval;
const Ray = @import("ray.zig").Ray;

pub const BVHNode = struct {
    const Self = @This();

    left: h.Hittable,
    right: h.Hittable,
    bbox: BBox,

    pub fn initFromList(
        allocator: std.mem.Allocator,
        hl: h.HittableList,
        rng: std.Random,
    ) !Self {
        return Self.initFromObjects(
            allocator,
            rng,
            hl.objects.items,
            0,
            hl.objects.items.len,
        );
    }

    pub fn initFromObjects(
        allocator: std.mem.Allocator,
        rng: std.Random,
        objects: []h.Hittable,
        start: usize,
        end: usize,
    ) !Self {
        var bbox = BBox.empty;
        for (start..end) |i| {
            bbox = BBox.fromBoxes(bbox, objects[i].boundingBox());
        }

        const axis = bbox.longestAxis();
        const objectSpan = end - start;

        var left: h.Hittable = undefined;
        var right: h.Hittable = undefined;

        switch (objectSpan) {
            1 => {
                left = objects[start];
                right = objects[start];
            },
            2 => {
                const a = objects[start];
                const b = objects[start + 1];

                if (boxCompare(axis, a, b)) {
                    left = a;
                    right = b;
                } else {
                    left = b;
                    right = a;
                }
            },
            else => {
                std.mem.sort(
                    h.Hittable,
                    objects[start..end],
                    axis,
                    boxCompare,
                );

                const mid = start + objectSpan / 2;

                const leftNode = try allocator.create(Self);
                leftNode.* = try Self.initFromObjects(
                    allocator,
                    rng,
                    objects,
                    start,
                    mid,
                );

                const rightNode = try allocator.create(Self);
                rightNode.* = try Self.initFromObjects(
                    allocator,
                    rng,
                    objects,
                    mid,
                    end,
                );

                left = leftNode.hittable();
                right = rightNode.hittable();
            },
        }

        return .{
            .left = left,
            .right = right,
            .bbox = BBox.fromBoxes(
                left.boundingBox(),
                right.boundingBox(),
            ),
        };
    }

    pub fn hittable(self: *const Self) h.Hittable {
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
        rec: *h.HitRecord,
    ) bool {
        const self: *const Self = @ptrCast(@alignCast(ptr));

        if (!self.bbox.hittable().hit(
            r,
            ray_t,
            rec,
        )) return false;

        const hitLeft = self.left.hit(r, ray_t, rec);
        const hitRight = self.right.hit(
            r,
            Interval.init(
                ray_t.min,
                if (hitLeft) rec.t else ray_t.max,
            ),
            rec,
        );

        return hitLeft or hitRight;
    }

    pub fn boundingBox(ptr: *const anyopaque) BBox {
        const self: *const Self = @ptrCast(@alignCast(ptr));

        return self.bbox;
    }

    pub fn boxCompare(
        axis: usize,
        a: h.Hittable,
        b: h.Hittable,
    ) bool {
        const aAxis = a.boundingBox().axisInterval(axis);
        const bAxis = b.boundingBox().axisInterval(axis);

        return aAxis.min < bAxis.min;
    }
};
