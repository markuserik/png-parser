const std = @import("std");
const Chunks = @import("chunks.zig");
const endianness = @import("png.zig").endianness;

const IHDR = @This();

width: u32,
height: u32,
bit_depth: u8,
color_type: ColorType,
compression_method: u8,
filter_method: u8,
interlace_method: u8,

pub const ColorType = enum(u8){
    Greyscale = 0,
    Truecolor = 2,
    Indexed_color = 3,
    Greyscale_with_alpha = 4,
    Truecolor_with_alpha = 6
};

pub fn parse(chunk: Chunks.RawChunk) !IHDR {
    var reader: std.io.Reader = std.io.Reader.fixed(chunk.data);
    const width: u32 = try reader.takeInt(u32, endianness);
    if (width > 2_147_483_648 or width == 0) return error.InvalidWidth;

    const height: u32 = try reader.takeInt(u32, endianness);
    if (height > 2_147_483_648 or height == 0) return error.InvalidHeight;

    const bit_depth: u8 = try reader.takeByte();

    const color_type: ColorType = std.enums.fromInt(ColorType, try reader.takeByte()) orelse return error.InvalidColorType;
    if (!try validateBitDepth(bit_depth, color_type)) return error.InvalidBitDepthColorTypeCombination;

    const compression_method: u8 = try reader.takeByte();

    const filter_method: u8 = try reader.takeByte();

    const interlace_method: u8 = try reader.takeByte();

    return IHDR{
        .width = width,
        .height = height,
        .bit_depth = bit_depth,
        .color_type = color_type,
        .compression_method = compression_method,
        .filter_method = filter_method,
        .interlace_method = interlace_method
    };
}

fn validateBitDepth(bit_depth: u8, color_type: ColorType) !bool {
    if ((bit_depth % 2 != 0 and bit_depth != 1) or bit_depth > 16) return error.InvalidBitDepth;
    switch (color_type) {
        // 1, 2, 4, 8, 16
        .Greyscale => {
            if (bit_depth % 2 != 0 and bit_depth != 1) return false;
        },
        // 1, 2, 4, 8
        .Indexed_color => {
            if (bit_depth % 2 != 0 and bit_depth != 1 and bit_depth > 8) return false;
        },
        // 8, 16
        .Truecolor,
        .Greyscale_with_alpha,
        .Truecolor_with_alpha => {
            if (bit_depth % 8 != 0) return false;
        },
    }
    return true;
}
