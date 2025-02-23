const std = @import("std");
const c = @cImport({
    @cInclude("wayland-server.h");
    @cInclude("wayland-server-protocol.h");
});

// Swift bridge function declarations
extern fn create_metal_window() ?*anyopaque;
extern fn draw_surface(window: *anyopaque, buffer: [*]const u8, width: i32, height: i32) void;
extern fn destroy_metal_window(window: *anyopaque) void;

// Compositor state
const MacCompositor = struct {
    display: *c.wl_display,
    event_loop: *c.wl_event_loop,
    surfaces: std.ArrayList(*MacSurface),
    metal_window: *anyopaque,
    allocator: std.mem.Allocator,
    xdg_shell: ?*c.wl_global,
    seat: ?*c.wl_global,
    outputs: std.ArrayList(*Output),

    pub fn init(allocator: std.mem.Allocator) !*MacCompositor {
        const self = try allocator.create(MacCompositor);

        // Create the Metal window using our Swift bridge
        const metal_window = create_metal_window() orelse {
            allocator.destroy(self);
            return error.MetalWindowCreationFailed;
        };

        self.* = .{
            .display = undefined,
            .event_loop = undefined,
            .surfaces = std.ArrayList(*MacSurface).init(allocator),
            .metal_window = metal_window,
            .allocator = allocator,
        };
        return self;
    }

    pub fn deinit(self: *MacCompositor) void {
        destroy_metal_window(self.metal_window);

        for (self.surfaces.items) |surface| {
            surface.deinit();
            self.allocator.destroy(surface);
        }
        self.surfaces.deinit();
        self.allocator.destroy(self);
    }
};

// Surface state
const MacSurface = struct {
    surface_resource: *c.wl_resource,
    buffer_resource: ?*c.wl_resource,
    width: i32,
    height: i32,
    data: ?[]u8,
    compositor: *MacCompositor,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, compositor: *MacCompositor) !*MacSurface {
        const self = try allocator.create(MacSurface);
        self.* = .{
            .surface_resource = undefined,
            .buffer_resource = null,
            .width = 0,
            .height = 0,
            .data = null,
            .compositor = compositor,
            .allocator = allocator,
        };
        return self;
    }

    pub fn deinit(self: *MacSurface) void {
        if (self.data) |data| {
            self.allocator.free(data);
        }
    }

    pub fn updateBuffer(self: *MacSurface) void {
        if (self.buffer_resource) |buffer_resource| {
            const shm_buffer = c.wl_shm_buffer_get(buffer_resource);
            if (shm_buffer != null) {
                const width = c.wl_shm_buffer_get_width(shm_buffer);
                const height = c.wl_shm_buffer_get_height(shm_buffer);
                const stride = c.wl_shm_buffer_get_stride(shm_buffer);
                const data = c.wl_shm_buffer_get_data(shm_buffer);

                // Update buffer data
                self.width = width;
                self.height = height;

                // Draw using Metal through our Swift bridge
                draw_surface(self.compositor.metal_window, data, width, height);
            }
        }
    }
};

// Wayland interface implementations
fn surfaceDestroy(client: *c.wl_client, resource: *c.wl_resource) callconv(.C) void {
    _ = client;
    c.wl_resource_destroy(resource);
}

fn surfaceAttach(client: *c.wl_client, resource: *c.wl_resource, buffer: ?*c.wl_resource, x: i32, y: i32) callconv(.C) void {
    _ = client;
    _ = x;
    _ = y;
    const surface = @ptrCast(*MacSurface, @alignCast(@alignOf(*MacSurface), c.wl_resource_get_user_data(resource)));
    surface.buffer_resource = buffer;
}

fn surfaceCommit(client: *c.wl_client, resource: *c.wl_resource) callconv(.C) void {
    _ = client;
    const surface = @ptrCast(*MacSurface, @alignCast(@alignOf(*MacSurface), c.wl_resource_get_user_data(resource)));
    surface.updateBuffer();
}

const surface_interface = c.wl_surface_interface{
    .destroy = surfaceDestroy,
    .attach = surfaceAttach,
    .commit = surfaceCommit,
    // Add other required interface functions
};

