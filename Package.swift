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
        // WhisperKit for native Swift speech recognition
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.7.0")
    ],
    targets: [
        .executableTarget(
            name: "AudioStudy",
            dependencies: [
                "WhisperKit"
            ],
            path: "Audio Study"
        )
    ]
)