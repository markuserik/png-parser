# png-parser
A zig parsing library for .png files.

# Usage
Add it to your project via this command, as there is no release yet this will
add the repository at the latest commit which can potentially be unstable.
```sh
zig fetch --save=png_parser git+https://github.com/markuserik/png-parser
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
    const png: png_parser.Png = try png_parser.parseFileFromPath("images/test.png");
    defer png.deinit();

    std.debug.print("Height: {}, Width: {}\n", .{png.height, png.width});
}
```
This way the parser will handle the png logic and provide a struct containing a 2d array of pixels (plus both height and width for convenience), the raw png values are still available in this struct.

Alternatively, use png_parser.Raw to get a raw struct with all the raw values.
```zig
const std = @import("std");
const png_parser = @import("png_parser").Raw;

pub fn main() !void {
    const png: png_parser.Png = try png_parser.parseFileFromPath("images/test.png");
    defer png.deinit();

    std.debug.print("Height: {}, Width: {}\n", .{png.ihdr.height, png.ihdr.width});
}
```
