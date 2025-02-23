# Usage Guide

## Basic Usage

1. Start the compositor:
```bash
zig build run
```

2. Run Wayland clients:
```bash
WAYLAND_DISPLAY=wayland-1 weston-terminal
```

## Configuration

The compositor can be configured through `~/.config/wayland-mac-compositor/config.toml`:

```toml
[window]
width = 1024
height = 768
title = "Wayland Compositor"

[rendering]
vsync = true
scale = 1.0

[debug]
enable_logging = false
```
