const std = @import("std");
const glfw = @import("zglfw");
const zopengl = @import("zopengl");

const zigimg = @import("zigimg");
const zm = @import("zmath");

const Shader = @import("shader.zig").Shader;

// const vertex_shader_source = @embedFile("./vert.glsl");
// const fragment_shader_source = @embedFile("./frag.glsl");

const o_vertices = &[_]f32{
    // position // color // texture
    0.5, 0.5, 0.0, 1.0, 0.0, 0.0, 1.0, 1.0, // top right
    0.5, -0.5, 0.0, 0.0, 1.0, 0.0, 1.0, 0.0, // bottom right
    -0.5, -0.5, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, // bottom left
    -0.5, 0.5, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, // top left
};

const cube = @import("cube.zig");
const vertices = cube.vertices;

const indices = &[_]c_uint{
    0, 1, 3,
    1, 2, 3,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    try glfw.init();
    defer glfw.terminate();

    glfw.windowHint(.context_version_major, 3);
    glfw.windowHint(.context_version_minor, 3);
    glfw.windowHint(.opengl_profile, .opengl_core_profile);
    const win = try glfw.Window.create(500, 500, "HE HE", null);
    defer win.destroy();

    glfw.makeContextCurrent(win);
    _ = win.setFramebufferSizeCallback(framebuffer_size_callback);

    try zopengl.loadCoreProfile(glfw.getProcAddress, 3, 3);
    const gl = zopengl.bindings;

    const shader = try Shader.new("./src/vert.glsl", "./src/frag.glsl", allocator);

    var vao: c_uint = undefined;
    gl.genVertexArrays(1, &vao);

    var vbo: c_uint = undefined;
    gl.genBuffers(1, &vbo);

    var ebo: c_uint = undefined;
    gl.genBuffers(1, &ebo);

    gl.bindVertexArray(vao);

    gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
    gl.bufferData(gl.ARRAY_BUFFER, vertices.len * @sizeOf(f32), vertices, gl.STATIC_DRAW);

    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo);
    gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, indices.len * @bitSizeOf(c_uint), indices, gl.STATIC_DRAW);

    // position attribute
    gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 5 * @sizeOf(f32), null);
    gl.enableVertexAttribArray(0);
    // color attribute
    // gl.vertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), @ptrFromInt(3 * @sizeOf(f32)));
    // gl.enableVertexAttribArray(1);
    // texture attribute
    gl.vertexAttribPointer(2, 2, gl.FLOAT, gl.FALSE, 5 * @sizeOf(f32), @ptrFromInt(3 * @sizeOf(f32)));
    gl.enableVertexAttribArray(2);

    gl.bindVertexArray(0);
    gl.bindBuffer(gl.ARRAY_BUFFER, 0);
    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0);

    // const colorUniformLocation = gl.getUniformLocation(shader_program, "testColor");

    var img = try zigimg.Image.fromFilePath(allocator, "wall.jpg");
    defer img.deinit();

    const texture_width: c_int = @intCast(img.width);
    const texture_height: c_int = @intCast(img.height);
    const texture_data = img.rawBytes();

    var texture: c_uint = undefined;
    gl.genTextures(1, &texture);
    gl.bindTexture(gl.TEXTURE_2D, texture);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);

    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGB, texture_width, texture_height, 0, gl.RGB, gl.UNSIGNED_BYTE, @ptrCast(texture_data));
    gl.generateMipmap(gl.TEXTURE_2D);

    var img2 = try zigimg.Image.fromFilePath(allocator, "awesomeface.png");
    defer img2.deinit();
    try img2.flipVertically();

    const t2_w: c_int = @intCast(img2.width);
    const t2_h: c_int = @intCast(img2.height);
    const t2_d = img2.rawBytes();

    var t2: c_uint = undefined;
    gl.genTextures(1, &t2);
    gl.bindTexture(gl.TEXTURE_2D, t2);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);

    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, t2_w, t2_h, 0, gl.RGBA, gl.UNSIGNED_BYTE, @ptrCast(t2_d));
    gl.generateMipmap(gl.TEXTURE_2D);

    var trans = zm.identity();

    // const r = zm.rotationZ(1.570796);
    // const s = zm.scaling(0.5, 0.5, 0.5);
    // trans = zm.mul(trans, r);
    // trans = zm.mul(trans, s);

    const window_size = win.getSize();

    const projection = zm.perspectiveFovLhGl(0.7853, @as(f32, @floatFromInt(window_size[0])) / @as(f32, @floatFromInt(window_size[1])), 0.1, 100.0);
    // const projection = zm.perspectiveFovLhGl(99.0, @as(f32, @floatFromInt(window_size[0])) / @as(f32, @floatFromInt(window_size[1])), 0.1, 100.0);

    gl.enable(gl.DEPTH_TEST);
    while (!win.shouldClose()) {
        processInput(win);

        gl.clearColor(0.2, 0.3, 0.3, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        // gl.polygonMode(gl.FRONT_AND_BACK, gl.LINE);

        const time_val = glfw.getTime();
        const green_val = std.math.sin(time_val) / 2.0 + 0.5;

        // var view = zm.identity();
        // view = zm.mul(view, zm.translation(0.0, 0.0, 10.0));
        const radius = 10.0;
        const camX = @sin(time_val / 10.0) * radius;
        const camZ = @cos(time_val / 10.0) * radius;
        const view = zm.lookAtLh(.{ @floatCast(camX), 0.0, @floatCast(camZ), 0.0 }, .{ 0.0, 0.0, 0.0, 0.0 }, .{ 0.0, 1.0, 0.0, 0.0 });

        // gl.useProgram(shader_program);
        // gl.uniform3f(colorUniformLocation, 0.0, @floatCast(green_val), 0.0);
        shader.use();
        shader.setFloat3("testColor", 0.0, @floatCast(green_val), 0.0);
        shader.setInt("texture1", 0);
        shader.setInt("texture2", 1);
        // const rot = zm.rotationZ(@floatCast(glfw.getTime() / 1000.0));
        const rot = zm.rotationZ(0.005);
        trans = zm.mul(rot, trans);

        // trans = zm.mul(trans, rot);
        const transLoc = gl.getUniformLocation(shader.id, "transform");
        gl.uniformMatrix4fv(transLoc, 1, gl.FALSE, &zm.matToArr(trans));
        const viewLoc = gl.getUniformLocation(shader.id, "view");
        gl.uniformMatrix4fv(viewLoc, 1, gl.FALSE, &zm.matToArr(view));
        const projLoc = gl.getUniformLocation(shader.id, "projection");
        gl.uniformMatrix4fv(projLoc, 1, gl.FALSE, &zm.matToArr(projection));

        gl.activeTexture(gl.TEXTURE0);
        gl.bindTexture(gl.TEXTURE_2D, texture);
        gl.activeTexture(gl.TEXTURE1);
        gl.bindTexture(gl.TEXTURE_2D, t2);
        gl.bindVertexArray(vao);
        // gl.drawArrays(gl.TRIANGLES, 0, 3);
        // gl.drawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, null);
        for (cube.cube_positions) |cpos| {
            var model = zm.identity();
            // model = zm.mul(model, zm.rotationX(-55.0));
            model = zm.mul(model, zm.rotationX(@floatCast(-1.0 * time_val)));
            model = zm.mul(model, zm.rotationY(@floatCast(-1.0 * time_val)));
            model = zm.mul(model, zm.translation(cpos[0], cpos[1], cpos[2]));
            // model = zm.mul(model, zm.rotationX(@floatCast(1.0 * time_val)));
            // model = zm.mul(model, zm.rotationY(@floatCast(1.0 * time_val)));
            // model = zm.mul(model, zm.translation(0.0, -1.0, 0.0));
            const modelLoc = gl.getUniformLocation(shader.id, "model");
            gl.uniformMatrix4fv(modelLoc, 1, gl.FALSE, &zm.matToArr(model));

            gl.drawArrays(gl.TRIANGLES, 0, 36);
        }
        gl.bindVertexArray(0);

        // gl.polygonMode(gl.FRONT_AND_BACK, gl.FILL);

        glfw.pollEvents();
        win.swapBuffers();
        // gl.clearBufferfv(gl.COLOR, 0, &[_]f32{ 0.2, 0.6, 0.4, 1.0 });
    }
}

fn framebuffer_size_callback(window: *glfw.Window, width: c_int, height: c_int) callconv(.c) void {
    _ = window;
    const gl = zopengl.bindings;
    gl.viewport(0, 0, width, height);
}

fn processInput(window: *glfw.Window) void {
    if (window.getKey(.escape) == .press) {
        window.setShouldClose(true);
    }
}
