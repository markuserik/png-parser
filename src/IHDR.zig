const std = @import("std");

const IHDR = @This();

pub fn parseIHDR(reader: *std.io.Reader, chunk_length: u32, endian: std.builtin.Endian) !IHDR {
    _ = try reader.take(chunk_length);
    _ = try reader.take(4);
    _ = endian;
    return IHDR{
    };
}
