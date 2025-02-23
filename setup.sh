#!/usr/bin/env bash

# Exit on error, undefined variables, and print commands
set -euxo pipefail

# Create root directory
mkdir -p wayland-mac-compositor
cd wayland-mac-compositor

# Create GitHub related directories
mkdir -p .github/workflows
mkdir -p .github/ISSUE_TEMPLATE

# Create empty GitHub Action workflows
cat >.github/workflows/build.yml <<'EOF'
name: Build
on: [push, pull_request]
jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v2
EOF

cat >.github/workflows/test.yml <<'EOF'
name: Test
on: [push, pull_request]
jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v2
EOF

cat >.github/workflows/release.yml <<'EOF'
name: Release
on:
  push:
    tags:
      - 'v*'
jobs:
  release:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v2
EOF

# Create documentation directory and files
mkdir -p docs
touch docs/{api-reference,contributing,development,installation,language-integration,usage}.md

# Create example directories
mkdir -p examples/{rust,zig,swift}
touch examples/rust/example.rs
touch examples/zig/example.zig
touch examples/swift/example.swift

# Create scripts directory
mkdir -p scripts
cat >scripts/build.sh <<'EOF'
#!/usr/bin/env bash
set -euxo pipefail
# Add build logic here
EOF

cat >scripts/run_integration_tests.sh <<'EOF'
#!/usr/bin/env bash
set -euxo pipefail
# Add test logic here
EOF

cat >scripts/setup_dev_environment.sh <<'EOF'
#!/usr/bin/env bash
set -euxo pipefail
# Add setup logic here
EOF

chmod +x scripts/*.sh

# Create source directory structure
mkdir -p src/{compositor,protocols,renderer,util}
touch src/compositor/{compositor,surface,output,input}.zig
touch src/protocols/{xdg_shell,compositor,seat}.zig
touch src/renderer/{metal.zig,shaders.metal}
touch src/util/{logger,config}.zig
touch src/main.zig

# Create Swift package structure
mkdir -p swift/Sources/WaylandMacBridge
mkdir -p swift/Tests/WaylandMacBridgeTests
touch swift/Sources/WaylandMacBridge/{MetalView,Renderer,Window}.swift
touch swift/Tests/WaylandMacBridgeTests/MetalTests.swift

# Create Package.swift
cat >swift/Package.swift <<'EOF'
// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "WaylandMacBridge",
    platforms: [.macOS(.v11)],
    products: [
        .library(
            name: "WaylandMacBridge",
            targets: ["WaylandMacBridge"]),
    ],
    targets: [
        .target(
            name: "WaylandMacBridge",
            dependencies: []),
        .testTarget(
            name: "WaylandMacBridgeTests",
            dependencies: ["WaylandMacBridge"]),
    ]
)
EOF

# Create test directory structure
mkdir -p tests/{integration,unit}
touch tests/integration/{compositor,protocol}_tests.zig
touch tests/unit/{compositor,protocol}_tests.zig

# Create vendor directory
mkdir -p vendor/protocols

# Create root level files
cat >.gitignore <<'EOF'
# Zig
zig-out/
zig-cache/

# Swift
.build/
.swiftpm/
Package.resolved

# OS
.DS_Store
.Spotlight-V100
.Trashes

# IDE
.vscode/
.idea/
*.xcodeproj
*.xcworkspace

# Test results
tests/results/

# Local configuration
config.toml
EOF

cat >LICENSE <<'EOF'
MIT License

Copyright (c) [year] [fullname]

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF

cat >README.md <<'EOF'
# Wayland macOS Compositor

A Wayland compositor implementation that runs natively within a macOS window.

## Features

- Wayland protocol support
- Metal-accelerated rendering
- Native macOS integration

## Getting Started

See [Installation Guide](docs/installation.md) for setup instructions.
EOF

cat >build.zig <<'EOF'
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "wayland-mac-compositor",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(exe);
}
EOF

cat >config.example.toml <<'EOF'
[window]
width = 1024
height = 768
title = "Wayland Compositor"

[rendering]
vsync = true
scale = 1.0

[debug]
enable_logging = false
log_level = "info"
EOF

# Make scripts executable
chmod +x scripts/*.sh

echo "Project structure created successfully!"
