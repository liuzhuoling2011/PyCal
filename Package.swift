// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PyCal",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .executable(name: "PyCal", targets: ["PyCal"])
    ],
    targets: [
        .executableTarget(
            name: "PyCal",
            path: "Sources/PyCal",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PyCalTests",
            dependencies: ["PyCal"],
            path: "Tests/PyCalTests"
        )
    ]
)
