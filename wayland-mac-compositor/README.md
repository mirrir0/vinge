# Wayland macOS Compositor

A Wayland compositor implementation that runs natively within a macOS window.

## Features

- Wayland protocol support
- Metal-accelerated rendering
- Native macOS integration

## Getting Started

See [Installation Guide](docs/installation.md) for setup instructions.

# Wayland macOS Compositor Documentation

## Table of Contents
- [README.md](#readmemd)
- [Installation Guide](docs/installation.md)
- [Usage Guide](docs/usage.md)
- [Development Guide](docs/development.md)
- [API Reference](docs/api-reference.md)
- [Language Integration](docs/language-integration.md)
- [Contributing](docs/contributing.md)

## README.md
# Wayland macOS Compositor

A Wayland compositor implementation that runs natively within a macOS window, providing seamless integration between Wayland clients and macOS's Metal graphics API.

## Features

- Run Wayland applications inside a native macOS window
- Hardware-accelerated rendering using Metal
- Support for XDG Shell protocol
- Input handling (keyboard and mouse)
- Multi-monitor support
- Swift/Metal backend with Zig implementation

## Quick Start

1. Install dependencies:
```bash
brew install zig
brew install wayland
xcode-select --install
```

2. Build the project:
```bash
# Build Swift framework
cd WaylandMacBridge
swift build -c release
cd ..

# Build Zig compositor
zig build
```

3. Run the compositor:
```bash
zig build run
```

4. Run a Wayland client:
```bash
WAYLAND_DISPLAY=wayland-1 your-wayland-app
```

## Documentation

- [Installation Guide](docs/installation.md) - Detailed setup instructions
- [Usage Guide](docs/usage.md) - How to use the compositor
- [Development Guide](docs/development.md) - How to develop with the compositor
- [API Reference](docs/api-reference.md) - API documentation
- [Language Integration](docs/language-integration.md) - Using with different programming languages
- [Contributing](docs/contributing.md) - How to contribute to the project

## Installation Guide

## Usage Guide

## Common Operations

### Managing Windows

- Click and drag the title bar to move windows
- Use window corners to resize
- Right-click title bar for additional options

### Keyboard Shortcuts

- `Cmd + Q`: Quit compositor
- `Cmd + W`: Close active window
- `Cmd + M`: Minimize window
- `Cmd + F`: Toggle fullscreen

### Multi-monitor Support

The compositor automatically detects available displays. Use System Preferences to configure display arrangement.

## Development Guide

## API Reference
## Contributing

## License

MIT License - see LICENSE file for details