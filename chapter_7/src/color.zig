const std = @import("std");
const vec3 = @import("vec3.zig");

pub const Color = vec3.Vec3;

pub fn colorByte(f: f64) u8 {
    return @as(u8, @intFromFloat(255.999 * f));
}

pub fn writeColor(writer: *std.Io.Writer, pixelColor: *const Color) !void {
    const r = pixelColor.x;
    const g = pixelColor.y;
    const b = pixelColor.z;

    const rbyte = colorByte(r);
    const gbyte = colorByte(g);
    const bbyte = colorByte(b);

    try writer.print("{} {} {}\n", .{ rbyte, gbyte, bbyte });
    try writer.flush();
}

pub fn colorConvert(n: usize, pos: comptime_int) f64 {
    return @as(f64, @as(f64, @floatFromInt(n)) / @as(f64, @floatFromInt(pos)));
}
