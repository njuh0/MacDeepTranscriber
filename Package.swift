// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AudioStudy",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .executable(name: "AudioStudy", targets: ["AudioStudy"])
    ],
    dependencies: [
        // No external dependencies - using Apple Speech only
    ],
    targets: [
        .executableTarget(
            name: "AudioStudy",
            dependencies: [],
            path: "Audio Study"
        )
    ]
)