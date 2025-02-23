# Installation

## Prerequisites

- macOS 11.0 or later
- Xcode Command Line Tools
- Zig 0.11.0 or later
- Wayland development libraries

## Installing Dependencies

1. Install Homebrew if not already installed:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

2. Install required packages:
```bash
brew install zig
brew install wayland
xcode-select --install
```

3. Verify installations:
```bash
zig version
wayland-scanner --version
```

## Building from Source

1. Clone the repository:
```bash
git clone https://github.com/yourusername/wayland-mac-compositor
cd wayland-mac-compositor
```

2. Build the Swift framework:
```bash
cd WaylandMacBridge
swift build -c release
cd ..
```

3. Build the Zig compositor:
```bash
zig build
```

## System Configuration

1. Set up environment variables in your shell configuration:
```bash
export WAYLAND_DEBUG=1  # Optional: Enable Wayland debug output
```

2. Configure XDG paths:
```bash
mkdir -p ~/.config/wayland-mac-compositor
cp config.example.toml ~/.config/wayland-mac-compositor/config.toml
```
