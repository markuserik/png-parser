const std = @import("std");
const endianness = @import("png.zig").endianness;

pub const RawChunk = struct {
    length: u32,
    type: ChunkType,
    data: []u8,
    crc: [4]u8
};

pub fn parseChunk(reader: *std.io.Reader) !RawChunk {
    const length: u32 = try reader.takeInt(u32, endianness);
    const raw_type: [4]u8 = (try reader.takeArray(4)).*;
    std.debug.print("Type: {s}\n", .{raw_type});
    return RawChunk{
        .length = length,
        .type = std.meta.stringToEnum(ChunkType, &raw_type) orelse ChunkType.aaaa,
        .data = try reader.take(length),
        .crc = (try reader.takeArray(4)).*
    };
}

pub const ChunkType = enum {
    aaaa,
    IHDR,
    PLTE,
    IEND
};
