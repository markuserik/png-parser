const std = @import("std");
const fs = std.fs;

const Chunk = @import("chunk.zig");

const IHDR = @import("chunks/IHDR.zig");
const PLTE = @import("chunks/PLTE.zig");
const IDAT = @import("chunks/IDAT.zig");

const cHRM = @import("chunks/cHRM.zig");
const gAMA = @import("chunks/gAMA.zig");
const iCCP = @import("chunks/iCCP.zig");
const mDCV = @import("chunks/mDCV.zig");
const cLLI = @import("chunks/cLLI.zig");
const bKGD = @import("chunks/bKGD.zig");
const tIME = @import("chunks/tIME.zig");
const tEXt = @import("chunks/tEXt.zig");

const root = @import("png.zig");
const endian: std.builtin.Endian = .big;

pub const ChunkOrderingError = error{
    IHDRNotFirst,
    MultipleIHDR,
    MultiplePLTE,
    NonSequentialIDAT,
    MultiplecHRM,
    PLTEBeforecHRM,
    MultiplegAMA,
    PLTEBeforegAMA,
    MultipleiCCP,
    PLTEBeforeiCCP,
    IDATBeforeiCCP,
    MultiplemDCV,
    PLTEBeforemDCV,
    IDATBeforemDCV,
    MultiplecLLI,
    PLTEBeforecLLI,
    IDATBeforecLLI,
    MultiplebKGD,
    bKGDBeforePLTE,
    MultipletIME
};

pub const Png = @This();

ihdr: IHDR,
plte: ?PLTE,
idat: IDAT,
chrm: ?cHRM,
gama: ?gAMA,
iccp: ?iCCP,
mdcv: ?mDCV,
clli: ?cLLI,
bkgd: ?bKGD,
time: ?tIME,
text: []tEXt,
arena: std.heap.ArenaAllocator,

pub fn deinit(self: *Png) void {
    self.arena.deinit();
}

const InternalPng = struct {
    ihdr: ?IHDR = null,
    plte: ?PLTE = null,
    idat: ?IDAT = null,
    chrm: ?cHRM = null,
    gama: ?gAMA = null,
    iccp: ?iCCP = null,
    mdcv: ?mDCV = null,
    clli: ?cLLI = null,
    bkgd: ?bKGD = null,
    time: ?tIME = null,
    text: std.ArrayList(tEXt) = std.ArrayList(tEXt){}
};

pub fn parseFileFromPath(file_path: []const u8, allocator: std.mem.Allocator) !Png {
    const file: fs.File = try fs.cwd().openFile(file_path, .{});
    defer file.close();

    return parseFile(file, allocator);
}

pub fn parseFile(file: fs.File, allocator: std.mem.Allocator) !Png {
    const raw_file = try allocator.alloc(u8, (try file.stat()).size);
    _ = try file.read(raw_file);
    defer allocator.free(raw_file);

    return parseRaw(raw_file, allocator);
}

pub fn parseRaw(raw_file: []u8, input_allocator: std.mem.Allocator) !Png {
    var arena: std.heap.ArenaAllocator = .init(input_allocator);
    const allocator = arena.allocator();
    errdefer arena.deinit();

    var png = InternalPng{};

    var reader: std.io.Reader = .fixed(raw_file);

    const signature = try reader.takeInt(u64, endian);
    if (signature != 0x89504E470D0A1A0A) return error.InvalidSignature;

    while (true) {
        const chunk = Chunk.parse(&reader, allocator, endian) catch |err| switch (err) {
            error.EndOfStream => return error.CorruptPNG,
            error.UnrecognizedNonCriticalChunk => if (png.ihdr == null) return ChunkOrderingError.IHDRNotFirst else continue,
            else => return err
        };

        if (png.ihdr == null and chunk.type != .IHDR) return ChunkOrderingError.IHDRNotFirst;

        switch (chunk.type) {
            .IHDR => {
                if (png.ihdr != null) return ChunkOrderingError.MultipleIHDR;
                png.ihdr = try .parse(chunk, endian);
            },
            .PLTE => {
                if (png.plte != null) return ChunkOrderingError.MultiplePLTE;
                png.plte = try .parse(chunk, png.ihdr.?.color_type, allocator);
            },
            .IDAT => {
                if (png.idat != null) return ChunkOrderingError.NonSequentialIDAT;
                var chunk_list: std.ArrayList(Chunk) = try .initCapacity(allocator, 1);
                try chunk_list.append(allocator, chunk);
                while (try Chunk.peekType(&reader) == .IDAT) {
                    try chunk_list.append(allocator, try .parse(&reader, allocator, endian));
                }
                png.idat = try .parse(chunk_list, png.ihdr.?, allocator, endian);
            },
            .IEND => {
                if (reader.peek(1) != error.EndOfStream) return error.DataAfterIEND;
                break;
            },
            .cHRM => {
                if (png.chrm != null) return ChunkOrderingError.MultiplecHRM;
                if (png.plte != null) return ChunkOrderingError.PLTEBeforecHRM;
                png.chrm = try .parse(chunk, endian);
            },
            .gAMA => {
                if (png.gama != null) return ChunkOrderingError.MultiplegAMA;
                if (png.plte != null) return ChunkOrderingError.PLTEBeforegAMA;
                png.gama = try .parse(chunk, endian);
            },
            .iCCP => {
                if (png.iccp != null) return ChunkOrderingError.MultipleiCCP;
                if (png.plte != null) return ChunkOrderingError.PLTEBeforeiCCP;
                if (png.idat != null) return ChunkOrderingError.IDATBeforeiCCP;
                png.iccp = try .parse(chunk, allocator);
            },
            .mDCV => {
                if (png.mdcv != null) return ChunkOrderingError.MultiplemDCV;
                if (png.plte != null) return ChunkOrderingError.PLTEBeforemDCV;
                if (png.idat != null) return ChunkOrderingError.IDATBeforemDCV;
                png.mdcv = try .parse(chunk, endian);
            },
            .cLLI => {
                if (png.clli != null) return ChunkOrderingError.MultiplecLLI;
                if (png.plte != null) return ChunkOrderingError.PLTEBeforecLLI;
                if (png.idat != null) return ChunkOrderingError.IDATBeforecLLI;
                png.clli = try .parse(chunk, endian);
            },
            .bKGD => {
                if (png.bkgd != null) return ChunkOrderingError.MultiplebKGD;
                if (png.plte == null) return ChunkOrderingError.bKGDBeforePLTE;
                png.bkgd = try .parse(chunk, png.ihdr.?.color_type, endian);
            },
            .tIME => {
                if (png.time != null) return ChunkOrderingError.MultipletIME;
                png.time = try .parse(chunk, endian);
            },
            .tEXt => {
                try png.text.append(allocator, try .parse(chunk, allocator));
            }
        }
    }

    if (png.ihdr.?.color_type == .Indexed_color and png.plte == null) return error.NoPLTEForIndexedColor;

    return Png{
        .ihdr = png.ihdr.?,
        .plte = png.plte,
        .idat = png.idat.?,
        .chrm = png.chrm,
        .gama = png.gama,
        .iccp = png.iccp,
        .mdcv = png.mdcv,
        .clli = png.clli,
        .bkgd = png.bkgd,
        .time = png.time,
        .text = try png.text.toOwnedSlice(allocator),
        .arena = arena
    };
}
