const std = @import("std");

const Point3 = @import("vec3.zig").Point3;
const Vec3 = @import("vec3.zig").Vec3;

pub const Perlin = struct {
    const Self = @This();
    const point_count: usize = 256;

    rng: std.Random,

    rand_vec: [point_count]Vec3,
    perm_x: [point_count]usize,
    perm_y: [point_count]usize,
    perm_z: [point_count]usize,

    pub fn init(rng: std.Random) Self {
        var self: Self = undefined;

        self.rng = rng;

        for (0..point_count) |i| {
            self.rand_vec[i] = Vec3.randomRange(self.rng, -1.0, 1.0);
        }

        self.perlinGeneratePerm(&self.perm_x);
        self.perlinGeneratePerm(&self.perm_y);
        self.perlinGeneratePerm(&self.perm_z);

        return self;
    }

    pub fn noise(self: Self, p: Point3) f64 {
        const u = p.x - @floor(p.x);
        const v = p.y - @floor(p.y);
        const w = p.z - @floor(p.z);

        const i: i64 = @intFromFloat(@floor(p.x));
        const j: i64 = @intFromFloat(@floor(p.y));
        const k: i64 = @intFromFloat(@floor(p.z));
        var c: [2][2][2]Vec3 = undefined;

        for (0..2) |di| {
            for (0..2) |dj| {
                for (0..2) |dk| {
                    const ix: usize = @intCast((i + @as(i64, @intCast(di))) & 255);
                    const jy: usize = @intCast((j + @as(i64, @intCast(dj))) & 255);
                    const kz: usize = @intCast((k + @as(i64, @intCast(dk))) & 255);

                    const idx = self.perm_x[ix] ^
                        self.perm_y[jy] ^
                        self.perm_z[kz];

                    c[di][dj][dk] = self.rand_vec[idx];
                }
            }
        }

        return perlinInterpolate(c, u, v, w);
    }

    pub fn turbulence(self: Self, p: Point3, depth: usize) f64 {
        var accum: f64 = 0.0;
        var weight: f64 = 1.0;
        var temp_p = p;

        for (0..depth) |_| {
            accum += weight * self.noise(temp_p);
            weight *= 0.5;
            temp_p = temp_p.scale(2.0);
        }

        return @abs(accum);
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

    // this feels like perhaps 2's shouldn't be so hard coded..
    fn trilinearInterpolate(c: [2][2][2]f64, u: f64, v: f64, w: f64) f64 {
        var accum: f64 = 0.0;

        for (0..2) |i| {
            for (0..2) |j| {
                for (0..2) |k| {
                    const fi = @as(f64, @floatFromInt(i));
                    const fj = @as(f64, @floatFromInt(j));
                    const fk = @as(f64, @floatFromInt(k));

                    accum += (fi * u + (1.0 - fi) * (1.0 - u)) *
                        (fj * v + (1.0 - fj) * (1.0 - v)) *
                        (fk * w + (1.0 - fk) * (1.0 - w)) *
                        c[i][j][k];
                }
            }
        }

        return accum;
    }

    fn perlinInterpolate(c: [2][2][2]Vec3, u: f64, v: f64, w: f64) f64 {
        // hermite cubic to round and prevent Mach bands & griding
        const uu = u * u * (3.0 - 2.0 * u);
        const vv = v * v * (3.0 - 2.0 * v);
        const ww = w * w * (3.0 - 2.0 * w);

        var accum: f64 = 0.0;

        for (0..2) |i| {
            for (0..2) |j| {
                for (0..2) |k| {
                    const fi = @as(f64, @floatFromInt(i));
                    const fj = @as(f64, @floatFromInt(j));
                    const fk = @as(f64, @floatFromInt(k));

                    const weight_v = Vec3.init(
                        u - fi,
                        v - fj,
                        w - fk,
                    );

                    accum += (fi * uu + (1.0 - fi) * (1.0 - uu)) *
                        (fj * vv + (1.0 - fj) * (1.0 - vv)) *
                        (fk * ww + (1.0 - fk) * (1.0 - ww)) *
                        weight_v.dot(c[i][j][k]);
                }
            }
        }

        return accum;
    }
};
