const std = @import("std");
const glx = @cImport({
    @cInclude("GL/glx.h");
});
const x = @cImport({
    @cInclude("X11/Xlib.h");
});

const visual_attribs = [_:0]c_int{
    glx.GLX_X_RENDERABLE,  glx.True,
    glx.GLX_DRAWABLE_TYPE, glx.GLX_WINDOW_BIT,
    glx.GLX_RENDER_TYPE,   glx.GLX_RGBA_BIT,
    glx.GLX_X_VISUAL_TYPE, glx.GLX_TRUE_COLOR,
    glx.GLX_RED_SIZE,      8,
    glx.GLX_GREEN_SIZE,    8,
    glx.GLX_BLUE_SIZE,     8,
    glx.GLX_ALPHA_SIZE,    8,
    glx.GLX_DEPTH_SIZE,    24,
    glx.GLX_STENCIL_SIZE,  8,
    glx.GLX_DOUBLEBUFFER,  x.True,
    //glx / GLX_SAMPLE_BUFFERS, 1,
    //glx / GLX_SAMPLES,        4,
    glx.None,
};

pub fn main() !void {
    const display = x.XOpenDisplay(null) orelse return error.XOpenDisplayFailed;
    const screen = x.XDefaultScreen(display);
    var glxMajor: c_int = undefined;
    var glxMinor: c_int = undefined;

    const glx_ver_ex = glx.glXQueryVersion(@ptrCast(display), &glxMajor, &glxMinor);
    if (0 == glx_ver_ex or (glxMajor == 1 and glxMinor < 3) or (glxMajor < 1)) {
        std.debug.print("Incompatible GLX version. Expected >=1.3 Found {}.{}\n", .{ glxMajor, glxMinor });
        return;
    }

    var fbcount: c_int = 0;
    const fbc = glx.glXChooseFBConfig(
        @ptrCast(display),
        screen,
        &visual_attribs,
        &fbcount,
    ) orelse return error.GlxFdcFailed;
    defer _ = glx.XFree(@ptrCast(fbc));
    std.debug.print("{d}::GLX version {d}.{d}\n", .{ glx_ver_ex, glxMajor, glxMinor });
}
