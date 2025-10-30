const std = @import("std");
const flate = std.compress.flate;
const Chunks = @import("../chunks.zig");
const endianness = @import("../png.zig").endianness;

const IHDR = @import("IHDR.zig");

const IDAT = @This();

pixels: [][]Pixel,

pub fn parse(chunks: std.ArrayList(Chunks.Chunk), ihdr: IHDR, allocator: std.mem.Allocator) !IDAT {
    if (ihdr.interlace_method == .Adam7) return error.Adam7InterlaceNotImplemented;

    const single_chunk = chunks.items.len == 1;
    const data: []u8 = if (single_chunk) chunks.items[0].data else try concatChunks(chunks, allocator);
    defer if (!single_chunk) allocator.free(data);

    var raw_reader: std.io.Reader = .fixed(data);
    var buffer: [flate.max_window_len]u8 = undefined;
    var decompress: flate.Decompress = .init(&raw_reader, .zlib, &buffer);
    const reader = &decompress.reader;

    var bytes_per_pixel: u8 = 0;
    switch (ihdr.bit_depth) {
        1, 2, 4 => return error.BitDepthNotImplemented,
        8 => bytes_per_pixel = 1,
        16 => bytes_per_pixel = 2,
        else => unreachable
    }

    bytes_per_pixel *= if (ihdr.color_type == .Truecolor_with_alpha) 4 else if (ihdr.color_type == .Greyscale_with_alpha) 2 else if (ihdr.color_type == .Indexed_color or ihdr.color_type == .Greyscale) 1 else 3;

    const scanline_length: u32 = ihdr.width*bytes_per_pixel;

    var reconstructed_data: [][]u8 = try allocator.alloc([]u8, ihdr.height);
    for (0..reconstructed_data.len) |i| {
        reconstructed_data[i] = try allocator.alloc(u8, scanline_length);
    }
    defer {
        for (0..reconstructed_data.len) |i| {
            allocator.free(reconstructed_data[i]);
        }
        allocator.free(reconstructed_data);
    }

    for (0..ihdr.height) |y| {
        const filter_type: u8 = try reader.takeByte();
        const line: []u8 = try reader.take(scanline_length);
        switch (filter_type) {
            0 => {
                for (0..scanline_length) |x| {
                    reconstructed_data[y][x] = line[x];
                }
            },
            1 => {
                switch (ihdr.bit_depth) {
                    8, 16 => {
                        for (0..bytes_per_pixel) |x| {
                            reconstructed_data[y][x] = line[x];
                        }
                        for (bytes_per_pixel..scanline_length) |x| {
                            reconstructed_data[y][x] = line[x] +% reconstructed_data[y][x-bytes_per_pixel];
                        }
                    },
                    else => return error.BitDepthNotImplemented
                }
            },
            2 => {
                switch (ihdr.bit_depth) {
                    8, 16 => {
                        for (0..scanline_length) |x| {
                            reconstructed_data[y][x] = line[x] +% if (y != 0) reconstructed_data[y-1][x] else 0;
                        }
                    },
                    else => return error.BitDepthNotImplemented
                }
            },
            3 => {
                switch (ihdr.bit_depth) {
                    8, 16 => {
                        for (0..bytes_per_pixel) |x| {
                            reconstructed_data[y][x] = line[x] +% @divFloor(if (y != 0) reconstructed_data[y-1][x] else 0, 2);
                        }
                        for (bytes_per_pixel..scanline_length) |x| {
                            reconstructed_data[y][x] = line[x] +% @as(u8, @intCast(@divFloor(@as(u16, reconstructed_data[y][x-bytes_per_pixel]) + @as(u16, if (y != 0) reconstructed_data[y-1][x] else 0), 2)));
                        }
                    },
                    else => return error.BitDepthNotImplemented
                }
            },
            4 => {
                switch (ihdr.bit_depth) {
                    8, 16 => {
                        for (0..bytes_per_pixel) |x| {
                            reconstructed_data[y][x] = line[x] +% paethPredictor(0, if (y != 0) reconstructed_data[y-1][x] else 0, 0);
                        }
                        for (bytes_per_pixel..scanline_length) |x| {
                            reconstructed_data[y][x] = line[x] +% paethPredictor(reconstructed_data[y][x-bytes_per_pixel], reconstructed_data[y-1][x], reconstructed_data[y-1][x-bytes_per_pixel]);
                        }
                    },
                    else => return error.BitDepthNotImplemented
                }
            },
            else => return error.InvalidFilterType
        }
    }
 
    var pixels: [][]Pixel = try allocator.alloc([]Pixel, ihdr.height);
    for (0..pixels.len) |i| {
        pixels[i] = try allocator.alloc(Pixel, ihdr.width);
        @memset(pixels[i], .{});
    }
    
    for (0..pixels.len) |y| {
        var row_reader: std.io.Reader = .fixed(reconstructed_data[y]);
        for (0..pixels[y].len) |x| {
            switch (ihdr.color_type) {
                .Greyscale => {
                    if (ihdr.bit_depth == 8) {
                        pixels[y][x].greyscale = try row_reader.takeByte();
                    }
                    else if (ihdr.bit_depth == 16) {
                        pixels[y][x].greyscale = try row_reader.takeInt(u16, endianness);
                    }
                    else return error.GreyscaleBitDepthNotImplemented;
                },
                .Truecolor => {
                    if (ihdr.bit_depth == 8) {
                        pixels[y][x].r = try row_reader.takeByte();
                        pixels[y][x].g = try row_reader.takeByte();
                        pixels[y][x].b = try row_reader.takeByte();
                    }
                    else {
                        pixels[y][x].r = try row_reader.takeInt(u16, endianness);
                        pixels[y][x].g = try row_reader.takeInt(u16, endianness);
                        pixels[y][x].b = try row_reader.takeInt(u16, endianness);
                    }
                },
                .Indexed_color => {
                    if (ihdr.bit_depth == 8) {
                        pixels[y][x].index = try row_reader.takeByte();
                    }
                    else return error.IndexedColorBitDepthNotImplemented;
                },
                .Greyscale_with_alpha => {
                    if (ihdr.bit_depth == 8) {
                        pixels[y][x].greyscale = try row_reader.takeByte();
                        pixels[y][x].alpha = try row_reader.takeByte();
                    }
                    else {
                        pixels[y][x].greyscale = try row_reader.takeInt(u16, endianness);
                        pixels[y][x].alpha = try row_reader.takeInt(u16, endianness);
                    }
                },
                .Truecolor_with_alpha => {
                    if (ihdr.bit_depth == 8) {
                        pixels[y][x].r = try row_reader.takeByte();
                        pixels[y][x].g = try row_reader.takeByte();
                        pixels[y][x].b = try row_reader.takeByte();
                        pixels[y][x].alpha = try row_reader.takeByte();
                    }
                    else {
                        pixels[y][x].r = try row_reader.takeInt(u16, endianness);
                        pixels[y][x].g = try row_reader.takeInt(u16, endianness);
                        pixels[y][x].b = try row_reader.takeInt(u16, endianness);
                        pixels[y][x].alpha = try row_reader.takeInt(u16, endianness);
                    }
                }
            }
        }
    }

    return IDAT{
        .pixels = pixels
    };
}

fn paethPredictor(a: i16, b: i16, c: i16) u8 {
    const p = a + b - c;
    const pa = @abs(p - a);
    const pb = @abs(p - b);
    const pc = @abs(p - c);
    const pr: u8 = @intCast(if (pa <= pb and pa <= pc) a
                            else if (pb <= pc) b 
                            else c);
    return pr;
}

fn concatChunks(chunks: std.ArrayList(Chunks.Chunk), allocator: std.mem.Allocator) ![]u8 {
    var data_len: u32 = 0;
    for (chunks.items) |chunk| data_len += chunk.length;

    const data: []u8 = try allocator.alloc(u8, data_len);
    var data_cursor: u32 = 0;
    for (chunks.items) |chunk| {
        for (0..chunk.length) |i| {
            data[data_cursor+i] = chunk.data[i];
        }
        data_cursor += chunk.length;
    }
    return data;
}

pub const Pixel = struct {
    r: ?u16 = null,
    g: ?u16 = null,
    b: ?u16 = null,

    greyscale: ?u16 = null,

    alpha: ?u16 = null,

    index: ?u8 = null
};
