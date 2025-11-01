const std = @import("std");

pub const Chunk = struct {
    length: u32,
    type: ChunkType,
    data: []u8,
    crc: u32
};

pub const ChunkType = enum {
    IHDR,
    PLTE,
    IDAT,
    IEND,

    cHRM,
    gAMA,
    iCCP,
    mDCV,
    cLLI,
    bKGD,
    tIME,
    tEXt
};

pub fn parse(reader: *std.io.Reader, allocator: std.mem.Allocator, endian: std.builtin.Endian) !Chunk {
    const length: u32 = try reader.takeInt(u32, endian);
    if (length >= 2_147_483_648) return error.InvalidChunkDataLength;
    const raw_type: [4]u8 = (try reader.takeArray(4)).*;
    const chunk_type: ?ChunkType = std.meta.stringToEnum(ChunkType, &raw_type);
    const data: []u8 = if (length != 0) try reader.take(length) else "";
    const crc: u32 = try reader.takeInt(u32, endian);

    if (chunk_type == null) {
        if (raw_type[0] >= 65 and raw_type[0] <= 90) return error.UnrecognizedCriticalChunk;
        return error.UnrecognizedNonCriticalChunk;
    }
    
    const crc_data: []u8 = try allocator.alloc(u8, data.len + 4);
    defer allocator.free(crc_data);
    inline for (0..4) |i| {
        crc_data[i] = raw_type[i];
    }
    for (0..data.len) |i| {
        crc_data[i+4] = data[i];
    }

    if (!verifyCRC(crc_data, crc)) return error.InvalidChunkCRC;

    return Chunk{
        .length = length,
        .type = chunk_type.?,
        .data = data,
        .crc = crc
    };
}

pub fn peekType(reader: *std.io.Reader) !?ChunkType {
    // The four first bytes of a chunk are the length so we must get the first 8
    // and only check the last four of the array
    const raw_type: [8]u8 = (try reader.peekArray(8)).*;
    return std.meta.stringToEnum(ChunkType, raw_type[4..8]);
}

const crc_table: [256]u32 = createCRCTable();

fn createCRCTable() [256]u32 {
    var table: [256]u32 = undefined;
    @setEvalBranchQuota(2305);
    for (0..256) |i| {
        var c: u32 = i;
        for (0..8) |_| {
            c = if ((c & 1) > 0) 0xedb88320 ^ (c >> 1) else c >> 1;
        }
        table[i] = c;
    }
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
