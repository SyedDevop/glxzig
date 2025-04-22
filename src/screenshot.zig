// Compile and run
// zig build-exe ./src/screenshot.zig -lc -lX11 && ./screenshot

const std = @import("std");
const c = @cImport({
    @cInclude("X11/Xlib.h");
    @cInclude("X11/Xutil.h");
});

/// Represents a generic pixel buffer that can be either a pointer to a constant
/// array of 8-bit values (`u8`) or 32-bit values (`u32`).
const Pixels = union(enum) {
    /// Pointer to an array of constant 8-bit pixel values.
    u8: [*]const u8,

    /// Pointer to an array of constant 32-bit pixel values.
    u32: [*]const u32,
};

fn savePixelsAsPPM(pixels: Pixels, width: usize, height: usize, filepath: [:0]const u8) !void {
    var file = try std.fs.cwd().createFileZ(filepath, .{});
    defer file.close();

    var buff_writer = std.io.bufferedWriter(file.writer());
    const writer = buff_writer.writer();
    try writer.print("P6\n{} {}\n255\n", .{ width, height });
    switch (pixels) {
        .u8 => |p| {
            for (0..(width * height)) |i| {
                const c1: u8 = p[i * 4 + 0];
                const c2: u8 = p[i * 4 + 1];
                const c3: u8 = p[i * 4 + 2];
                try writer.writeAll(&[_]u8{ c3, c2, c1 });
            }
        },
        .u32 => |p| {
            for (0..(width * height)) |i| {
                const pixel = p[i];
                const c1: u8 = @intCast(pixel & 0xFF);
                const c2: u8 = @intCast((pixel >> 8) & 0xFF);
                const c3: u8 = @intCast((pixel >> 16) & 0xFF);
                try writer.writeAll(&[_]u8{ c3, c2, c1 });
            }
        },
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
    const pixel_ptr_u8: [*]const u8 = @alignCast(@ptrCast(data));

    const width: usize = @intCast(img.*.width);
    const height: usize = @intCast(img.*.height);
    var timer = try std.time.Timer.start();
    try savePixelsAsPPM(.{ .u32 = pixel_ptr }, width, height, "screen-u32.ppm");
    var end = timer.read() / 1000_000;
    std.debug.print("Save time for screen-u32: {d:.2} ms\n", .{end});

    timer.reset();
    try savePixelsAsPPM(.{ .u8 = pixel_ptr_u8 }, width, height, "screen-u8.ppm");
    end = timer.read() / 1000_000;
    std.debug.print("Save time for screen-u8: {d:.2} ms\n", .{end});
}
