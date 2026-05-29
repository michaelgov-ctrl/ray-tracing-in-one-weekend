const std = @import("std");

const Point3 = @import("vec3.zig").Point3;

pub const Perlin = struct {
    const Self = @This();
    const point_count: usize = 256;

    rng: std.Random,

    rand_float: [point_count]f64,
    perm_x: [point_count]usize,
    perm_y: [point_count]usize,
    perm_z: [point_count]usize,

    pub fn init(rng: std.Random) Self {
        var self: Self = undefined;

        self.rng = rng;

        for (0..point_count) |i| {
            self.rand_float[i] = self.rng.float(f64);
        }

        self.perlinGeneratePerm(&self.perm_x);
        self.perlinGeneratePerm(&self.perm_y);
        self.perlinGeneratePerm(&self.perm_z);

        return self;
    }

    pub fn noise(self: Self, p: Point3) f64 {
        const i = @as(usize, @intFromFloat(4.0 * p.x)) & 255;
        const j = @as(usize, @intFromFloat(4.0 * p.y)) & 255;
        const k = @as(usize, @intFromFloat(4.0 * p.z)) & 255;

        const idx = self.perm_x[i] ^ self.perm_y[j] ^ self.perm_z[k];
        return self.rand_float[idx];
    }

    fn perlinGeneratePerm(self: Self, p: *[point_count]usize) void {
        for (0..point_count) |i| {
            p[i] = i;
        }

        self.permute(p, point_count);
    }

    fn permute(self: Self, p: *[point_count]usize, n: usize) void {
        var i = n - 1;
        while (i > 0) : (i -= 1) {
            const target = self.rng.intRangeAtMost(usize, 0, i);

            const tmp = p[i];
            p[i] = p[target];
            p[target] = tmp;
        }
    }

    //fn trilinearInterpolate(c: [2][2][2]f64, u: f64, v: f64, w: f64) f64 {}
};
