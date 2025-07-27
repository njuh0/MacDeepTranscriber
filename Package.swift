// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MacDeepTranscriber",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .executable(name: "MacDeepTranscriber", targets: ["MacDeepTranscriber"])
    ],
    dependencies: [
        // No external dependencies - using Apple Speech only
    ],
    targets: [
        .executableTarget(
            name: "MacDeepTranscriber",
            dependencies: [],
            path: "MacDeepTranscriber",
            resources: [
                .process("Assets.xcassets"),
                .copy("MacDeepTranscriber.entitlements")
            ]
        )
    ]
)