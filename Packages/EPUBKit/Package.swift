// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "EPUBKit",
    platforms: [
        .iOS(.v26),
        .macOS(.v26)
    ],
    products: [
        .library(name: "EPUBKit", targets: ["EPUBKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation", from: "0.9.20")
    ],
    targets: [
        .target(
            name: "EPUBKit",
            dependencies: [
                .product(name: "ZIPFoundation", package: "ZIPFoundation")
            ]
        )
    ]
)
