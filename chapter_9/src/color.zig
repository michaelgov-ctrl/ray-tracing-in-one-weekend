const std = @import("std");
const vec3 = @import("vec3.zig");

const Interval = @import("interval.zig").Interval;

pub const Color = vec3.Vec3;

pub fn colorByte(f: f64) u8 {
    return @as(u8, @intFromFloat(256 * f));
}

pub fn writeColor(writer: *std.Io.Writer, pixelColor: Color) !void {
    const r = pixelColor.x;
    const g = pixelColor.y;
    const b = pixelColor.z;

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
