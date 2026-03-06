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
    dependencies: [
        .package(url: "https://github.com/RevenueCat/purchases-ios.git", from: "5.0.0")
    ],
    targets: [
        .target(
            name: "StackTracker",
            dependencies: [
                .product(name: "RevenueCat", package: "purchases-ios")
            ],
            path: "StackTracker",
            resources: [
                .process("Assets.xcassets")
            ]
        )
    ]
)
