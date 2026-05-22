const Color = @import("color.zig").Color;
const Point3 = @import("vec3.zig").Point3;

pub const Texture = struct {
    const Self = @This();

    ptr: *const anyopaque,

    valueFn: *const fn (
        ptr: *const anyopaque,
        u: f64,
        v: f64,
        p: Point3,
    ) Color,

    pub fn value(
        self: Self,
        u: f64,
        v: f64,
        p: Point3,
    ) Color {
        return self.valueFn(self.ptr, u, v, p);
    }
};

pub const SolidColor = struct {
    const Self = @This();

    albedo: Color,

    pub fn initFromAlbedo(albedo: Color) Self {
        return .{ .albedo = albedo };
    }

    pub fn initFromRGB(r: f64, g: f64, b: f64) Self {
        return .{
            .albedo = Color.init(
                r,
                g,
                b,
            ),
        };
    }

    pub fn texture(self: *const Self) Texture {
        return .{
            .ptr = self,
            .valueFn = value,
        };
    }

    fn value(
        ptr: *const anyopaque,
        u: f64,
        v: f64,
        p: Point3,
    ) Color {
        const self: *const Self = @ptrCast(@alignCast(ptr));

        _ = u;
        _ = v;
        _ = p;

        return self.albedo;
    }
};

pub const CheckerTexture = struct {
    const Self = @This();

    invScale: f64,
    even: Color,
    odd: Color,

    pub fn initFromColors(
        scale: f64,
        c1: Color,
        c2: Color,
    ) Self {
        return .{
            .invScale = 1.0 / scale,
            .even = c1,
            .odd = c2,
        };
    }

    pub fn texture(self: *const Self) Texture {
        return .{
            .ptr = self,
            .valueFn = value,
        };
    }

    fn value(
        ptr: *const anyopaque,
        u: f64,
        v: f64,
        p: Point3,
    ) Color {
        const self: *const Self = @ptrCast(@alignCast(ptr));

        _ = u;
        _ = v;

        const xInt: i64 = @intFromFloat(@floor(self.invScale * p.x));
        const yInt: i64 = @intFromFloat(@floor(self.invScale * p.y));
        const zInt: i64 = @intFromFloat(@floor(self.invScale * p.z));

        const isEven = @mod(xInt + yInt + zInt, 2) == 0;

        return if (isEven)
            self.even
        else
            self.odd;
    }
};
