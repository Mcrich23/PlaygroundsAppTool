// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "PlaygroundsAppTool",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .library(name: "PlaygroundsAppToolLibrary", targets: ["PlaygroundsAppToolLibrary"]),
        .executable(name: "PlaygroundsAppTool", targets: ["PlaygroundsAppTool"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "602.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "PlaygroundsAppTool",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "PlaygroundsAppToolLibrary"
            ],
            path: "Sources/CLI"
        ),
        .target(
            name: "PlaygroundsAppToolLibrary",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ],
            path: "Sources/PlaygroundsAppToolLibrary"
        )
    ]
)
