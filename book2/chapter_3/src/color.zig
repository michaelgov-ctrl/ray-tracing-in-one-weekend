const std = @import("std");
const vec3 = @import("vec3.zig");

const Interval = @import("interval.zig").Interval;

pub const Color = vec3.Vec3;

pub fn colorByte(f: f64) u8 {
    return @as(u8, @intFromFloat(256 * f));
}

pub fn linearToGamma(linearComponent: f64) f64 {
    return if (linearComponent > 0) std.math.sqrt(linearComponent) else 0;
}

pub fn writeColor(writer: *std.Io.Writer, pixelColor: Color) !void {
    var r = pixelColor.x;
    var g = pixelColor.y;
    var b = pixelColor.z;

    // Apply a lineat to gamma transform for gamma 2
    r = linearToGamma(r);
    g = linearToGamma(g);
    b = linearToGamma(b);

    // translate the [0,1] component values to the byte range [0,255].
    const intensity = Interval.init(0.000, 0.999);
    const rbyte = colorByte(intensity.clamp(r));
    const gbyte = colorByte(intensity.clamp(g));
    const bbyte = colorByte(intensity.clamp(b));

    try writer.print("{} {} {}\n", .{ rbyte, gbyte, bbyte });
    try writer.flush();
}

pub fn colorConvert(n: usize, pos: comptime_int) f64 {
    return @as(f64, @as(f64, @floatFromInt(n)) / @as(f64, @floatFromInt(pos)));
}
