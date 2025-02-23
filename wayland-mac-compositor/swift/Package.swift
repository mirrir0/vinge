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
