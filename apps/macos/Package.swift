// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "MissionControlMac",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "MissionControlMac", targets: ["MissionControlMac"]),
    ],
    dependencies: [
        .package(url: "https://github.com/clerk/clerk-ios", .upToNextMajor(from: "1.0.0")),
        .package(
            url: "https://github.com/microsoft/SwiftStreamingMarkdown",
            revision: "95bb755a9b23a1aea8682b9ebc912cb72b176c95"
        ),
    ],
    targets: [
        .executableTarget(
            name: "MissionControlMac",
            dependencies: [
                .product(name: "ClerkKit", package: "clerk-ios"),
                .product(name: "SwiftStreamingMarkdown", package: "SwiftStreamingMarkdown"),
            ]
        ),
        .testTarget(
            name: "MissionControlMacTests",
            dependencies: ["MissionControlMac"]
        ),
    ]
)
