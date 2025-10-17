const std = @import("std");
const Chunks = @import("chunks.zig");
const endianness = @import("png.zig").endianness;

const PLTE = @This();

entries: []Entry,

pub fn parsePLTE(chunk: Chunks.RawChunk, allocator: std.mem.Allocator) !PLTE {
    var plte: *PLTE = try allocator.create(PLTE);
    var reader: std.io.Reader = std.io.Reader.fixed(chunk.data);
    if (chunk.length % 3 != 0) {
        std.log.err("Corrupt PLTE chunk, length not divisible by 3\n", .{});
        return error.CorruptPLTE;
    }
    const num_entries: u32 = chunk.length / 3;
    plte.entries = try allocator.alloc(Entry, num_entries);
    for (0..num_entries) |i| {
        plte.entries[i].r = try reader.takeByte();
        plte.entries[i].g = try reader.takeByte();
        plte.entries[i].b = try reader.takeByte();
    }

    return plte.*;
}

pub const Entry = struct{
    r: u8,
    g: u8,
    b: u8
};
