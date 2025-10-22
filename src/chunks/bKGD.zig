const std = @import("std");
const Chunks = @import("../chunks.zig");
const endianness = @import("../png.zig").endianness;

const ColorType = @import("IHDR.zig").ColorType;

pub const bKGD = @This();

greyscale: ?u16 = null,

red: ?u16 = null,
green: ?u16 = null,
blue: ?u16 = null,

palette_index: ?u8 = null,

pub fn parse(chunk: Chunks.RawChunk, color_type: ColorType) !bKGD {
    var reader: std.io.Reader = std.io.Reader.fixed(chunk.data);
    switch (color_type) {
        .Greyscale,
        .Greyscale_with_alpha => {
            return bKGD{
                .greyscale = try reader.takeInt(u16, endianness)
            };
        },
        .Truecolor,
        .Truecolor_with_alpha => {
            return bKGD{
                .red = try reader.takeInt(u16, endianness),
                .green = try reader.takeInt(u16, endianness),
                .blue = try reader.takeInt(u16, endianness)
            };
        },
        .Indexed_color => {
            return bKGD{
                .palette_index = try reader.takeByte()
            };
        }
    }
}
