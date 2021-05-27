// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftVideo",
    products: [
        .library(
            name: "SwiftVideo",
            targets: ["SwiftVideo"]),
    ],
    dependencies: [
        .package(name: "SwiftImage", url: "https://github.com/koher/swift-image.git", from: "0.7.1"),
    ],
    targets: [
        .target(
            name: "SwiftVideo",
            dependencies: ["SwiftImage"]),
        .testTarget(
            name: "SwiftVideoTests",
            dependencies: ["SwiftVideo", "SwiftImage"]),
    ]
)
