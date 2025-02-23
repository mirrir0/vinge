# Configuration System Design

## config.example.toml

```toml
# Wayland macOS Compositor Configuration
# Place this file at ~/.config/wayland-mac-compositor/config.toml

[window]
# Initial window dimensions
width = 1024
height = 768
title = "Wayland Compositor"
# Whether to remember window position between sessions
remember_position = true
# Default window position (if remember_position is false)
default_x = 100
default_y = 100

[rendering]
# Enable VSync
vsync = true
# Display scale factor (1.0 = 100%)
scale = 1.0
# Maximum frame rate (0 = unlimited)
max_fps = 60
# Enable Metal GPU acceleration
gpu_acceleration = true
# Preferred Metal device (empty = automatic)
preferred_gpu = ""
# Buffer swap strategy: "immediate", "fifo", or "mailbox"
swap_strategy = "fifo"

[input]
# Input event handling rate in Hz
input_rate = 125
# Mouse acceleration (1.0 = system default)
mouse_acceleration = 1.0
# Key repeat delay in milliseconds
key_repeat_delay = 500
# Key repeat rate in milliseconds
key_repeat_rate = 30

[debug]
# Enable debug logging
enable_logging = false
# Log level: "error", "warn", "info", "debug", "trace"
log_level = "info"
# Log file path (empty = stdout)
log_file = ""
# Enable performance metrics
enable_metrics = false
# Metrics reporting interval in seconds
metrics_interval = 5

[protocols]
# Enable/disable specific Wayland protocols
xdg_shell = true
xdg_decoration = true
linux_dmabuf = false
viewporter = true
relative_pointer = true
pointer_constraints = true
keyboard_shortcuts_inhibit = true

[security]
# Allow/deny specific clients
allow_clients = ["org.freedesktop.*", "com.example.*"]
deny_clients = []
# Enable sandbox restrictions
enable_sandbox = true
# Maximum client memory in MB
max_client_memory = 512
# Maximum number of clients
max_clients = 10
```

### Design Considerations

1. **Configuration Format**
   - TOML chosen for human readability and well-defined spec
   - Hierarchical structure maps cleanly to Zig structs
   - Easy to extend with new sections

2. **Default Values**
   - All settings have sensible defaults
   - Critical settings fail-safe to secure/stable values
   - Performance settings balanced for typical use

3. **Validation**
   - All values must be validated on load
   - Type checking must be strict
   - Range validation for numeric values
   - Pattern matching for strings

4. **Hot Reload**
   - Config should support hot reload where possible
   - State changes must be atomic
   - Maintain consistency during reloads

# Integration Testing System

## run_integration_tests.sh

```bash
#!/usr/bin/env bash
set -euo pipefail

# Configuration
COMPOSITOR_BIN="./zig-out/bin/wayland-mac-compositor"
TEST_TIMEOUT=30
TEMP_DIR=$(mktemp -d)
LOG_FILE="$TEMP_DIR/test.log"
WAYLAND_SOCKET="$TEMP_DIR/wayland-test-0"

# Test applications
APPS=(
    "weston-terminal"
    "gtk3-demo"
    "qt5-wayland-test"
    "custom-test-client"
)

# Cleanup function
cleanup() {
    echo "Cleaning up..."
    kill $COMPOSITOR_PID || true
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# Start compositor
export WAYLAND_DEBUG=1
export WAYLAND_DISPLAY="$WAYLAND_SOCKET"
$COMPOSITOR_BIN --test-mode &
COMPOSITOR_PID=$!

# Wait for compositor to start
sleep 2

# Run test suite
run_test_suite() {
    local test_name=$1
    echo "Running test: $test_name"
    
    case $test_name in
        "basic-connection")
            test_basic_connection
            ;;
        "surface-creation")
            test_surface_creation
            ;;
        "input-handling")
            test_input_handling
            ;;
        *)
            echo "Unknown test: $test_name"
            exit 1
            ;;
    esac
}

# Test implementations
test_basic_connection() {
    # Test client connection
    for app in "${APPS[@]}"; do
        echo "Testing connection with $app"
        timeout $TEST_TIMEOUT $app --wayland-only || {
            echo "Connection test failed for $app"
            exit 1
        }
    done
}

test_surface_creation() {
    # Surface creation tests
    ./test-clients/surface-test || exit 1
}

test_input_handling() {
    # Input handling tests
    ./test-clients/input-test || exit 1
}

# Run all tests
for test in "${@:-basic-connection surface-creation input-handling}"; do
    run_test_suite "$test"
done

echo "All tests passed!"
```

### Design Considerations

1. **Test Environment**
   - Isolated Wayland socket for testing
   - Temporary directory for test artifacts
   - Proper cleanup on exit
   - Timeout mechanism for hanging tests

