// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "rekvizit",
    products: [
        .library(name: "Rekvizit", targets: ["Rekvizit"]),
        .executable(name: "rekvizit", targets: ["RekvizitCLI"]),
    ],
    targets: [
        .target(name: "Rekvizit"),
        .executableTarget(name: "RekvizitCLI", dependencies: ["Rekvizit"]),
        .testTarget(name: "RekvizitTests", dependencies: ["Rekvizit"]),
    ]
)
