const std = @import("std");
const flate = std.compress.flate;
const Chunk = @import("../chunk.zig");

pub const zTXt = @This();

keyword: []u8,
text: []u8,

pub fn parse(chunk: Chunk) !zTXt {
    var reader: std.io.Reader = .fixed(chunk.data);
    const keyword = try reader.takeDelimiterExclusive(0);
    // Discard delimiter
    _ = try reader.takeByte();

    const compression_method = try reader.takeByte();
    if (compression_method != 0) return error.InvalidCompressionMethod;

    var buffer: [flate.max_window_len]u8 = undefined;
    var decompress: flate.Decompress = .init(&reader, .zlib, &buffer);
    const compressed_reader = &decompress.reader;

    const text = try compressed_reader.takeDelimiterExclusive(0);

    return zTXt{
        .keyword = keyword,
        .text = text
    };
}
