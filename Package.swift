// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "CodexMicroMapper",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "CodexMicroMapper", targets: ["CodexMicroMapper"]),
    ],
    targets: [
        .target(
            name: "CodexMicroCore"
        ),
        .target(
            name: "CodexMicroSystem",
            dependencies: ["CodexMicroCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("IOKit"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
        .executableTarget(
            name: "CodexMicroMapper",
            dependencies: ["CodexMicroCore", "CodexMicroSystem"],
            path: "Sources/CodexMicroMapperApp",
            resources: [
                .copy("Resources"),
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
        .testTarget(
            name: "CodexMicroCoreTests",
            dependencies: ["CodexMicroCore"]
        ),
        .testTarget(
            name: "CodexMicroSystemTests",
            dependencies: ["CodexMicroCore", "CodexMicroSystem"]
        ),
        .testTarget(
            name: "CodexMicroMapperTests",
            dependencies: ["CodexMicroMapper", "CodexMicroCore"]
        ),
    ]
)
