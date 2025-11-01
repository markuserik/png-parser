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
    const file: fs.File = try fs.cwd().openFile(file_path, .{});
    defer file.close();

    return parseFile(file, allocator);
}

pub fn parseFile(file: fs.File, allocator: std.mem.Allocator) !Png {
    const raw_file: []u8 = try allocator.alloc(u8, (try file.stat()).size);
    _ = try file.read(raw_file);
    defer allocator.free(raw_file);

    return parseRaw(raw_file, allocator);
}

pub fn parseRaw(raw_file: []u8, allocator: std.mem.Allocator) !Png {
    var raw_png: Raw = try Raw.parseRaw(raw_file, allocator);
    const pixels: [][]Pixel = try parsePixels(&raw_png);
    
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
    const height: u32 = raw_png.ihdr.height;
    const width: u32 = raw_png.ihdr.width;
    const raw_pixels = raw_png.idat.pixels;
    const bit_depth = raw_png.ihdr.bit_depth;

    var pixels: [][]Pixel = try allocator.alloc([]Pixel, height);
    for (0..pixels.len) |y| {
        pixels[y] = try allocator.alloc(Pixel, width);
    }

    for (0..height) |y| {
        for (0..width) |x| {
            switch (raw_png.ihdr.color_type) {
                .Greyscale => return error.NotImplemented,
                .Truecolor => {
                    if (bit_depth == 8) {
                        pixels[y][x].r = raw_pixels[y][x].r8.?;
                        pixels[y][x].g = raw_pixels[y][x].g8.?;
                        pixels[y][x].b = raw_pixels[y][x].b8.?;
                        pixels[y][x].a = 255;
                    }
                    else {
                        pixels[y][x].r = val16to8(raw_pixels[y][x].r16.?);
                        pixels[y][x].g = val16to8(raw_pixels[y][x].g16.?);
                        pixels[y][x].b = val16to8(raw_pixels[y][x].b16.?);
                        pixels[y][x].a = 255;
                    }
                },
                .Indexed_color => return error.NotImplemented,
                .Greyscale_with_alpha => return error.NotImplemented,
                .Truecolor_with_alpha => {
                    if (bit_depth == 8) {
                        pixels[y][x].r = raw_pixels[y][x].r8.?;
                        pixels[y][x].g = raw_pixels[y][x].g8.?;
                        pixels[y][x].b = raw_pixels[y][x].b8.?;
                        pixels[y][x].a = raw_pixels[y][x].alpha8.?;
                    }
                    else {
                        pixels[y][x].r = val16to8(raw_pixels[y][x].r16.?);
                        pixels[y][x].g = val16to8(raw_pixels[y][x].g16.?);
                        pixels[y][x].b = val16to8(raw_pixels[y][x].b16.?);
                        pixels[y][x].a = val16to8(raw_pixels[y][x].alpha16.?);
                    }
                }
            }
        }
    }
    return pixels;
}

fn val16to8(val: u16) u8 {
    return @intCast(val / 257);
}

pub const Pixel = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8
};
