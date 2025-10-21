const std = @import("std");
const endianness = @import("png.zig").endianness;

pub const RawChunk = struct {
    length: u32,
    type: ChunkType,
    data: []u8,
    crc: u32
};

pub const ChunkType = enum {
    aaaa,
    IHDR,
    PLTE,
    IEND
};

pub fn parseChunk(reader: *std.io.Reader, allocator: std.mem.Allocator) !RawChunk {
    const length: u32 = try reader.takeInt(u32, endianness);
    const raw_type: [4]u8 = (try reader.takeArray(4)).*;
    const data: []u8 = try reader.take(length);
    const crc: u32 = try reader.takeInt(u32, endianness);
    
    const crc_data: []u8 = try allocator.alloc(u8, data.len + 4);
    defer allocator.free(crc_data);
    for (0..4) |i| {
        crc_data[i] = raw_type[i];
    }
    for (0..data.len) |i| {
        crc_data[i+4] = data[i];
    }

    if (!verifyCRC(crc_data, crc)) {
        return error.InvalidCRC;
    }

    return RawChunk{
        .length = length,
        .type = std.meta.stringToEnum(ChunkType, &raw_type) orelse ChunkType.aaaa,
        .data = data,
        .crc = crc
    };
}

const crc_table: [256]u32 = createCRCTable();

fn createCRCTable() [256]u32 {
    var table: [256]u32 = undefined;
    @setEvalBranchQuota(10000);
    for (0..256) |i| {
        var c: u32 = i;
        for (0..8) |_| {
            if ((c & 1) > 0) {
                c = 0xedb88320 ^ (c >> 1);
            }
            else {
                c = c >> 1;
            }
        }
        table[i] = c;
    }
    @setEvalBranchQuota(1000);
    return table;
}

fn verifyCRC(data: []u8, crc: u32) bool {
    const new_crc: u32 = createCRC(data);
    return crc == new_crc;
}


fn createCRC(data: []u8) u32 {
    var crc: u32 = 0xFFFFFFFF;
    for (0..data.len) |i| {
        crc = crc_table[(crc ^ data[i]) & 0xFF] ^ (crc >> 8);
    }
    return crc ^ 0xFFFFFFFF;
}
