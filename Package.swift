// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "unibrain",
    platforms: [
        .macOS(.v15),
        .iOS(.v17),
    ],
    products: [
        .library(name: "UnibrainCore", targets: ["UnibrainCore"]),
        .library(name: "UnibrainProviders", targets: ["UnibrainProviders"]),
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "6.2.2"),
    ],
    targets: [
        .target(
            name: "UnibrainCore",
            dependencies: [
                .product(name: "Yams", package: "Yams"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .target(
            name: "UnibrainProviders",
            dependencies: ["UnibrainCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "UnibrainCoreTests",
            dependencies: ["UnibrainCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "UnibrainProvidersTests",
            dependencies: ["UnibrainCore", "UnibrainProviders"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)
