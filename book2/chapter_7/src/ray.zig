const vec3 = @import("vec3.zig");

pub const Ray = struct {
    const Self = @This();

    origin: vec3.Point3,
    direction: vec3.Vec3,
    time: f64,

    pub fn init(
        origin: vec3.Point3,
        direction: vec3.Vec3,
        time: f64,
    ) Self {
        return .{
            .origin = origin,
            .direction = direction,
            .time = time,
        };
    }

    pub fn at(self: Self, t: f64) vec3.Point3 {
        return self.origin.add(self.direction.scale(t));
    }
};
