const std = @import("std");
const core = @import("mach-core");
const gpu = core.gpu;
const assets = @import("assets");

const zgui = @import("zgui").MachImgui(core);

pub const App = @This();

pub var content_scale: [2]f32 = undefined;
pub var window_size: [2]f32 = undefined;
pub var framebuffer_size: [2]f32 = undefined;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
// pub const mach_core_options = core.ComptimeOptions{
//     .use_wgpu = false,
//     .use_dgpu = true,
// };

title_timer: core.Timer,
pipeline: *gpu.RenderPipeline,

pub fn init(app: *App) !void {
    const allocator = gpa.allocator();

    try core.init(.{});

    const shader_module = core.device.createShaderModuleWGSL("shader.wgsl", @embedFile("shader.wgsl"));
    defer shader_module.release();

    // Fragment state
    const blend = gpu.BlendState{};
    const color_target = gpu.ColorTargetState{
        .format = core.descriptor.format,
        .blend = &blend,
        .write_mask = gpu.ColorWriteMaskFlags.all,
    };
    const fragment = gpu.FragmentState.init(.{
        .module = shader_module,
        .entry_point = "frag_main",
        .targets = &.{color_target},
    });
    const pipeline_descriptor = gpu.RenderPipeline.Descriptor{
        .fragment = &fragment,
        .vertex = gpu.VertexState{
            .module = shader_module,
            .entry_point = "vertex_main",
        },
    };
    const pipeline = core.device.createRenderPipeline(&pipeline_descriptor);

    app.* = .{ .title_timer = try core.Timer.start(), .pipeline = pipeline };

    zgui.init(allocator);
    zgui.mach_backend.init(core.device, core.descriptor.format, .{});

    // TODO: Make font size scalable and not hard coded: Look at Pixi
    const font_size = 18.0;
    _ = zgui.io.addFontFromFile(assets.fonts.roboto_medium.path, font_size);

    const style = zgui.getStyle();
    style.window_min_size = .{ 100.0, 100.0 };
    style.window_border_size = 8.0;
    style.scrollbar_size = 6.0;
}

pub fn deinit(app: *App) void {
    zgui.mach_backend.deinit();
    zgui.deinit();

    app.pipeline.release();

    core.deinit();
    _ = gpa.detectLeaks();
}

pub fn update(app: *App) !bool {
    zgui.mach_backend.newFrame();

    const descriptor = core.descriptor;
    window_size = .{ @floatFromInt(core.size().width), @floatFromInt(core.size().height) };
    framebuffer_size = .{ @floatFromInt(descriptor.width), @floatFromInt(descriptor.height) };
    content_scale = .{
        framebuffer_size[0] / window_size[0],
        framebuffer_size[1] / window_size[1],
    };

    var iter = core.pollEvents();
    while (iter.next()) |event| {
        switch (event) {
            .close => return true,
            else => {},
        }

        zgui.mach_backend.passEvent(event, content_scale);
    }

    render_content();

    if (core.swap_chain.getCurrentTextureView()) |back_buffer_view| {
        defer back_buffer_view.release();

        const zgui_commands = commands: {
            const encoder = core.device.createCommandEncoder(null);
            defer encoder.release();

            const background: gpu.Color = .{
                .r = @floatCast(42),
                .g = @floatCast(44),
                .b = @floatCast(54),
                .a = 1.0,
            };

            // Gui pass.
            {
                const color_attachment = gpu.RenderPassColorAttachment{
                    .view = back_buffer_view,
                    .clear_value = background,
                    .load_op = .clear,
                    .store_op = .store,
                };

                const render_pass_info = gpu.RenderPassDescriptor.init(.{
                    .color_attachments = &.{color_attachment},
                });
                const pass = encoder.beginRenderPass(&render_pass_info);
                pass.setPipeline(app.pipeline);
                pass.draw(3, 1, 0, 0);

                zgui.mach_backend.draw(pass);
                pass.end();
                pass.release();
            }

            break :commands encoder.finish(null);
        };
        defer zgui_commands.release();

        core.queue.submit(&.{zgui_commands});
        core.swap_chain.present();
    }

    // update the window title every second
    if (app.title_timer.read() >= 1.0) {
        app.title_timer.reset();
        try core.printTitle("Triangle [ {d}fps ] [ Input {d}hz ]", .{
            core.frameRate(),
            core.inputRate(),
        });
    }

    return false;
}

pub fn render_content() void {
    if (!zgui.begin("Debug", .{})) {
        zgui.end();
        return;
    }

    if (zgui.collapsingHeader("Record", .{})) {
        if (zgui.button("Create Image", .{ .w = 200.0 })) {
            // ctx.capture_screenshot = true;
            std.debug.print("Creating PNG of viewport\n", .{});
        }
    }

    zgui.end();
}