// XDG Shell implementation
const Output = struct {
    output_resource: *c.wl_resource,
    compositor: *MacCompositor,
    x: i32,
    y: i32,
    width: i32,
    height: i32,
    scale: i32,

    pub fn init(allocator: std.mem.Allocator, compositor: *MacCompositor) !*Output {
        const self = try allocator.create(Output);
        self.* = .{
            .output_resource = undefined,
            .compositor = compositor,
            .x = 0,
            .y = 0,
            .width = 800,
            .height = 600,
            .scale = 1,
        };
        return self;
    }
};

fn xdgSurfaceGetTopLevel(client: *c.wl_client, resource: *c.wl_resource, id: u32) callconv(.C) void {
    const xdg_surface = @ptrCast(*XdgSurface, @alignCast(@alignOf(*XdgSurface), c.wl_resource_get_user_data(resource)));

    const toplevel_resource = c.wl_resource_create(client, &c.xdg_toplevel_interface, c.wl_resource_get_version(resource), id) orelse {
        c.wl_client_post_no_memory(client);
        return;
    };

    xdg_surface.role = .toplevel;
    xdg_surface.toplevel = toplevel_resource;

    c.wl_resource_set_implementation(toplevel_resource, &xdg_toplevel_interface, xdg_surface, null);
}

fn xdgSurfaceDestroy(client: *c.wl_client, resource: *c.wl_resource) callconv(.C) void {
    _ = client;
    c.wl_resource_destroy(resource);
}

const xdg_surface_interface = c.xdg_surface_interface{
    .destroy = xdgSurfaceDestroy,
    .get_toplevel = xdgSurfaceGetTopLevel,
    .get_popup = null, // Implement if needed
};

// Seat implementation for input handling
fn seatGetPointer(client: *c.wl_client, resource: *c.wl_resource, id: u32) callconv(.C) void {
    const seat = @ptrCast(*Seat, @alignCast(@alignOf(*Seat), c.wl_resource_get_user_data(resource)));

    const pointer_resource = c.wl_resource_create(client, &c.wl_pointer_interface, c.wl_resource_get_version(resource), id) orelse {
        c.wl_client_post_no_memory(client);
        return;
    };

    c.wl_resource_set_implementation(pointer_resource, &pointer_interface, seat, null);
}

fn seatGetKeyboard(client: *c.wl_client, resource: *c.wl_resource, id: u32) callconv(.C) void {
    const seat = @ptrCast(*Seat, @alignCast(@alignOf(*Seat), c.wl_resource_get_user_data(resource)));

    const keyboard_resource = c.wl_resource_create(client, &c.wl_keyboard_interface, c.wl_resource_get_version(resource), id) orelse {
        c.wl_client_post_no_memory(client);
        return;
    };

    c.wl_resource_set_implementation(keyboard_resource, &keyboard_interface, seat, null);
}

const seat_interface = c.wl_seat_interface{
    .get_pointer = seatGetPointer,
    .get_keyboard = seatGetKeyboard,
    .get_touch = null, // Implement if needed
};

fn bindSeat(client: *c.wl_client, data: ?*anyopaque, version: u32, id: u32) callconv(.C) void {
    const compositor = @ptrCast(*MacCompositor, @alignCast(@alignOf(*MacCompositor), data.?));

    const resource = c.wl_resource_create(client, &c.wl_seat_interface, version, id) orelse {
        c.wl_client_post_no_memory(client);
        return;
    };

    c.wl_resource_set_implementation(resource, &seat_interface, compositor, null);
}

pub fn main() !void {
    // Setup allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create compositor
    var compositor = try MacCompositor.init(allocator);
    defer compositor.deinit();

    // Initialize Wayland display
    compositor.display = c.wl_display_create() orelse {
        std.debug.print("Failed to create Wayland display\n", .{});
        return error.WaylandInitFailed;
    };

    // Setup Wayland server
    compositor.event_loop = c.wl_display_get_event_loop(compositor.display);

    _ = c.wl_global_create(compositor.display, &c.wl_compositor_interface, 4, compositor, bindCompositor) orelse {
        std.debug.print("Failed to create compositor interface\n", .{});
        return error.CompositorInitFailed;
    };

    const socket = c.wl_display_add_socket_auto(compositor.display);
    if (socket == null) {
        std.debug.print("Failed to create Wayland socket\n", .{});
        return error.SocketCreationFailed;
    }

    std.debug.print("Running Wayland compositor on socket {s}\n", .{socket});

    // Run the compositor
    _ = c.wl_display_run(compositor.display);
}
