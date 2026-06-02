const std = @import("std");

const Color = @import("color.zig").Color;
const Interval = @import("interval.zig").Interval;
const Perlin = @import("perlin.zig").Perlin;
const Point3 = @import("vec3.zig").Point3;
const RtwImage = @import("rtw_image.zig").RtwImage;

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

pub const ImageTexture = struct {
    const Self = @This();

    image: RtwImage,

    pub fn initFromFile(allocator: std.mem.Allocator, filename: []const u8) !Self {
        return .{
            .image = try RtwImage.initFromFile(allocator, filename),
        };
    }

    pub fn deinit(self: *Self) void {
        return self.image.deinit();
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

        _ = p;

        // If we have no texture data, then return solid cyan as a debugging aid.
        if (self.image.height() <= 0) return Color.init(0.0, 1.0, 1.0);

        // Clamp input texture coordinates to [0,1] x [1,0]
        const u_clamp = Interval.init(0.0, 1.0).clamp(u);
        const v_clamp = 1.0 - Interval.init(0.0, 1.0).clamp(v);

        const i: i64 = @intFromFloat(u_clamp * @as(f64, @floatFromInt(self.image.width())));
        const j: i64 = @intFromFloat(v_clamp * @as(f64, @floatFromInt(self.image.height())));

        return self.image.pixelData(i, j);
    }
};

pub const NoiseTexture = struct {
    const Self = @This();

    noise: Perlin,
    scale: f64,

    pub fn init(noise: Perlin, scale: f64) Self {
        return .{
            .noise = noise,
            .scale = scale,
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

        return Color.init(0.5, 0.5, 0.5)
            .scale(1.0 + std.math.sin(self.scale * p.z + 10.0 *
            self.noise.turbulence(p, 7)));
    }
};
