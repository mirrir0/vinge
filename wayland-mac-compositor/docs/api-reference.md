# API Reference

## Zig API

### Compositor

```zig
pub const Compositor = struct {
    pub fn init(allocator: std.mem.Allocator) !*Compositor;
    pub fn deinit(self: *Compositor) void;
    pub fn run(self: *Compositor) !void;
};
```

### Surface

```zig
pub const Surface = struct {
    pub fn init(allocator: std.mem.Allocator) !*Surface;
    pub fn attach(self: *Surface, buffer: *Buffer) void;
    pub fn commit(self: *Surface) void;
};
```

## Swift API

### WaylandWindow

```swift
public class WaylandWindow {
    public init()
    public func drawBuffer(buffer: UnsafeRawPointer, width: Int, height: Int)
    public func handleInput(event: NSEvent)
}
```

## Language Integration
# Language Integration

## Zig Integration

Import and use in your Zig project:

```zig
const wmc = @import("wayland_mac_compositor");

pub fn main() !void {
    var compositor = try wmc.Compositor.init(allocator);
    defer compositor.deinit();
    try compositor.run();
}
```

## Rust Integration

Add to your `Cargo.toml`:

```toml
[dependencies]
wayland-mac-compositor = "0.1.0"
```

Use in your Rust code:

```rust
use wayland_mac_compositor::{Compositor, Surface};

fn main() -> Result<(), Box<dyn Error>> {
    let mut compositor = Compositor::new()?;
    compositor.run()?;
    Ok(())
}
```

## Swift Integration

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/wayland-mac-compositor", from: "0.1.0")
]
```

Use in your Swift code:

```swift
import WaylandMacCompositor

let window = WaylandWindow()
window.show()
```

