# png-parser
A zig parsing library for .png files.

# Supported functionality
Currently only images with color type Truecolor and Truecolor_with_alpha.
Only images not relying on any ancilliary chunks are supported.
Also, interlace method Adam7 is not supported.

# Usage
Add it to your project via this command.
```sh
zig fetch --save=png_parser https://github.com/markuserik/png-parser/archive/0.1.0.tar.gz
```

Then add these lines to your build.zig.
```zig
const png_dep = b.dependency("png_parser", .{ .target = target, .optimize = optimize });
exe.root_module.addImport("png_parser", png_dep.module("png_parser"));
```

After that use it like this in your code.
```zig
const std = @import("std");
const png_parser = @import("png_parser");

pub fn main() !void {
    const png: png_parser.Png = try png_parser.parseFileFromPath("images/test.png", std.heap.page_allocator);
    defer png.deinit();

    std.debug.print("Height: {}, Width: {}\n", .{png.height, png.width});
}
```
This way the parser will handle the png logic and provide a struct containing a 2d array of pixels (plus both height and width for convenience), the raw png struct is still available in this struct.

Alternatively, use png_parser.Raw to get a raw struct with all the raw values.
```zig
const std = @import("std");
const png_parser = @import("png_parser").Raw;

pub fn main() !void {
    const png: png_parser.Png = try png_parser.parseFileFromPath("images/test.png", std.heap.page_allocator);
    defer png.deinit();

    std.debug.print("Height: {}, Width: {}\n", .{png.ihdr.height, png.ihdr.width});
}
```