2. **Test Coverage**
   - Basic connectivity testing
   - Protocol compliance testing
   - Input handling verification
   - Resource management testing
   - Performance benchmarking

3. **Test Structure**
   - Modular test implementation
   - Easy to add new test cases
   - Clear failure reporting
   - Reproducible test conditions

4. **Reliability**
   - Proper error handling
   - Cleanup of resources
   - Timeout mechanism
   - Isolation between tests

# Metal Rendering Pipeline Design

## Complete Shader Implementation

```metal
#include <metal_stdlib>
using namespace metal;

// Vertex shader inputs
struct VertexInput {
    float3 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
    float4 color    [[attribute(2)]];
};

// Vertex shader outputs / Fragment shader inputs
struct ColorInOut {
    float4 position [[position]];
    float2 texCoord;
    float4 color;
    float  layer   [[render_target_array_index]];
};

// Uniform buffer containing transform matrices
struct Uniforms {
    float4x4 modelMatrix;
    float4x4 viewMatrix;
    float4x4 projectionMatrix;
    float4x4 textureMatrix;
    float4   clipPlane;
    float    opacity;
    float    layer;
};

// Vertex shader
vertex ColorInOut vertexShader(
    VertexInput in [[stage_in]],
    constant Uniforms & uniforms [[buffer(1)]]
) {
    ColorInOut out;
    
    // Apply transformations
    float4 position = float4(in.position, 1.0);
    position = uniforms.modelMatrix * position;
    position = uniforms.viewMatrix * position;
    position = uniforms.projectionMatrix * position;
    
    // Transform texture coordinates
    float4 texCoord = float4(in.texCoord, 0.0, 1.0);
    texCoord = uniforms.textureMatrix * texCoord;
    
    out.position = position;
    out.texCoord = texCoord.xy;
    out.color = in.color;
    out.layer = uniforms.layer;
    
    return out;
}

// Fragment shader
fragment float4 fragmentShader(
    ColorInOut in [[stage_in]],
    texture2d<float> texture [[texture(0)]],
    constant Uniforms & uniforms [[buffer(1)]]
) {
    constexpr sampler textureSampler(
        mag_filter::linear,
        min_filter::linear,
        mip_filter::linear,
        address::clamp_to_edge
    );
    
    // Sample texture
    float4 color = texture.sample(textureSampler, in.texCoord);
    
    // Apply color transformation
    color *= in.color;
    
    // Apply opacity
    color.a *= uniforms.opacity;
    
    return color;
}

// Compute shader for effects
kernel void computeEffects(
    texture2d<float, access::read> inTexture [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    // Ensure within texture bounds
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
        return;
    }
    
    // Read input color
    float4 color = inTexture.read(gid);
    
    // Apply effects (example: brightness adjustment)
    color = pow(color, 2.2); // gamma correction
    color = color * 1.2;     // brightness boost
    color = pow(color, 1/2.2); // inverse gamma
    
    // Write output
    outTexture.write(color, gid);
}
```

### Design Considerations

1. **Performance**
   - Efficient vertex transformation
   - Optimal texture sampling
   - Minimal uniform buffer updates
   - Batch rendering support

2. **Feature Support**
   - Multi-layer compositing
   - Color transformation
   - Texture matrix support
   - Clipping planes
   - Opacity/transparency

3. **Quality**
   - Proper gamma correction
   - High-quality texture filtering
   - Antialiasing support
   - Color precision

4. **Flexibility**
   - Extensible effect system
   - Configurable parameters
   - Multiple render paths
   - Debug visualization support

# XDG Shell Protocol Implementation

