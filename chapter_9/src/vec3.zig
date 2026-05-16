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

    pub fn unitVector(self: Self) Vec3 {
        return self.div(self.length());
    }

    pub fn cross(self: Self, v: Vec3) Vec3 {
        return .{
            .x = self.y * v.z - self.z * v.y,
            .y = self.z * v.x - self.x * v.z,
            .z = self.x * v.y - self.y * v.x,
        };
    }
};

pub const Point3 = Vec3;
