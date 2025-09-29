// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "whipswift",
    products: [
        .library(name: "WhipCore", targets: ["WhipCore"]),
    ],
    targets: [
        .target(
            name: "WhipCore",
            path: "Sources/WhipCore"
        ),
        .testTarget(
            name: "WhipCoreTests",
            dependencies: ["WhipCore"],
            path: "Tests/WhipCoreTests"
        )
    ]
)
