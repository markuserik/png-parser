# png-decoder
A zig decoding library for .png files.

# Supported functionality
All color types are supported, however, only bit counts of 8 and 16 are
supported.
Although some ancilliary chunks are parsed with their values available in the raw png struct, only images not relying on any ancilliary chunks are supported.
Also, interlace method Adam7 is not supported.

# Usage
Add it to your project via this command.
```sh
zig fetch --save=png_decoder https://github.com/markuserik/png-decoder/archive/0.1.0.tar.gz
```

Then add these lines to your build.zig.
```zig
const png_dep = b.dependency("png_decoder", .{ .target = target, .optimize = optimize });
exe.root_module.addImport("png_decoder", png_dep.module("png_decoder"));
```

After that use it like this in your code.
```zig
const std = @import("std");
const png_decoder = @import("png_decoder");

pub fn main() !void {
    const png: png_decoder.Png = try png_decoder.parseFileFromPath("images/test.png", std.heap.page_allocator);
    defer png.deinit();

    std.debug.print("Height: {}, Width: {}\n", .{png.height, png.width});
}
```
This way the decoder will handle the png logic and provide a struct containing a 2d array of pixels (plus both height and width for convenience), the raw png struct is still available in this struct.

Alternatively, use png_decoder.Raw to get a raw struct with all the raw values.
```zig
const std = @import("std");
const png_decoder = @import("png_decoder").Raw;

pub fn main() !void {
    const png: png_decoder.Png = try png_decoder.parseFileFromPath("images/test.png", std.heap.page_allocator);
    defer png.deinit();

    std.debug.print("Height: {}, Width: {}\n", .{png.ihdr.height, png.ihdr.width});
}
```
