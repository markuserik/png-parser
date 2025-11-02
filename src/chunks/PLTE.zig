const std = @import("std");
const Chunk = @import("../chunk.zig");

const IHDR = @import("IHDR.zig");

const PLTE = @This();

entries: []Entry,

pub fn parse(chunk: Chunk, color_type: IHDR.ColorType, allocator: std.mem.Allocator) !PLTE {
    if (color_type == .Greyscale or color_type == .Greyscale_with_alpha) return error.PLTEPresentForInvalidColorType;

    var plte: PLTE = undefined;
    var reader: std.io.Reader = std.io.Reader.fixed(chunk.data);

    if (chunk.length % 3 != 0) return error.InvalidPLTELength;

    const num_entries: u32 = chunk.length / 3;
    plte.entries = try allocator.alloc(Entry, num_entries);
    for (0..num_entries) |i| {
        plte.entries[i].r = try reader.takeByte();
        plte.entries[i].g = try reader.takeByte();
        plte.entries[i].b = try reader.takeByte();
    }

    return plte;
}

pub const Entry = struct{
    r: u8,
    g: u8,
    b: u8
};
