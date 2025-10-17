const std = @import("std");
const fs = std.fs;

const Chunk_type = @import("chunk_types.zig").Chunk_type;
const IHDR = @import("IHDR.zig");

const endianness: std.builtin.Endian = std.builtin.Endian.big;

pub const Png = struct {
    ihdr: IHDR,
    arena: std.heap.ArenaAllocator,

    pub fn deinit(self: *Png) void {
        self.arena.deinit();
    }
};

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

    var png: *Png = try allocator.create(Png);
    png.arena = arena;

    var reader: std.io.Reader = std.io.Reader.fixed(raw_file);

    // Discard identifier
    _ = try reader.take(8);

    while (true) {
        const chunk_length: u32 = try reader.takeInt(u32, endianness);
        const chunk_type_raw: [4]u8 = (try reader.takeArray(4)).*;
        const chunk_type: Chunk_type = std.meta.stringToEnum(Chunk_type, &chunk_type_raw) orelse { std.debug.print("Unsupported chunk type: {s}\n", .{chunk_type_raw}); return error.UnsupportedChunkType;};

        switch (chunk_type) {
            Chunk_type.IHDR => { png.ihdr = try IHDR.parseIHDR(&reader, chunk_length, endianness); },
        }
    }
    
    return png;
}
