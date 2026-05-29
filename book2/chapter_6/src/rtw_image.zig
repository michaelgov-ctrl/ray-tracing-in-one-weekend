const std = @import("std");

const c = @cImport({
    @cInclude("stb_image.h");
});

const Color = @import("color.zig").Color;

pub const RtwImage = struct {
    const Self = @This();

    const bytes_per_pixel: c_int = 3;

    allocator: std.mem.Allocator,

    fdata: [*c]f32 = null,
    bdata: ?[]u8 = null,

    image_width: c_int = 0,
    image_height: c_int = 0,
    bytes_per_scanline: i64 = 0,

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
        };
    }

    pub fn initFromFile(
        allocator: std.mem.Allocator,
        image_filename: []const u8,
    ) !Self {
        var image = Self.init(allocator);

        if (try image.loadFromSearchPaths(image_filename)) {
            return image;
        }

        std.debug.print("ERROR: Could not load image file '{s}'.\n", .{image_filename});
        return image;
    }

    pub fn deinit(self: *Self) void {
        if (self.bdata) |bytes| {
            self.allocator.free(bytes);
            self.bdata = null;
        }

        if (self.fdata) |data| {
            c.stbi_image_free(data);
            self.fdata = null;
        }
    }

    fn loadFromSearchPaths(self: *Self, image_filename: []const u8) !bool {
        const path = try std.fmt.allocPrint(self.allocator, "images/{s}", .{image_filename});
        defer self.allocator.free(path);

        if (try self.load(path)) return true;

        return false;
    }

    pub fn load(self: *Self, filename: []const u8) !bool {
        // stbi_loadf expects a null-terminated C string.
        const c_filename = try self.allocator.dupeZ(u8, filename);
        defer self.allocator.free(c_filename);

        var n: c_int = bytes_per_pixel;

        const data = c.stbi_loadf(
            c_filename.ptr,
            &self.image_width,
            &self.image_height,
            &n,
            bytes_per_pixel,
        );

        if (data == null) {
            return false;
        }

        // If this image already had data, clean it up before replacing it.
        self.deinit();

        self.fdata = data;
        self.bytes_per_scanline = self.image_width * bytes_per_pixel;

        try self.convertToBytes();
        return true;
    }

    pub fn width(self: Self) i64 {
        return if (self.fdata == null) 0 else self.image_width;
    }

    pub fn height(self: Self) i64 {
        return if (self.fdata == null) 0 else self.image_height;
    }

    pub fn pixelData(self: Self, x_in: i64, y_in: i64) Color {
        if (self.bdata == null) {
            // if no data return magenta
            return Color.init(255.0, 0.0, 255.0);
        }

        const x = clamp(x_in, 0, self.image_width);
        const y = clamp(y_in, 0, self.image_height);

        const index: usize = @intCast(
            y * self.bytes_per_scanline + x * bytes_per_pixel,
        );

        const data = self.bdata.?;

        // normalize the color
        const r: f64 = @as(f64, @floatFromInt(data[index + 0])) / 255.0;
        const g: f64 = @as(f64, @floatFromInt(data[index + 1])) / 255.0;
        const b: f64 = @as(f64, @floatFromInt(data[index + 2])) / 255.0;

        return Color.init(r, g, b);
    }

    fn convertToBytes(self: *Self) !void {
        const total_bytes: usize = @intCast(self.image_width * self.image_height * bytes_per_pixel);

        const bytes = try self.allocator.alloc(u8, total_bytes);
        errdefer self.allocator.free(bytes);

        const floats = self.fdata[0..total_bytes];

        for (bytes, floats) |*b, f| {
            b.* = floatToByte(f);
        }

        self.bdata = bytes;
    }

    fn clamp(x: i64, low: i64, high: i64) i64 {
        if (x < low) return low;
        if (x < high) return x;
        return high - 1;
    }

    fn floatToByte(value: f64) u8 {
        if (value <= 0.0) return 0;
        if (value >= 1.0) return 255;

        return @intFromFloat(256.0 * value);
    }
};
