const std = @import("std");
const c = @cImport({
    @cInclude("GL/glx.h");
    @cInclude("GL/glu.h");
    @cInclude("X11/Xlib.h");
});

var v_attr = [_]c_int{
    c.GLX_RGBA,
    c.GLX_DEPTH_SIZE,
    24,
    c.GLX_DOUBLEBUFFER,
    c.None,
};

const visual_attribs = [_]c_int{
    c.GLX_X_RENDERABLE,  c.True,
    c.GLX_DRAWABLE_TYPE, c.GLX_WINDOW_BIT,
    c.GLX_RENDER_TYPE,   c.GLX_RGBA_BIT,
    c.GLX_X_VISUAL_TYPE, c.GLX_TRUE_COLOR,
    c.GLX_RED_SIZE,      8,
    c.GLX_GREEN_SIZE,    8,
    c.GLX_BLUE_SIZE,     8,
    c.GLX_ALPHA_SIZE,    8,
    c.GLX_DEPTH_SIZE,    24,
    c.GLX_STENCIL_SIZE,  8,
    c.GLX_DOUBLEBUFFER,  c.True,
    //c.GLX_SAMPLE_BUFFERS  , 1,
    //c.GLX_SAMPLES         , 4,
    c.None,
};

fn drawa_quad() void {
    c.glClearColor(1.0, 1.0, 1.0, 1.0);
    c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT);

    c.glMatrixMode(c.GL_PROJECTION);
    c.glLoadIdentity();
    c.glOrtho(-1.0, 1.0, -1.0, 1.0, 1.0, 20.0);

    c.glMatrixMode(c.GL_MODELVIEW);
    c.glLoadIdentity();
    c.gluLookAt(0.0, 0.0, 10.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0);

    c.glBegin(c.GL_QUADS);
    c.glColor3f(1.0, 0.0, 0.0);
    c.glVertex3f(-0.75, -0.75, 0.0);
    c.glColor3f(0.0, 1.0, 0.0);
    c.glVertex3f(0.75, -0.75, 0.0);
    c.glColor3f(0.0, 0.0, 1.0);
    c.glVertex3f(0.75, 0.75, 0.0);
    c.glColor3f(1.0, 1.0, 0.0);
    c.glVertex3f(-0.75, 0.75, 0.0);
    c.glEnd();
}

pub fn main() !void {
    const display = c.XOpenDisplay(null) orelse return error.XOpenDisplayFailed;
    const screen = c.XDefaultScreen(display);
    const root = c.DefaultRootWindow(display);
    var glxMajor: c_int = undefined;
    var glxMinor: c_int = undefined;

    const glx_ver_ex = c.glXQueryVersion((display), &glxMajor, &glxMinor);
    if (0 == glx_ver_ex or (glxMajor == 1 and glxMinor < 3) or (glxMajor < 1)) {
        std.debug.print("Incompatible GLX version. Expected >=1.3 Found {}.{}\n", .{ glxMajor, glxMinor });
        return;
    }
    std.debug.print("{d}::GLX version {d}.{d}\n", .{ glx_ver_ex, glxMajor, glxMinor });
    std.debug.print("GLX Extension: {s}\n\n", .{c.glXQueryExtensionsString((display), screen)});
    var fbcount: c_int = undefined;

    const fbc = c.glXChooseFBConfig((display), screen, &visual_attribs, &fbcount) orelse return error.FrameBufferConfigFailed;
    defer _ = c.XFree(@ptrCast(fbc));
    std.debug.print("Found {d} matching FB configs.\n", .{fbcount});
    std.debug.print("Getting XVisualInfos\n", .{});
    var best_fbc: c_int = -1;
    var worst_fbc: c_int = -1;
    var best_num_samp: c_int = -1;
    var worst_num_samp: c_int = 999;
    for (0..@intCast(fbcount)) |i| {
        const vi = c.glXGetVisualFromFBConfig((display), fbc[i]);
        defer _ = c.XFree(vi);
        if (vi != null) {
            var samp_buf: c_int = undefined;
            var samples: c_int = undefined;
            _ = c.glXGetFBConfigAttrib((display), fbc[i], c.GLX_SAMPLE_BUFFERS, &samp_buf);
            _ = c.glXGetFBConfigAttrib((display), fbc[i], c.GLX_SAMPLES, &samples);
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
    const vi = c.glXGetVisualFromFBConfig((display), bestfbc);
    defer _ = c.XFree(vi);
    std.debug.print("Visual {d} selected\n", .{vi.*.visualid});

    const cmap = c.XCreateColormap(display, root, (vi.*.visual), c.AllocNone);
    var swap: c.XSetWindowAttributes = .{ .colormap = cmap, .event_mask = c.ExposureMask | c.KeyPressMask };
    const win = c.XCreateWindow(
        display,
        root,
        0,
        0,
        800,
        600,
        0,
        vi.*.depth,
        c.InputOutput,
        (vi.*.visual),
        c.CWColormap | c.CWEventMask,
        &swap,
    );
    _ = c.XMapWindow(display, win);
    var wmDeleteMess = c.XInternAtom(display, "WM_DELETE_WINDOW", 0);
    _ = c.XSetWMProtocols(display, win, &wmDeleteMess, 1);
    _ = c.XStoreName(display, win, "Hello Dirrrr");
    const glc = c.glXCreateContext((display), vi, null, c.GL_TRUE);
    _ = c.glXMakeCurrent((display), win, glc);

    c.glEnable(c.GL_DEPTH_TEST);
    c.glEnable(c.GL_DEBUG_OUTPUT);

    c.glClearColor(1.0, 0.0, 0.0, 1.0);

    std.debug.print("GL Version  {s}\n", .{c.glGetString(c.GL_VERSION)});
    std.debug.print("GL Vender   {s}\n", .{c.glGetString(c.GL_VENDOR)});
    std.debug.print("GL Renderer {s}\n", .{c.glGetString(c.GL_RENDERER)});

    var xev: c.XEvent = undefined;
    var runing = true;
    while (runing) {
        var gwa: c.XWindowAttributes = undefined;
        _ = c.XGetWindowAttributes(display, win, &gwa);
        c.glViewport(0, 0, gwa.width, gwa.height);
        c.glClear(c.GL_COLOR_BUFFER_BIT);

        c.glMatrixMode(c.GL_PROJECTION);
        c.glLoadIdentity();
        c.glOrtho(-1.0, 1.0, -1.0, 1.0, 1.0, 20.0);

        drawa_quad();

        c.glXSwapBuffers((display), win);
        _ = c.XNextEvent(display, &xev);

        switch (xev.type) {
            c.Expose => {},
            c.KeyPress => runing = false,
            c.ClientMessage => {
                runing = !(xev.xclient.data.l[0] == wmDeleteMess);
            },
            else => {},
        }
    }
    if (!runing) {
        _ = c.glXMakeCurrent((display), c.None, null);
        c.glXDestroyContext((display), glc);
        _ = c.XDestroyWindow(display, win);
        _ = c.XCloseDisplay(display);
    }
    return;
}
