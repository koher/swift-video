// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "EasyMoviy",
    products: [
        .library(
            name: "EasyMoviy",
            targets: ["EasyMoviy"]),
    ],
    dependencies: [
        .package(url: "https://github.com/koher/EasyImagy.git", from: "0.5.0"),
    ],
    targets: [
        .target(
            name: "EasyMoviy",
            dependencies: ["EasyImagy"]),
        .testTarget(
            name: "EasyMoviyTests",
            dependencies: ["EasyMoviy", "EasyImagy"]),
    ]
)
