const std = @import("std");
const Chunk = @import("../chunk.zig");

pub const cLLI = @This();

maxCLL: u32,
maxFALL: u32,

pub fn parse(chunk: Chunk, endian: std.builtin.Endian) !cLLI {
    var reader: std.io.Reader = .fixed(chunk.data);
    return cLLI{
        .maxCLL = try reader.takeInt(u32, endian),
        .maxFALL = try reader.takeInt(u32, endian)
    };
}
