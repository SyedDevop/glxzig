const std = @import("std");
const glx = @cImport({
    @cInclude("GL/glx.h");
    @cInclude("GL/glu.h");
});
const x = @cImport({
    @cInclude("X11/Xlib.h");
});

var v_attr = [_]c_int{
    glx.GLX_RGBA,
    glx.GLX_DEPTH_SIZE,
    24,
    glx.GLX_DOUBLEBUFFER,
    glx.None,
};

const visual_attribs = [_]c_int{
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
    glx.GLX_DOUBLEBUFFER,  glx.True,
    //glx.GLX_SAMPLE_BUFFERS  , 1,
    //glx.GLX_SAMPLES         , 4,
    glx.None,
};

fn drawa_quad() void {
    glx.glClearColor(1.0, 1.0, 1.0, 1.0);
    glx.glClear(glx.GL_COLOR_BUFFER_BIT | glx.GL_DEPTH_BUFFER_BIT);

    glx.glMatrixMode(glx.GL_PROJECTION);
    glx.glLoadIdentity();
    glx.glOrtho(-1.0, 1.0, -1.0, 1.0, 1.0, 20.0);

    glx.glMatrixMode(glx.GL_MODELVIEW);
    glx.glLoadIdentity();
    glx.gluLookAt(0.0, 0.0, 10.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0);

    glx.glBegin(glx.GL_QUADS);
    glx.glColor3f(1.0, 0.0, 0.0);
    glx.glVertex3f(-0.75, -0.75, 0.0);
    glx.glColor3f(0.0, 1.0, 0.0);
    glx.glVertex3f(0.75, -0.75, 0.0);
    glx.glColor3f(0.0, 0.0, 1.0);
    glx.glVertex3f(0.75, 0.75, 0.0);
    glx.glColor3f(1.0, 1.0, 0.0);
    glx.glVertex3f(-0.75, 0.75, 0.0);
    glx.glEnd();
}

pub fn main() !void {
    const display = x.XOpenDisplay(null) orelse return error.XOpenDisplayFailed;
    const screen = x.XDefaultScreen(display);
    const root = x.DefaultRootWindow(display);
    var glxMajor: c_int = undefined;
    var glxMinor: c_int = undefined;

    const glx_ver_ex = glx.glXQueryVersion(@ptrCast(display), &glxMajor, &glxMinor);
    if (0 == glx_ver_ex or (glxMajor == 1 and glxMinor < 3) or (glxMajor < 1)) {
        std.debug.print("Incompatible GLX version. Expected >=1.3 Found {}.{}\n", .{ glxMajor, glxMinor });
        return;
    }
    std.debug.print("{d}::GLX version {d}.{d}\n", .{ glx_ver_ex, glxMajor, glxMinor });
    std.debug.print("GLX Extension: {s}\n\n", .{glx.glXQueryExtensionsString(@ptrCast(display), screen)});
    var fbcount: c_int = undefined;

    const fbc = glx.glXChooseFBConfig(@ptrCast(display), screen, &visual_attribs, &fbcount) orelse return error.FrameBufferConfigFailed;
    defer _ = x.XFree(@ptrCast(fbc));
    std.debug.print("Found {d} matching FB configs.\n", .{fbcount});
    std.debug.print("Getting XVisualInfos\n", .{});
    var best_fbc: c_int = -1;
    var worst_fbc: c_int = -1;
    var best_num_samp: c_int = -1;
    var worst_num_samp: c_int = 999;
    for (0..@intCast(fbcount)) |i| {
        const vi = glx.glXGetVisualFromFBConfig(@ptrCast(display), fbc[i]);
        defer _ = x.XFree(vi);
        if (vi != null) {
            var samp_buf: c_int = undefined;
            var samples: c_int = undefined;
            _ = glx.glXGetFBConfigAttrib(@ptrCast(display), fbc[i], glx.GLX_SAMPLE_BUFFERS, &samp_buf);
            _ = glx.glXGetFBConfigAttrib(@ptrCast(display), fbc[i], glx.GLX_SAMPLES, &samples);
            if (best_fbc < 0 or samp_buf != 0 and samples > best_num_samp) {
                best_fbc = @intCast(i);
                best_num_samp = samples;
            }
            if (worst_fbc < 0 or samp_buf == 0 or samples < worst_num_samp) {
                worst_fbc = @intCast(i);
                worst_num_samp = samples;
            }
        }
    }
    const bestfbc = fbc[@intCast(best_fbc)];
    const vi = glx.glXGetVisualFromFBConfig(@ptrCast(display), bestfbc);
    defer _ = x.XFree(vi);
    std.debug.print("Visual {d} selected\n", .{vi.*.visualid});

    const cmap = x.XCreateColormap(display, root, @ptrCast(vi.*.visual), x.AllocNone);
    var swap: x.XSetWindowAttributes = .{ .colormap = cmap, .event_mask = x.ExposureMask | x.KeyPressMask };
    const win = x.XCreateWindow(
        display,
        root,
        0,
        0,
        800,
        600,
        0,
        vi.*.depth,
        x.InputOutput,
        @ptrCast(vi.*.visual),
        x.CWColormap | x.CWEventMask,
        &swap,
    );
    _ = x.XMapWindow(display, win);
    var wmDeleteMess = x.XInternAtom(display, "WM_DELETE_WINDOW", 0);
    _ = x.XSetWMProtocols(display, win, &wmDeleteMess, 1);
    _ = x.XStoreName(display, win, "Hello Dirrrr");
    const glc = glx.glXCreateContext(@ptrCast(display), vi, null, glx.GL_TRUE);
    _ = glx.glXMakeCurrent(@ptrCast(display), win, glc);
    glx.glEnable(glx.GL_DEPTH_TEST);
    glx.glClearColor(1.0, 0.0, 0.0, 1.0);

    std.debug.print("GL Version  {s}\n", .{glx.glGetString(glx.GL_VERSION)});
    std.debug.print("GL Vender   {s}\n", .{glx.glGetString(glx.GL_VENDOR)});
    std.debug.print("GL Renderer {s}\n", .{glx.glGetString(glx.GL_RENDERER)});

    var xev: x.XEvent = undefined;
    var runing = true;
    while (runing) {
        var gwa: x.XWindowAttributes = undefined;
        _ = x.XGetWindowAttributes(display, win, &gwa);
        glx.glViewport(0, 0, gwa.width, gwa.height);
        glx.glClear(glx.GL_COLOR_BUFFER_BIT);

        glx.glMatrixMode(glx.GL_PROJECTION);
        glx.glLoadIdentity();
        glx.glOrtho(-1.0, 1.0, -1.0, 1.0, 1.0, 20.0);

        drawa_quad();

        glx.glXSwapBuffers(@ptrCast(display), win);
        _ = x.XNextEvent(display, &xev);

        switch (xev.type) {
            x.Expose => {},
            x.KeyPress => runing = false,
            x.ClientMessage => {
                runing = !(xev.xclient.data.l[0] == wmDeleteMess);
            },
            else => {},
        }
    }
    if (!runing) {
        _ = glx.glXMakeCurrent(@ptrCast(display), x.None, null);
        glx.glXDestroyContext(@ptrCast(display), glc);
        _ = x.XDestroyWindow(display, win);
        _ = x.XCloseDisplay(display);
    }
    return;
}
