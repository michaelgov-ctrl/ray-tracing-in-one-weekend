const std = @import("std");

const Color = @import("color.zig").Color;
const HitRecord = @import("hittable.zig").HitRecord;
const Point3 = @import("vec3.zig").Point3;
const Ray = @import("ray.zig").Ray;
const SolidColor = @import("texture.zig").SolidColor;
const Texture = @import("texture.zig").Texture;
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

    emittedFn: *const fn (
        ptr: *const anyopaque,
        u: f64,
        v: f64,
        p: Point3,
    ) Color,

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

    pub fn emitted(
        self: Self,
        u: f64,
        v: f64,
        p: Point3,
    ) Color {
        return self.emittedFn(
            self.ptr,
            u,
            v,
            p,
        );
    }
};

pub const Lambertian = struct {
    const Self = @This();

    texture: Texture,

    pub fn initFromTexture(texture: Texture) Self {
        return .{
            .texture = texture,
        };
    }

    pub fn material(self: *const Self) Material {
        return .{
            .ptr = self,
            .scatterFn = scatter,
            .emittedFn = emitted,
        };
    }

    fn scatter(
        ptr: *const anyopaque,
        rng: std.Random,
        rIn: Ray,
        rec: HitRecord,
    ) ?ScatterResult {
        const self: *const Self = @ptrCast(@alignCast(ptr));

        var scatterDirection = rec.normal.add(Vec3.randomUnitVector(rng));
        if (scatterDirection.nearZero()) scatterDirection = rec.normal;

        return .{
            .attenuation = self.texture.value(
                rec.u,
                rec.v,
                rec.p,
            ),
            .scattered = Ray.init(
                rec.p,
                scatterDirection,
                rIn.time,
            ),
        };
    }

    pub fn emitted(
        ptr: *const anyopaque,
        u: f64,
        v: f64,
        p: Point3,
    ) Color {
        const self: *const Self = @ptrCast(@alignCast(ptr));

        _ = self;
        _ = u;
        _ = v;
        _ = p;

        return Color.init(0.0, 0.0, 0.0);
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
            .emittedFn = emitted,
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
            .scattered = Ray.init(
                rec.p,
                reflected,
                rIn.time,
            ),
        };
    }

    pub fn emitted(
        ptr: *const anyopaque,
        u: f64,
        v: f64,
        p: Point3,
    ) Color {
        const self: *const Self = @ptrCast(@alignCast(ptr));

        _ = self;
        _ = u;
        _ = v;
        _ = p;

        return Color.init(0.0, 0.0, 0.0);
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
            .emittedFn = emitted,
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
            .scattered = Ray.init(
                rec.p,
                direction,
                rIn.time,
            ),
        };
    }

    fn reflectance(cosine: f64, refractionIndex: f64) f64 {
        // Use Schlick's approximation for reflectance.
        var r0 = (1 - refractionIndex) / (1 + refractionIndex);
        r0 = r0 * r0;
        return r0 + (1 - r0) * std.math.pow(f64, 1 - cosine, 5);
    }

    pub fn emitted(
        ptr: *const anyopaque,
        u: f64,
        v: f64,
        p: Point3,
    ) Color {
        const self: *const Self = @ptrCast(@alignCast(ptr));

        _ = self;
        _ = u;
        _ = v;
        _ = p;

        return Color.init(0.0, 0.0, 0.0);
    }
};

pub const DiffuseLight = struct {
    const Self = @This();

    texture: Texture,

    pub fn initFromTexture(texture: Texture) Self {
        return .{
            .texture = texture,
        };
    }

    pub fn material(self: *const Self) Material {
        return .{
            .ptr = self,
            .scatterFn = scatter,
            .emittedFn = emitted,
        };
    }

    fn scatter(
        ptr: *const anyopaque,
        rng: std.Random,
        rIn: Ray,
        rec: HitRecord,
    ) ?ScatterResult {
        const self: *const Self = @ptrCast(@alignCast(ptr));

        _ = self;
        _ = rng;
        _ = rIn;
        _ = rec;

        return null;
    }

    pub fn emitted(
        ptr: *const anyopaque,
        u: f64,
        v: f64,
        p: Point3,
    ) Color {
        const self: *const Self = @ptrCast(@alignCast(ptr));

        return self.texture.value(u, v, p);
    }
};

pub const Isotropic = struct {
    const Self = @This();

    tex: Texture,

    pub fn init(tex: Texture) Self {
        return .{
            .tex = tex,
        };
    }

    pub fn material(self: *const Self) Material {
        return .{
            .ptr = self,
            .scatterFn = scatter,
            .emittedFn = emitted,
        };
    }

    fn scatter(
        ptr: *const anyopaque,
        rng: std.Random,
        rIn: Ray,
        rec: HitRecord,
    ) ?ScatterResult {
        const self: *const Self = @ptrCast(@alignCast(ptr));

        return .{
            .attenuation = self.tex.value(
                rec.u,
                rec.v,
                rec.p,
            ),
            .scattered = Ray.init(
                rec.p,
                Vec3.randomUnitVector(rng),
                rIn.time,
            ),
        };
    }

    pub fn emitted(
        ptr: *const anyopaque,
        u: f64,
        v: f64,
        p: Point3,
    ) Color {
        const self: *const Self = @ptrCast(@alignCast(ptr));

        _ = self;
        _ = u;
        _ = v;
        _ = p;

        return Color.init(0.0, 0.0, 0.0);
    }
};