```zig
const XdgShellState = struct {
    const Role = enum {
        none,
        toplevel,
        popup,
    };

    surface: *Surface,
    role: Role,
    toplevel: ?*XdgToplevel,
    popup: ?*XdgPopup,
    configured: bool,
    pending: struct {
        x: i32,
        y: i32,
        width: i32,
        height: i32,
        states: std.ArrayList(XdgToplevelState),
    },
    current: struct {
        x: i32,
        y: i32,
        width: i32,
        height: i32,
        states: std.ArrayList(XdgToplevelState),
    },

    pub fn init(allocator: std.mem.Allocator, surface: *Surface) !*XdgShellState {
        const self = try allocator.create(XdgShellState);
        self.* = .{
            .surface = surface,
            .role = .none,
            .toplevel = null,
            .popup = null,
            .configured = false,
            .pending = .{
                .x = 0,
                .y = 0,
                .width = 0,
                .height = 0,
                .states = std.ArrayList(XdgToplevelState).init(allocator),
            },
            .current = .{
                .x = 0,
                .y = 0,
                .width = 0,
                .height = 0,
                .states = std.ArrayList(XdgToplevelState).init(allocator),
            },
        };
        return self;
    }

    pub fn deinit(self: *XdgShellState) void {
        self.pending.states.deinit();
        self.current.states.deinit();
        self.allocator.destroy(self);
    }

    pub fn configure(self: *XdgShellState, width: i32, height: i32) !void {
        self.pending.width = width;
        self.pending.height = height;
        try self.sendConfigure();
    }

    pub fn sendConfigure(self: *XdgShellState) !void {
        const serial = self.surface.compositor.nextSerial();
        
        switch (self.role) {
            .toplevel => if (self.toplevel) |toplevel| {
                try toplevel.configure(
                    self.pending.width,
                    self.pending.height,
                    self.pending.states.items,
                );
            },
            .popup => if (self.popup) |popup| {
                try popup.configure(
                    self.pending.x,
                    self.pending.y,
                    self.pending.width,
                    self.pending.height,
                );
            },
            .none => return,
        }

        try self.surface.configure(serial);
    }

    pub fn commit(self: *XdgShellState) !void {
        if (!self.configured) {
            return error.NotConfigured;
        }

        // Update current state
        self.current.x = self.pending.x;
        self.current.y = self.pending.y;
        self.current.width = self.pending.width;
        self.current.height = self.pending.height;
        
        try self.current.states.resize(0);
        try self.current.states.appendSlice(self.pending.states.items);
    }
};
```

### Design Considerations

1. **Protocol Compliance**
   - Full XDG Shell protocol support
   - Proper state management
   - Correct event ordering
   - Version compatibility

2. **State Management**
   - Clear separation of pending/current state
   - Atomic state updates
   - Proper cleanup on destruction
   - Error handling

3. **Resource Management**
   - Memory allocation strategy
   - Resource cleanup
   - Reference counting
   - Lifecycle management

4. **Performance**
   - Efficient state updates
   - Minimal allocations
   - Batched configurations
   - Event coalescing

# Error Handling and Logging System

```zig
const std = @import("std");

pub const LogLevel = enum {
    error,
    warn,
    info,
    debug,
    trace,

    pub fn format(
        self: LogLevel,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        switch (self) {
            .error => try writer.writeAll("ERROR"),
            .warn => try writer.writeAll("WARN"),
            .info => try writer.writeAll("INFO"),
            .debug => try writer.writeAll("DEBUG"),
            .trace => try writer.writeAll("TRACE"),
        }
    }
};

pub const LogContext = struct {
    file: []const u8,
    line: u32,
    function: []const u8,
    level: LogLevel,
};

pub const Logger = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    mutex: std.Thread.Mutex,
    file: ?std.fs.File,
    level: LogLevel,
    metrics: Metrics,

    pub fn init(allocator: std.mem.Allocator, level: LogLevel) !Self {
        return Self{
            .allocator = allocator,
            .mutex = std.Thread.Mutex{},
            .file = null,
            .level = level,
            .metrics = Metrics.init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.file) |file| {
            file.close();
        }
        self.metrics.deinit();
    }

    pub fn setFile(self: *Self, path: []const u8) !void {
        const file = try std.fs.createFileAbsolute(path, .{
            .read = true,
            .truncate = false,
        });
        
        if (self.file) |old_file| {
            old_file.close();
        }
        
        self.file = file;
    }

    pub fn log(
        self: *Self,
        context: LogContext,
        comptime format: []const u8,
        args: anytype,
    ) !void {
        if (@enumToInt(context.level) > @enumToInt(self.level)) {
            return;
        }

        self.mutex.lock();
        defer self.mutex.unlock();

        const timestamp = std.time.milliTimestamp();
        const thread_id = std.Thread.getCurrentId();

        // Format: [LEVEL] [timestamp] [thread] [file:line] message
        const message = try std.fmt.allocPrint(
            self.allocator,
            "[{s}] [{d}] [{d}] [{s}:{d}] " ++ format ++ "\n",
            .{
                context.level,
                timestamp,
                thread_id,
                context.file,
                context.line,
            } ++ args,
        );
        defer self.allocator.free(message);

        if (self.file) |file| {
            try file.writeAll(message);
            try file.sync();
        } else {
            try std.io.getStdOut().writeAll(message);
        }

        // Update metrics
        try self.metrics.recordLog(context.level);
    }
};

pub const Metrics = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    mutex: std.Thread.Mutex,
    counts: std.AutoHashMap(LogLevel, u64),
    start_time: i64,

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .mutex = std.Thread.Mutex{},
            .counts = std.AutoHashMap(LogLevel, u64).init(allocator),
            .start_time = std.time.milliTimestamp(),
        };
    }

    pub fn deinit(self: *Self) void {
        self.counts.deinit();
    }

    pub fn recordLog(self: *Self, level: LogLevel) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const count = self.counts.get(level) orelse 0;
        try self.counts.put(level, count + 1);
    }

    pub fn getReport(self: *Self, writer: anytype) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const elapsed = std.time.milliTimestamp() - self.start_time;
        try writer.print("Log Metrics Report (elapsed: {d}ms)\n", .{elapsed});

        var it = self.counts.iterator();
        while (it.next()) |entry| {
            try writer.print("{s}: {d}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
        }
    }
};

// Error types
pub const CompositorError = error{
    NotConfigured,
    NotInitialized,
    InvalidState,
    ResourceNotFound,
    ProtocolError,
    RenderError,
    SystemError,
    OutOfMemory,
};

// Error handling macros
pub fn assertOrLog(
    condition: bool,
    logger: *Logger,
    level: LogLevel,
    comptime format: []const u8,
    args: anytype,
) !void {
    if (!condition) {
        try logger.log(.{
            .level = level,
            .file = @src().file,
            .line = @src().line,
            .function = @src().fn_name,
        }, format, args);
        return error.AssertionFailed;
    }
}
```

