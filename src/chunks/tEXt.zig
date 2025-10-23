const std = @import("std");
const Chunks = @import("../chunks.zig");

pub const tEXt = @This();

keyword: []u8,
text: []u8,

pub fn parse(chunk: Chunks.Chunk, allocator: std.mem.Allocator) !tEXt {
    var reader: std.io.Reader = std.io.Reader.fixed(chunk.data);
    const keyword: []u8 = try reader.takeDelimiterExclusive(0);
    const text: []u8 = try reader.take(chunk.length - keyword.len - 1);
    const keyword_alloc = try allocator.alloc(u8, keyword.len);
    const text_alloc = try allocator.alloc(u8, text.len);
    @memcpy(keyword_alloc, keyword);
    @memcpy(text_alloc, text);
    return tEXt{
        .keyword = keyword_alloc,
        .text = text_alloc
    };
}
