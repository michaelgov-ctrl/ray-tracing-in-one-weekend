const vec3 = @import("vec3.zig");

pub const Ray = struct {
    const Self = @This();

    origin: vec3.Point3,
    direction: vec3.Vec3,

    pub fn init(orig: vec3.Point3, dir: vec3.Vec3) Self {
        return .{
            .origin = orig,
            .direction = dir,
        };
    }

    pub fn at(self: Self, t: f64) vec3.Point3 {
        return self.origin.add(self.direction.scale(t));
    }
};
