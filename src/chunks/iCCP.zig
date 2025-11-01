const std = @import("std");
const flate = std.compress.flate;
const Chunks = @import("../chunks.zig");

const iCCP = @This();

profile_name: []u8,
profile: []u8,

pub fn parse(chunk: Chunks.Chunk, allocator: std.mem.Allocator) !iCCP {
    var raw_reader: std.io.Reader = .fixed(chunk.data);
    var profile_name: std.ArrayList(u8) = try .initCapacity(allocator, 1);
    while (raw_reader.takeByte()) |byte| {
        if (byte == 0) break;
        try profile_name.append(allocator, byte);
    }
    else |err| return err;

    // 0 = Deflate
    // Only method in the specification as of now
    if (try raw_reader.takeByte() != 0) return error.UnrecognizedCompressionMethod;

    var buffer: [flate.max_window_len]u8 = undefined;
    var decompress: flate.Decompress = .init(&raw_reader, .zlib, &buffer);
    const reader = &decompress.reader;

    var profile: std.ArrayList(u8) = try .initCapacity(allocator, 1);
    while (reader.takeByte()) |byte| {
        try profile.append(allocator, byte);
    }
    else |err| switch (err) {
        error.EndOfStream => {},
        else => return err
    }

    return iCCP{
        .profile_name = try profile_name.toOwnedSlice(allocator),
        .profile = try profile.toOwnedSlice(allocator)
    };
}
