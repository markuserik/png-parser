const std = @import("std");
const Chunks = @import("chunks.zig");
const endianness = @import("png.zig").endianness;

const IHDR = @This();

width: u32,
height: u32,
bit_depth: u8,
color_type: u8,
compression_method: u8,
filter_method: u8,
interlace_method: u8,

pub fn parseIHDR(chunk: Chunks.RawChunk) !IHDR {
    var reader: std.io.Reader = std.io.Reader.fixed(chunk.data);
    return IHDR{
        .width = try reader.takeInt(u32, endianness),
        .height = try reader.takeInt(u32, endianness),
        .bit_depth = try reader.takeByte(),
        .color_type = try reader.takeByte(),
        .compression_method = try reader.takeByte(),
        .filter_method = try reader.takeByte(),
        .interlace_method = try reader.takeByte()
    };
}
