const std = @import("std");

const Color = @import("color.zig").Color;
const HitRecord = @import("hittable.zig").HitRecord;
const Ray = @import("ray.zig").Ray;
const Vec3 = @import("vec3.zig").Vec3;

pub const ScatterResult = struct {
    attenuation: Color,
    scattered: Ray,
};

pub const Material = struct {
    const Self = @This();

    ptr: *const anyopaque,
    scatterFn: *const fn (
        ptr: *const anyopaque,
        rng: std.Random,
        rIn: Ray,
        rec: HitRecord,
    ) ?ScatterResult,

    pub fn scatter(
        self: Self,
        rng: std.Random,
        rIn: Ray,
        rec: HitRecord,
    ) ?ScatterResult {
        return self.scatterFn(
            self.ptr,
            rng,
            rIn,
            rec,
        );
    }
};

pub const Labertian = struct {
    const Self = @This();

    albedo: Color,

    pub fn init(al: Color) Self {
        return .{
            .albedo = al,
        };
    }

    pub fn material(self: *const Self) Material {
        return .{
            .ptr = self,
            .scatterFn = scatter,
        };
    }

    fn scatter(
        ptr: *const anyopaque,
        rng: std.Random,
        rIn: Ray,
        rec: HitRecord,
    ) ?ScatterResult {
        _ = rIn;

        const self: *const Self = @ptrCast(@alignCast(ptr));

        var scatterDirection = rec.normal.add(Vec3.randomUnitVector(rng));
        if (scatterDirection.nearZero()) scatterDirection = rec.normal;

        return .{
            .attenuation = self.albedo,
            .scattered = Ray.init(rec.p, scatterDirection),
        };
    }
};

pub const Metal = struct {
    const Self = @This();

    albedo: Color,
    fuzz: f64,

    pub fn init(albedo: Color, fuzz: f64) Self {
        return .{
            .albedo = albedo,
            .fuzz = if (fuzz < 1.0) fuzz else 1.0,
        };
    }

    pub fn material(self: *const Self) Material {
        return .{
            .ptr = self,
            .scatterFn = scatter,
        };
    }

    fn scatter(
        ptr: *const anyopaque,
        rng: std.Random,
        rIn: Ray,
        rec: HitRecord,
    ) ?ScatterResult {
        const self: *const Self = @ptrCast(@alignCast(ptr));

        var reflected = rIn.direction.reflect(rec.normal);
        reflected = reflected.unitVector()
            .add(Vec3.randomUnitVector(rng).scale(self.fuzz));

        return .{
            .attenuation = self.albedo,
            .scattered = Ray.init(rec.p, reflected),
        };
    }
};
