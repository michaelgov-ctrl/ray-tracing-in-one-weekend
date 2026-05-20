pub const Vec3 = struct {
    x: f64 = 0.0,
    y: f64 = 0.0,
    z: f64 = 0.0,

    pub fn init(x: f64, y: f64, z: f64) Vec3 {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn addEqls(self: *Vec3, v: Vec3) void {
        self.x += v.x;
        self.y += v.y;
        self.z += v.z;
    }

    pub fn subEqls(self: *Vec3, v: Vec3) void {
        self.x -= v.x;
        self.y -= v.y;
        self.z -= v.z;
    }

    pub fn scaleEqls(self: *Vec3, t: f64) void {
        self.x *= t;
        self.y *= t;
        self.z *= t;
    }

    pub fn divEqls(self: *Vec3, t: f64) void {
        self.scaleEqls(1.0 / t);
    }

    pub fn add(a: Vec3, b: Vec3) Vec3 {
        return .{
            .x = a.x + b.x,
            .y = a.y + b.y,
            .z = a.z + b.z,
        };
    }

    pub fn sub(a: Vec3, b: Vec3) Vec3 {
        return .{
            .x = a.x - b.x,
            .y = a.y - b.y,
            .z = a.z - b.z,
        };
    }

    pub fn scale(v: Vec3, t: f64) Vec3 {
        return .{
            .x = v.x * t,
            .y = v.y * t,
            .z = v.z * t,
        };
    }

    pub fn div(v: Vec3, t: f64) Vec3 {
        return Vec3.scale(v, 1.0 / t);
    }

    pub fn dot(a: Vec3, b: Vec3) f64 {
        return a.x * b.x +
            a.y * b.y +
            a.z * b.z;
    }

    pub fn lengthSquared(v: Vec3) f64 {
        return Vec3.dot(v, v);
    }

    pub fn length(v: Vec3) f64 {
        return @sqrt(v.lengthSquared());
    }

    pub fn unit_vector(v: Vec3) Vec3 {
        return v.div(v.length());
    }

    pub fn cross(a: Vec3, b: Vec3) Vec3 {
        return .{
            .x = a.y * b.z - a.z * b.y,
            .y = a.z * b.x - a.x * b.z,
            .z = a.x * b.y - a.y * b.x,
        };
    }
};

pub const Point3 = Vec3;
