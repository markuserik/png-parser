const std = @import("std");
const fs = std.fs;

const Chunks = @import("chunks.zig");
const ChunkType = Chunks.ChunkType;

const IHDR = @import("IHDR.zig");
const PLTE = @import("PLTE.zig");

pub const endianness: std.builtin.Endian = std.builtin.Endian.big;

pub const Png = @This();

ihdr: IHDR,
plte: ?PLTE,
arena: std.heap.ArenaAllocator,

pub fn deinit(self: *Png) void {
    self.arena.deinit();
}

pub fn parseFileFromPath(file_path: []const u8) !Png {
    const file: fs.File = try fs.cwd().openFile(file_path, .{});
    defer file.close();

    return parseFile(file);
}

pub fn parseFile(file: fs.File) !Png {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator: std.mem.Allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const raw_file: []u8 = try allocator.alloc(u8, (try file.stat()).size);
    _ = try file.read(raw_file);
    defer allocator.free(raw_file);

    return parseRaw(raw_file);
}

pub fn parseRaw(raw_file: []u8) !Png {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator: std.mem.Allocator = arena.allocator();
    errdefer arena.deinit();

    var png: *Png = try allocator.create(Png);
    png.arena = arena;

    var reader: std.io.Reader = std.io.Reader.fixed(raw_file);

    const signature: u64 = try reader.takeInt(u64, endianness);
    if (signature != 0x89504E470D0A1A0A) return error.CorruptPNG;

    while (true) {
        const chunk: Chunks.RawChunk = Chunks.parseChunk(&reader, allocator) catch |err| switch (err) {
            error.EndOfStream => return error.CorruptPNG,
            else => return err
        };

        switch (chunk.type) {
           .IHDR => png.ihdr = try IHDR.parse(chunk),
           .PLTE => png.plte = try PLTE.parse(chunk, allocator),
           .IEND => break,
           .aaaa => {}
        }
    }
    
    return png.*;
}
