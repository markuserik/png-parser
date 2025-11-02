const std = @import("std");
const Chunk = @import("../chunk.zig");

pub const gAMA = @This();

gamma: u32,

pub fn parse(chunk: Chunk, endian: std.builtin.Endian) !gAMA {
    var reader: std.io.Reader = .fixed(chunk.data);
    return gAMA{
        .gamma = try reader.takeInt(u32, endian)
    };
}
