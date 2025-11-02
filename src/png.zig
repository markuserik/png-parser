const std = @import("std");
const fs = std.fs;

pub const Raw = @import("raw.zig");
pub const Png = @This();

width: u32,
height: u32,
pixels: [][]Pixel,
raw: Raw,
arena: std.heap.ArenaAllocator,

pub fn deinit(self: *Png) void {
    self.arena.deinit();
}

pub fn parseFileFromPath(file_path: []const u8, allocator: std.mem.Allocator) !Png {
    const file = try fs.cwd().openFile(file_path, .{});
    defer file.close();

    return parseFile(file, allocator);
}

pub fn parseFile(file: fs.File, allocator: std.mem.Allocator) !Png {
    const raw_file = try allocator.alloc(u8, (try file.stat()).size);
    _ = try file.read(raw_file);
    defer allocator.free(raw_file);

    return parseRaw(raw_file, allocator);
}

pub fn parseRaw(raw_file: []u8, allocator: std.mem.Allocator) !Png {
    var raw_png = try Raw.parseRaw(raw_file, allocator);
    const pixels = try parsePixels(&raw_png);
    
    return Png{
        .width = raw_png.ihdr.width,
        .height = raw_png.ihdr.height,
        .pixels = pixels,
        .raw = raw_png,
        .arena = raw_png.arena
    };
}

fn parsePixels(raw_png: *Raw) ![][]Pixel {
    const allocator = raw_png.arena.allocator();
    const height = raw_png.ihdr.height;
    const width = raw_png.ihdr.width;
    const raw_pixels = raw_png.idat.pixels;
    const bit_depth = raw_png.ihdr.bit_depth;

    var pixels = try allocator.alloc([]Pixel, height);
    for (0..pixels.len) |y| {
        pixels[y] = try allocator.alloc(Pixel, width);
    }

    for (0..height) |y| {
        for (0..width) |x| {
            switch (raw_png.ihdr.color_type) {
                .Greyscale => {
                    if (bit_depth == 8) {
                        pixels[y][x].r = val8to16(raw_pixels[y][x].greyscale8.?);
                        pixels[y][x].g = val8to16(raw_pixels[y][x].greyscale8.?);
                        pixels[y][x].b = val8to16(raw_pixels[y][x].greyscale8.?);
                    }
                    else if(bit_depth == 16) {
                        pixels[y][x].r = raw_pixels[y][x].greyscale16.?;
                        pixels[y][x].g = raw_pixels[y][x].greyscale16.?;
                        pixels[y][x].b = raw_pixels[y][x].greyscale16.?;
                    }
                    else return error.BitDepthNotImplemented;
                },
                .Truecolor => {
                    if (bit_depth == 8) {
                        pixels[y][x].r = val8to16(raw_pixels[y][x].r8.?);
                        pixels[y][x].g = val8to16(raw_pixels[y][x].g8.?);
                        pixels[y][x].b = val8to16(raw_pixels[y][x].b8.?);
                        pixels[y][x].a = 65535;
                    }
                    else {
                        pixels[y][x].r = raw_pixels[y][x].r16.?;
                        pixels[y][x].g = raw_pixels[y][x].g16.?;
                        pixels[y][x].b = raw_pixels[y][x].b16.?;
                        pixels[y][x].a = 65535;
                    }
                },
                .Indexed_color => {
                    if (bit_depth == 8) {
                        const entry = raw_png.plte.?.entries[raw_pixels[y][x].index.?];
                        pixels[y][x].r = val8to16(entry.r);
                        pixels[y][x].g = val8to16(entry.g);
                        pixels[y][x].b = val8to16(entry.b);
                        pixels[y][x].a = 65535;
                    }
                    else return error.BitDepthNotImplemented;
                },
                .Greyscale_with_alpha => {
                    if (bit_depth == 8) {
                        pixels[y][x].r = val8to16(raw_pixels[y][x].greyscale8.?);
                        pixels[y][x].g = val8to16(raw_pixels[y][x].greyscale8.?);
                        pixels[y][x].b = val8to16(raw_pixels[y][x].greyscale8.?);
                        pixels[y][x].a = val8to16(raw_pixels[y][x].alpha8.?);
                    }
                    else if(bit_depth == 16) {
                        pixels[y][x].r = raw_pixels[y][x].greyscale16.?;
                        pixels[y][x].g = raw_pixels[y][x].greyscale16.?;
                        pixels[y][x].b = raw_pixels[y][x].greyscale16.?;
                        pixels[y][x].a = raw_pixels[y][x].alpha16.?;
                    }
                },
                .Truecolor_with_alpha => {
                    if (bit_depth == 8) {
                        pixels[y][x].r = val8to16(raw_pixels[y][x].r8.?);
                        pixels[y][x].g = val8to16(raw_pixels[y][x].g8.?);
                        pixels[y][x].b = val8to16(raw_pixels[y][x].b8.?);
                        pixels[y][x].a = val8to16(raw_pixels[y][x].alpha8.?);
                    }
                    else {
                        pixels[y][x].r = raw_pixels[y][x].r16.?;
                        pixels[y][x].g = raw_pixels[y][x].g16.?;
                        pixels[y][x].b = raw_pixels[y][x].b16.?;
                        pixels[y][x].a = raw_pixels[y][x].alpha16.?;
                    }
                }
            }
        }
    }

    for (0..height) |y| {
        for (0..width) |x| {
            pixels[y][x].pixel8bit.r = val16to8(pixels[y][x].r);
            pixels[y][x].pixel8bit.g = val16to8(pixels[y][x].g);
            pixels[y][x].pixel8bit.b = val16to8(pixels[y][x].b);
            pixels[y][x].pixel8bit.a = val16to8(pixels[y][x].a);
        }
    }
    return pixels;
}

fn val8to16(val: u8) u16 {
    return @intCast(val * @as(u16, 257));
}

fn val16to8(val: u16) u8 {
    return @intCast(val / 257);
}

pub const Pixel = struct {
    r: u16,
    g: u16,
    b: u16,
    a: u16,
    pixel8bit: Pixel8Bit
};

pub const Pixel8Bit= struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8
};
