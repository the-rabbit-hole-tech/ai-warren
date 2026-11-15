// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "__REPO_NAME__",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "__REPO_NAME__", targets: ["Core"]),
    ],
    targets: [
        .target(name: "Core"),
        .testTarget(name: "CoreTests", dependencies: ["Core"]),
    ]
)
