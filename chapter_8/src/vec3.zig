pub const Vec3 = struct {
    x: f64 = 0.0,
    y: f64 = 0.0,
    z: f64 = 0.0,

    pub fn init(x: f64, y: f64, z: f64) Vec3 {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn add(self: Vec3, v: Vec3) Vec3 {
        return .{
            .x = self.x + v.x,
            .y = self.y + v.y,
            .z = self.z + v.z,
        };
    }

    pub fn sub(self: Vec3, v: Vec3) Vec3 {
        return .{
            .x = self.x - v.x,
            .y = self.y - v.y,
            .z = self.z - v.z,
        };
    }

    pub fn neg(self: Vec3) Vec3 {
        return .{
            .x = -self.x,
            .y = -self.y,
            .z = -self.z,
        };
    }

    pub fn scale(self: Vec3, t: f64) Vec3 {
        return .{
            .x = self.x * t,
            .y = self.y * t,
            .z = self.z * t,
        };
    }

    pub fn div(self: Vec3, t: f64) Vec3 {
        return Vec3.scale(self, 1.0 / t);
    }

    pub fn dot(self: Vec3, v: Vec3) f64 {
        return self.x * v.x +
            self.y * v.y +
            self.z * v.z;
    }

    pub fn lengthSquared(self: Vec3) f64 {
        return self.dot(self);
    }

    pub fn length(self: Vec3) f64 {
        return @sqrt(self.lengthSquared());
    }

    pub fn unitVector(self: Vec3) Vec3 {
        return self.div(self.length());
    }

    pub fn cross(self: Vec3, v: Vec3) Vec3 {
        return .{
            .x = self.y * v.z - self.z * v.y,
            .y = self.z * v.x - self.x * v.z,
            .z = self.x * v.y - self.y * v.x,
        };
    }
};

pub const Point3 = Vec3;
