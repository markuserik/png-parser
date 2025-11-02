const std = @import("std");
const Chunk = @import("../chunk.zig");

pub const cHRM = @This();

whitePointX: u32,
whitePointY: u32,
redX: u32,
redY: u32,
greenX: u32,
greenY: u32,
blueX: u32,
blueY: u32,

pub fn parse(chunk: Chunk, endian: std.builtin.Endian) !cHRM {
    var reader: std.io.Reader = std.io.Reader.fixed(chunk.data);
    return cHRM{
        .whitePointX = try reader.takeInt(u32, endian),
        .whitePointY = try reader.takeInt(u32, endian),
        .redX = try reader.takeInt(u32, endian),
        .redY = try reader.takeInt(u32, endian),
        .greenX = try reader.takeInt(u32, endian),
        .greenY = try reader.takeInt(u32, endian),
        .blueX = try reader.takeInt(u32, endian),
        .blueY = try reader.takeInt(u32, endian)
    };
}
