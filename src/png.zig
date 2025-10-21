const std = @import("std");
const fs = std.fs;

pub const endianness: std.builtin.Endian = std.builtin.Endian.big;

const Raw = @import("raw.zig");
pub const Png = @This();

width: u32,
height: u32,
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
    const raw_png: Raw = try Raw.parseRaw(raw_file);
    
    return Png{
        .width = raw_png.ihdr.width,
        .height = raw_png.ihdr.height,
        .arena = raw_png.arena
    };
}
