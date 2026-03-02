// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StackTracker",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "StackTracker",
            targets: ["StackTracker"]
        )
    ],
    targets: [
        .target(
            name: "StackTracker",
            path: "StackTracker",
            resources: [
                .process("Assets.xcassets")
            ]
        )
    ]
)
