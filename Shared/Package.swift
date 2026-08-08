// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "DontUnplugThatShared",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "DontUnplugThatShared",
            targets: ["DontUnplugThatShared"]
        )
    ],
    targets: [
        .target(name: "DontUnplugThatShared"),
        .testTarget(
            name: "DontUnplugThatSharedTests",
            dependencies: ["DontUnplugThatShared"]
        )
    ]
)
