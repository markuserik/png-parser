const std = @import("std");
const Chunk = @import("../chunk.zig");

pub const tIME = @This();

year: u16,
month: u8,
day: u8,
hour: u8,
minute: u8,
second: u8,

pub fn parse(chunk: Chunk, endian: std.builtin.Endian) !tIME {
    var reader: std.io.Reader = .fixed(chunk.data);
    const year = try reader.takeInt(u16, endian);
    const month = try reader.takeByte();
    if (month == 0 or month > 12) return error.InvalidMonth;

    const day = try reader.takeByte();
    if (day == 0 or day > 31) return error.InvalidDay;

    const hour = try reader.takeByte();
    if (hour > 23) return error.InvalidHour;

    const minute = try reader.takeByte();
    if (minute > 59) return error.InvalidMinute;

    const second = try reader.takeByte();
    if (second > 60) return error.InvalidSecond;

    return tIME{
        .year = year,
        .month = month,
        .day = day,
        .hour = hour,
        .minute = minute,
        .second = second
    };
}
