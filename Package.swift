// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "kMacPaint",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "kMacPaint",
            targets: ["kMacPaint"]
        ),
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "kMacPaint",
            dependencies: [],
            path: "Sources/kMacPaint",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "kMacPaintTests",
            dependencies: ["kMacPaint"],
            path: "Tests/kMacPaintTests"
        ),
    ]
)
