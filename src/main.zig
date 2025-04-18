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
    var glxMajor: c_int = undefined;
    var glxMinor: c_int = undefined;

    const glx_ver_ex = glx.glXQueryVersion(@ptrCast(display), &glxMajor, &glxMinor);
    if (0 == glx_ver_ex or (glxMajor == 1 and glxMinor < 3) or (glxMajor < 1)) {
        std.debug.print("Incompatible GLX version. Expected >=1.3 Found {}.{}\n", .{ glxMajor, glxMinor });
        return;
    }
    std.debug.print("{d}::GLX version {d}.{d}\n", .{ glx_ver_ex, glxMajor, glxMinor });
    std.debug.print("GLX Extension: {s}\n\n", .{glx.glXQueryExtensionsString(@ptrCast(display), screen)});

    const root = x.DefaultRootWindow(display);
    const vi = glx.glXChooseVisual(@ptrCast(display), screen, &v_attr) orelse return error.ChooseVisualFailed;
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
}
