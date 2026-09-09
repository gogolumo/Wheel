// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "Wheel",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "WheelDomain", targets: ["WheelDomain"]),
        .library(name: "WheelCore", targets: ["WheelCore"]),
        .executable(name: "wheel-demo", targets: ["WheelDemo"])
    ],
    targets: [
        .target(
            name: "WheelDomain"
        ),
        .target(
            name: "WheelCore",
            dependencies: ["WheelDomain"]
        ),
        .executableTarget(
            name: "WheelDemo",
            dependencies: ["WheelDomain", "WheelCore"]
        ),
        .testTarget(
            name: "WheelDomainTests",
            dependencies: ["WheelDomain"]
        ),
        .testTarget(
            name: "WheelCoreTests",
            dependencies: ["WheelCore", "WheelDomain"]
        )
    ]
)
