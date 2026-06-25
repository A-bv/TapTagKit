// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TapTagKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "TapTagKit", targets: ["TapTagKit"]),
    ],
    targets: [
        .target(name: "TapTagKit", resources: [.process("Resources")]),
        .testTarget(name: "TapTagKitTests", dependencies: ["TapTagKit"]),
    ]
)
