// Compile and run
// zig build-exe ./src/screenshot.zig -lc -lX11 && ./screenshot

const std = @import("std");
const c = @cImport({
    @cInclude("X11/Xlib.h");
    @cInclude("X11/Xutil.h");
});

fn savePixelsAsPPM(pixels: [*]const u32, width: usize, height: usize, filepath: [:0]const u8) !void {
    var file = try std.fs.cwd().createFileZ(filepath, .{});
    defer file.close();

    var buff_writer = std.io.bufferedWriter(file.writer());
    const writer = buff_writer.writer();
    try writer.print("P6\n{} {}\n255\n", .{ width, height });

    for (0..(width * height)) |i| {
        const pixel = pixels[i];
        const c1: u8 = @intCast(pixel & 0xFF);
        const c2: u8 = @intCast((pixel >> 8) & 0xFF);
        const c3: u8 = @intCast((pixel >> 16) & 0xFF);
        try writer.writeAll(&[_]u8{ c3, c2, c1 });
    }
    try buff_writer.flush();
    try file.sync();
}
pub fn main() !void {
    const dpy = c.XOpenDisplay(null) orelse return error.XOpenDisplayFailed;
    defer _ = c.XCloseDisplay(dpy);
    const screen = c.XDefaultScreen(dpy);
    const root = c.RootWindow(dpy, screen);

    var attributes: c.XWindowAttributes = undefined;
    _ = c.XGetWindowAttributes(dpy, root, &attributes);
    const img = c.XGetImage(
        dpy,
        root,
        0,
        0,
        @intCast(attributes.width),
        @intCast(attributes.height),
        c.AllPlanes,
        c.ZPixmap,
    ) orelse return error.GetImageFailed;
    defer {
        if (img.*.f.destroy_image) |distory| _ = distory(img);
    }
    std.debug.print("Width: {d}\n", .{img.*.width});
    std.debug.print("Height: {d}\n", .{img.*.height});
    std.debug.print("BPP: {d}\n", .{img.*.bits_per_pixel});
    if (img.*.bits_per_pixel != 32) return error.UnsupportedBPP;

    const data = img.*.data;
    const pixel_ptr: [*]const u32 = @alignCast(@ptrCast(data));

    const width: usize = @intCast(img.*.width);
    const height: usize = @intCast(img.*.height);
    try savePixelsAsPPM(pixel_ptr, width, height, "screen.ppm");
}
