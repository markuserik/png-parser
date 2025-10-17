const std = @import("std");
const endianness = @import("png.zig").endianness;

pub const RawChunk = struct {
    length: u32,
    type: Chunk_type,
    data: []u8,
    crc: [4]u8
};

pub fn parseChunk(reader: *std.io.Reader) !RawChunk {
    const length: u32 = try reader.takeInt(u32, endianness);
    const raw_type: [4]u8 = (try reader.takeArray(4)).*;
    return RawChunk{
        .length = length,
        .type = std.meta.stringToEnum(Chunk_type, &raw_type) orelse { std.debug.print("Unsupported chunk type: {s}\n", .{raw_type}); return error.UnsupportedChunkType;},
        .data = try reader.take(length),
        .crc = (try reader.takeArray(4)).*
    };
}

pub const Chunk_type = enum {
    IHDR
};
