// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TapTagKit",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "TapTagKit", targets: ["TapTagKit"]),
    ],
    targets: [
        .target(name: "TapTagKit"),
        .testTarget(name: "TapTagKitTests", dependencies: ["TapTagKit"]),
    ]
)
