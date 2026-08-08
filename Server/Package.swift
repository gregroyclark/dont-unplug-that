// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "DontUnplugThatServer",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "DontUnplugThatServer",
            targets: ["DontUnplugThatServer"]
        )
    ],
    dependencies: [
        .package(path: "../Shared"),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.100.0")
    ],
    targets: [
        .executableTarget(
            name: "DontUnplugThatServer",
            dependencies: [
                .product(name: "DontUnplugThatShared", package: "Shared"),
                .product(name: "Vapor", package: "vapor")
            ]
        ),
        .testTarget(
            name: "DontUnplugThatServerTests",
            dependencies: [
                "DontUnplugThatServer",
                .product(name: "DontUnplugThatShared", package: "Shared"),
                .product(name: "XCTVapor", package: "vapor")
            ]
        )
    ]
)
