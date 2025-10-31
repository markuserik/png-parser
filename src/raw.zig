const std = @import("std");
const fs = std.fs;

const Chunks = @import("chunks.zig");
const ChunkType = Chunks.ChunkType;

const IHDR = @import("chunks/IHDR.zig");
const PLTE = @import("chunks/PLTE.zig");
const IDAT = @import("chunks/IDAT.zig");

const cHRM = @import("chunks/cHRM.zig");
const gAMA = @import("chunks/gAMA.zig");
const bKGD = @import("chunks/bKGD.zig");
const tIME = @import("chunks/tIME.zig");
const tEXt = @import("chunks/tEXt.zig");

const root = @import("png.zig");
const endianness = root.endianness;

pub const Png = @This();

ihdr: IHDR,
plte: ?PLTE,
idat: IDAT,
chrm: ?cHRM,
gama: ?gAMA,
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
    const raw_file: []u8 = try allocator.alloc(u8, (try file.stat()).size);
    _ = try file.read(raw_file);
    defer allocator.free(raw_file);

    return parseRaw(raw_file, allocator);
}

pub fn parseRaw(raw_file: []u8, input_allocator: std.mem.Allocator) !Png {
    var arena = std.heap.ArenaAllocator.init(input_allocator);
    const allocator: std.mem.Allocator = arena.allocator();
    errdefer arena.deinit();

    var png: InternalPng = InternalPng{};

    var reader: std.io.Reader = std.io.Reader.fixed(raw_file);

    const signature: u64 = try reader.takeInt(u64, endianness);
    if (signature != 0x89504E470D0A1A0A) return error.InvalidSignature;

    while (true) {
        const chunk: Chunks.Chunk = Chunks.parse(&reader, allocator) catch |err| switch (err) {
            error.EndOfStream => return error.CorruptPNG,
            error.UnrecognizedNonCriticalChunk => continue,
            else => return err
        };

        if (png.ihdr == null and chunk.type != .IHDR) return error.IHDRNotFirst;

        switch (chunk.type) {
            .IHDR => {
                if (png.ihdr != null) return error.MultipleIHDR;
                png.ihdr = try IHDR.parse(chunk);
            },
            .PLTE => {
                if (png.plte != null) return error.MultiplePLTE;
                png.plte = try PLTE.parse(chunk, png.ihdr.?.color_type, allocator);
            },
            .IDAT => {
                if (png.idat != null) return error.NonSequentialIDAT;
                var chunk_list: std.ArrayList(Chunks.Chunk) = try std.ArrayList(Chunks.Chunk).initCapacity(allocator, 1);
                try chunk_list.append(allocator, chunk);
                while (try Chunks.peekType(&reader) == .IDAT) {
                    try chunk_list.append(allocator, try Chunks.parse(&reader, allocator));
                }
                png.idat = try IDAT.parse(chunk_list, png.ihdr.?, allocator);
            },
            .IEND => {
                if (reader.peek(1) != error.EndOfStream) return error.DataAfterIEND;
                break;
            },
            .cHRM => {
                if (png.chrm != null) return error.MultiplecHRM;
                if (png.plte != null) return error.PLTEBeforecHRM;
                png.chrm = try cHRM.parse(chunk);
            },
            .gAMA => {
                if (png.gama != null) return error.MultiplegAMA;
                if (png.plte != null) return error.PLTEBeforegAMA;
                png.gama = try gAMA.parse(chunk);
            },
            .bKGD => {
                if (png.bkgd != null) return error.MultiplebKGD;
                if (png.plte == null) return error.bKGDBeforePLTE;
                png.bkgd = try bKGD.parse(chunk, png.ihdr.?.color_type);
            },
            .tIME => {
                if (png.time != null) return error.MultipletIME;
                png.time = try tIME.parse(chunk);
            },
            .tEXt => {
                try png.text.append(allocator, try tEXt.parse(chunk, allocator));
            }
        }
    }

    return Png{
        .ihdr = png.ihdr.?,
        .plte = png.plte,
        .idat = png.idat.?,
        .chrm = png.chrm,
        .gama = png.gama,
        .bkgd = png.bkgd,
        .time = png.time,
        .text = try png.text.toOwnedSlice(allocator),
        .arena = arena
    };
}
