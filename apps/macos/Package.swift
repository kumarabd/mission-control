// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "MissionControl",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "MissionControl", targets: ["MissionControl"]),
    ],
    dependencies: [
        .package(url: "https://github.com/clerk/clerk-ios", .upToNextMajor(from: "1.0.0")),
        .package(
            url: "https://github.com/microsoft/SwiftStreamingMarkdown",
            revision: "95bb755a9b23a1aea8682b9ebc912cb72b176c95"
        ),
        .package(url: "https://github.com/ianleon/ForceGraph.git", .upToNextMinor(from: "0.3.0")),
    ],
    targets: [
        .executableTarget(
            name: "MissionControl",
            dependencies: [
                .product(name: "ClerkKit", package: "clerk-ios"),
                .product(name: "SwiftStreamingMarkdown", package: "SwiftStreamingMarkdown"),
                .product(name: "ForceGraph", package: "ForceGraph"),
            ],
            // Xcode owns the asset catalog and copies the fonts into the app;
            // SwiftPM only needs the fonts for `swift run`.
            exclude: ["Assets.xcassets"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "MissionControlTests",
            dependencies: ["MissionControl"]
        ),
    ],
    // The shared iOS Core predates strict concurrency. Build both clients in the
    // same language mode until that layer is migrated together.
    swiftLanguageModes: [.v5]
)
