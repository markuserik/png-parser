const std = @import("std");
const png = @import("png.zig");

const IHDR = @This();

pub fn parseIHDR(chunk: png.RawChunk) !IHDR {
    _ = chunk;
    return IHDR{
    };
}
