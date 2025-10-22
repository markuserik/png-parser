const std = @import("std");
const fs = std.fs;

const Chunks = @import("chunks.zig");
const ChunkType = Chunks.ChunkType;

const IHDR = @import("chunks/IHDR.zig");
const PLTE = @import("chunks/PLTE.zig");

const root = @import("png.zig");
const endianness = root.endianness;

pub const Png = @This();

ihdr: IHDR,
plte: ?PLTE,
arena: std.heap.ArenaAllocator,

pub fn deinit(self: *Png) void {
    self.arena.deinit();
}

const InternalPng = struct {
    ihdr: ?IHDR = null,
    plte: ?PLTE = null
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

pub fn parseRaw(raw_file: []u8, passed_allocator: std.mem.Allocator) !Png {
    var arena = std.heap.ArenaAllocator.init(passed_allocator);
    const allocator: std.mem.Allocator = arena.allocator();
    errdefer arena.deinit();

    var png: InternalPng = InternalPng{};

    var reader: std.io.Reader = std.io.Reader.fixed(raw_file);

    const signature: u64 = try reader.takeInt(u64, endianness);
    if (signature != 0x89504E470D0A1A0A) return error.InvalidSignature;

    while (true) {
        const chunk: Chunks.RawChunk = Chunks.parseChunk(&reader, allocator) catch |err| switch (err) {
            error.EndOfStream => return error.CorruptPNG,
            else => return err
        };

        switch (chunk.type) {
           .IHDR => {
               if (png.ihdr != null) return error.MultipleIHDR;
               png.ihdr = try IHDR.parse(chunk);
           },
           .PLTE => {
               if (png.plte != null) return error.MultiplePLTE;
               png.plte = try PLTE.parse(chunk, (png.ihdr orelse return error.IHDRNotFirst).color_type, allocator);
           },
           .IEND => break,
           .aaaa => {}
        }
    }
    
    return Png{
        .ihdr = png.ihdr.?,
        .plte = png.plte,
        .arena = arena
    };
}
