// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "QuotaPulse",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "QuotaPulse", targets: ["QuotaPulse"])],
    targets: [
        .executableTarget(
            name: "QuotaPulse",
            path: "Sources/QuotaPulse",
            resources: [.process("Resources")]
        ),
        .testTarget(name: "QuotaPulseTests", dependencies: ["QuotaPulse"], path: "Tests/QuotaPulseTests")
    ]
)
