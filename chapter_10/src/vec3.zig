const std = @import("std");

pub const Vec3 = struct {
    const Self = @This();

    x: f64 = 0.0,
    y: f64 = 0.0,
    z: f64 = 0.0,

    pub fn init(x: f64, y: f64, z: f64) Self {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn add(self: Self, v: Vec3) Vec3 {
        return .{
            .x = self.x + v.x,
            .y = self.y + v.y,
            .z = self.z + v.z,
        };
    }

    pub fn sub(self: Self, v: Vec3) Vec3 {
        return .{
            .x = self.x - v.x,
            .y = self.y - v.y,
            .z = self.z - v.z,
        };
    }

    pub fn neg(self: Self) Vec3 {
        return .{
            .x = -self.x,
            .y = -self.y,
            .z = -self.z,
        };
    }

    pub fn scale(self: Self, t: f64) Vec3 {
        return .{
            .x = self.x * t,
            .y = self.y * t,
            .z = self.z * t,
        };
    }

    pub fn div(self: Self, t: f64) Vec3 {
        return Vec3.scale(self, 1.0 / t);
    }

    pub fn dot(self: Self, v: Vec3) f64 {
        return self.x * v.x +
            self.y * v.y +
            self.z * v.z;
    }

    pub fn lengthSquared(self: Self) f64 {
        return self.dot(self);
    }

    pub fn length(self: Self) f64 {
        return @sqrt(self.lengthSquared());
    }

    pub fn random(rng: std.Random) Vec3 {
        return .{
            .x = rng.float(f64),
            .y = rng.float(f64),
            .z = rng.float(f64),
        };
    }

    pub fn randomRange(rng: std.Random, min: f64, max: f64) Vec3 {
        return .{
            .x = randomDouble(rng, min, max),
            .y = randomDouble(rng, min, max),
            .z = randomDouble(rng, min, max),
        };
    }

    pub fn unitVector(self: Self) Vec3 {
        return self.div(self.length());
    }

    pub fn randomUnitVector(rng: std.Random) Vec3 {
        while (true) {
            const p = Vec3.randomRange(rng, -1.0, 1.0);
            const lensq = p.lengthSquared();

            // avoid divide by zero
            if (lensq > 1e-160 and lensq <= 1.0) {
                return p.div(@sqrt(lensq));
            }
        }
    }

    pub fn randomOnHemisphere(self: Self, rng: std.Random) Vec3 {
        const onUnitSphere = randomUnitVector(rng);

        // if the points are in the same hemisphere
        return if (self.dot(onUnitSphere) > 0.0) onUnitSphere else onUnitSphere.neg();
    }

    pub fn cross(self: Self, v: Vec3) Vec3 {
        return .{
            .x = self.y * v.z - self.z * v.y,
            .y = self.z * v.x - self.x * v.z,
            .z = self.x * v.y - self.y * v.x,
        };
    }
};

fn randomDouble(rng: std.Random, min: f64, max: f64) f64 {
    // https://www.reddit.com/r/learnprogramming/comments/sk21qj/generate_a_random_number_within_a_range_how_does/
    return min + (max - min) * rng.float(f64);
}

pub const Point3 = Vec3;
