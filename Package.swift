// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "NeonPulse",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(name: "NeonPulse", targets: ["NeonPulse"])
    ],
    targets: [
        .executableTarget(
            name: "NeonPulse",
            path: "Sources/NeonPulse",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "NeonPulseTests",
            dependencies: ["NeonPulse"],
            path: "Tests/NeonPulseTests"
        )
    ]
)