### Design Considerations

1. **Thread Safety**
   - Mutex protection for shared resources
   - Atomic operations where appropriate
   - Thread-local storage for performance
   - Deadlock prevention

2. **Performance**
   - Efficient string formatting
   - Minimized allocations
   - Level-based filtering
   - Buffered I/O

3. **Observability**
   - Structured logging format
   - Metrics collection
   - Performance tracking
   - Debug capabilities

4. **Reliability**
   - Fail-safe operations
   - Resource cleanup
   - Error propagation
   - Recovery mechanisms

# Rust FFI Bindings

```rust
use std::ffi::{c_void, CStr, CString};
use std::os::raw::{c_char, c_int};
use std::sync::Arc;

#[repr(C)]
pub struct WaylandMacCompositor {
    _private: [u8; 0],
}

#[repr(C)]
pub struct WaylandSurface {
    _private: [u8; 0],
}

#[link(name = "wayland_mac_compositor")]
extern "C" {
    fn wmc_compositor_create() -> *mut WaylandMacCompositor;
    fn wmc_compositor_destroy(compositor: *mut WaylandMacCompositor);
    fn wmc_compositor_run(compositor: *mut WaylandMacCompositor) -> c_int;
    fn wmc_surface_attach(
        surface: *mut WaylandSurface,
        buffer: *const c_void,
        width: c_int,
        height: c_int,
    ) -> c_int;
}

pub struct Compositor {
    inner: *mut WaylandMacCompositor,
}

impl Compositor {
    pub fn new() -> Result<Self, Box<dyn std::error::Error>> {
        let inner = unsafe { wmc_compositor_create() };
        if inner.is_null() {
            return Err("Failed to create compositor".into());
        }
        Ok(Self { inner })
    }

    pub fn run(&self) -> Result<(), Box<dyn std::error::Error>> {
        let result = unsafe { wmc_compositor_run(self.inner) };
        if result != 0 {
            return Err("Failed to run compositor".into());
        }
        Ok(())
    }
}

impl Drop for Compositor {
    fn drop(&mut self) {
        unsafe { wmc_compositor_destroy(self.inner) }
    }
}

// Safe wrapper for Surface
pub struct Surface {
    inner: *mut WaylandSurface,
}

impl Surface {
    pub fn attach_buffer(
        &self,
        buffer: &[u8],
        width: i32,
        height: i32,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let result = unsafe {
            wmc_surface_attach(
                self.inner,
                buffer.as_ptr() as *const c_void,
                width,
                height,
            )
        };
        if result != 0 {
            return Err("Failed to attach buffer".into());
        }
        Ok(())
    }
}

// Safe Rust API
pub struct WaylandCompositor {
    compositor: Arc<Compositor>,
}

impl WaylandCompositor {
    pub fn new() -> Result<Self, Box<dyn std::error::Error>> {
        Ok(Self {
            compositor: Arc::new(Compositor::new()?),
        })
    }

    pub fn run(&self) -> Result<(), Box<dyn std::error::Error>> {
        self.compositor.run()
    }
}

// Example usage
fn main() -> Result<(), Box<dyn std::error::Error>> {
    let compositor = WaylandCompositor::new()?;
    compositor.run()?;
    Ok(())
}
```

### Design Considerations

1. **Safety**
   - Proper memory management
   - Safe wrapper types
   - Error handling
   - Thread safety

2. **API Design**
   - Idiomatic Rust interface
   - Clear ownership semantics
   - Error propagation
   - Resource cleanup

3. **Performance**
   - Minimal overhead
   - Zero-copy where possible
   - Efficient memory layout
   - Cache-friendly design

4. **Interoperability**
   - C ABI compatibility
   - Platform considerations
   - Version compatibility
   - Feature parity

[Continues with additional missing components documentation if you'd like me to cover more.]