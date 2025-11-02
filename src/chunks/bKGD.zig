const std = @import("std");
const Chunk = @import("../chunk.zig");

const ColorType = @import("IHDR.zig").ColorType;

pub const bKGD = @This();

greyscale: ?u16 = null,

red: ?u16 = null,
green: ?u16 = null,
blue: ?u16 = null,

palette_index: ?u8 = null,

pub fn parse(chunk: Chunk, color_type: ColorType, endian: std.builtin.Endian) !bKGD {
    var reader: std.io.Reader = std.io.Reader.fixed(chunk.data);
    switch (color_type) {
        .Greyscale,
        .Greyscale_with_alpha => {
            return bKGD{
                .greyscale = try reader.takeInt(u16, endian)
            };
        },
        .Truecolor,
        .Truecolor_with_alpha => {
            return bKGD{
                .red = try reader.takeInt(u16, endian),
                .green = try reader.takeInt(u16, endian),
                .blue = try reader.takeInt(u16, endian)
            };
        },
        .Indexed_color => {
            return bKGD{
                .palette_index = try reader.takeByte()
            };
        }
    }
}
