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
        .library(name: "WheelMacOS", targets: ["WheelMacOS"]),
        .executable(name: "wheel-demo", targets: ["WheelDemo"]),
        .executable(name: "wheel-input-spike", targets: ["WheelInputSpike"])
    ],
    targets: [
        .target(
            name: "WheelDomain"
        ),
        .target(
            name: "WheelCore",
            dependencies: ["WheelDomain"]
        ),
        .target(
            name: "WheelMacOS",
            dependencies: ["WheelDomain"],
            linkerSettings: [
                .linkedFramework("ApplicationServices")
            ]
        ),
        .executableTarget(
            name: "WheelDemo",
            dependencies: ["WheelDomain", "WheelCore"]
        ),
        .executableTarget(
            name: "WheelInputSpike",
            dependencies: ["WheelDomain", "WheelMacOS"]
        ),
        .testTarget(
            name: "WheelDomainTests",
            dependencies: ["WheelDomain"]
        ),
        .testTarget(
            name: "WheelCoreTests",
            dependencies: ["WheelCore", "WheelDomain"]
        ),
        .testTarget(
            name: "WheelMacOSTests",
            dependencies: ["WheelDomain", "WheelMacOS"]
        )
    ]
)
