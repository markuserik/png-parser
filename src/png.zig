const std = @import("std");
const fs = std.fs;

pub const Png = struct {
};

pub fn parseFileFromPath(file_path: []const u8) !Png {
    const file: fs.File = fs.cwd().openFile(file_path, .{});
    defer file.close();

    return parseFile(file);
}

pub fn parseFile(file: fs.File) !Png {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator: std.mem.Allocator = gpa.allocator();
    defer gpa.deinit();

    const raw_file: []u8 = try allocator.alloc(u8, (try file.stat()).size);
    _ = try file.read(raw_file);
    defer allocator.free(raw_file);

    return parseRaw(raw_file);
}

pub fn parseRaw(raw_file: []u8) !Png {
    _ = raw_file;
    return Png{};
}
