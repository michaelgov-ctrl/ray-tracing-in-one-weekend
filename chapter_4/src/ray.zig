const vec3 = @import("vec3.zig");

pub const Ray = struct {
    origin: vec3.Point3,
    direction: vec3.Vec3,

    pub fn init(orig: vec3.Point3, dir: vec3.Vec3) Ray {
        return .{
            .origin = orig,
            .direction = dir,
        };
    }

    pub fn at(self: Ray, t: f64) vec3.Point3 {
        return self.origin.addEqls(self.direction.scaleEqls(t));
    }
};
