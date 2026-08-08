// swift-tools-version: 6.1
// This is a Skip (https://skip.dev) package.
import PackageDescription

let package = Package(
    name: "App",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DontUnplugThat", type: .dynamic, targets: ["DontUnplugThat"]),
    ],
    dependencies: [
        .package(url: "https://source.skip.tools/skip.git", from: "1.9.5"),
        .package(url: "https://source.skip.tools/skip-fuse-ui.git", from: "1.0.0"),
        .package(url: "https://source.skip.dev/skip-kit.git", from: "1.0.0"),
        .package(url: "https://source.skip.dev/skip-authentication-services.git", exact: "0.1.0"),
        .package(url: "https://source.skip.tools/skip-keychain.git", exact: "0.3.2"),
        .package(path: "../Shared")
    ],
    targets: [
        .target(name: "DontUnplugThat", dependencies: [
            .product(name: "SkipFuseUI", package: "skip-fuse-ui"),
            .product(name: "SkipKit", package: "skip-kit"),
            .product(name: "SkipAuthenticationServices", package: "skip-authentication-services"),
            .product(name: "SkipKeychain", package: "skip-keychain"),
            .product(name: "DontUnplugThatShared", package: "Shared")
        ], resources: [.process("Resources")], plugins: [.plugin(name: "skipstone", package: "skip")]),
        .testTarget(
            name: "DontUnplugThatTests",
            dependencies: ["DontUnplugThat"]
        ),
    ]
)
