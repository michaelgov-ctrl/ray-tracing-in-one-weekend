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

pub const Dielectric = struct {
    const Self = @This();

    // Refractive index in vacuum or air, or the ratio of the material's Refractive
    // index over the refractive index of the enclosing media.
    refractionIndex: f64,

    pub fn init(refractionIndex: f64) Self {
        return .{
            .refractionIndex = refractionIndex,
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

        const ri = if (rec.frontFace) 1.0 / self.refractionIndex else self.refractionIndex;

        const unitDirection = rIn.direction.unitVector();
        const cosTheta: f64 = @min(unitDirection.neg().dot(rec.normal), 1.0);
        const sinTheta: f64 = @sqrt(1.0 - cosTheta * cosTheta);

        const cannotRefract = ri * sinTheta > 1.0;

        const shouldReflect = cannotRefract or
            reflectance(cosTheta, ri) > rng.float(f64);

        const direction = if (shouldReflect)
            unitDirection.reflect(rec.normal)
        else
            unitDirection.refract(rec.normal, ri);

        return .{
            .attenuation = Color.init(1.0, 1.0, 1.0),
            .scattered = Ray.init(rec.p, direction),
        };
    }

    fn reflectance(cosine: f64, refractionIndex: f64) f64 {
        // Use Schlick's approximation for reflectance.
        var r0 = (1 - refractionIndex) / (1 + refractionIndex);
        r0 = r0 * r0;
        return r0 + (1 - r0) * std.math.pow(f64, 1 - cosine, 5);
    }
};
