const std = @import("std");
const Chunk = @import("../chunk.zig");

pub const MasteringDisplayColorPrimaryChromaticities = struct {
    rx: u16,
    ry: u16,
    gx: u16,
    gy: u16,
    bx: u16,
    by: u16
};

pub const MasteringDisplayWhitePointChromaticities = struct {
    x: u16,
    y: u16
};

pub const mDCV = @This();

mastering_display_color_primary_chromaticities: MasteringDisplayColorPrimaryChromaticities,
mastering_display_white_point_chromaticities: MasteringDisplayWhitePointChromaticities,
mastering_display_maximum_luminance: u32,
mastering_display_minimum_luminance: u32,

pub fn parse(chunk: Chunk, endian: std.builtin.Endian) !mDCV {
    var reader: std.io.Reader = .fixed(chunk.data);

    var mastering_display_color_primary_chromaticities: MasteringDisplayColorPrimaryChromaticities = undefined;
    mastering_display_color_primary_chromaticities.rx = try reader.takeInt(u16, endian);
    mastering_display_color_primary_chromaticities.ry = try reader.takeInt(u16, endian);
    mastering_display_color_primary_chromaticities.gx = try reader.takeInt(u16, endian);
    mastering_display_color_primary_chromaticities.gy = try reader.takeInt(u16, endian);
    mastering_display_color_primary_chromaticities.bx = try reader.takeInt(u16, endian);
    mastering_display_color_primary_chromaticities.by = try reader.takeInt(u16, endian);

    var mastering_display_white_point_chromaticities: MasteringDisplayWhitePointChromaticities = undefined;
    mastering_display_white_point_chromaticities.x = try reader.takeInt(u16, endian);
    mastering_display_white_point_chromaticities.y = try reader.takeInt(u16, endian);

    const mastering_display_maximum_luminance = try reader.takeInt(u32, endian);
    const mastering_display_minimum_luminance = try reader.takeInt(u32, endian);

    return mDCV{
        .mastering_display_color_primary_chromaticities = mastering_display_color_primary_chromaticities,
        .mastering_display_white_point_chromaticities = mastering_display_white_point_chromaticities,
        .mastering_display_maximum_luminance = mastering_display_maximum_luminance,
        .mastering_display_minimum_luminance = mastering_display_minimum_luminance
    };
}
