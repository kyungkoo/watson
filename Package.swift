// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "WatsonChat",
    platforms: [
        .macOS("15.0")
    ],
    products: [
        .library(name: "WatsonDomain", targets: ["WatsonDomain"]),
        .library(name: "WatsonAppCore", targets: ["WatsonAppCore"]),
        .library(name: "WatsonMLX", targets: ["WatsonMLX"]),
        .executable(name: "WatsonChat", targets: ["WatsonChat"])
    ],
    dependencies: [
        .package(url: "https://github.com/ml-explore/mlx-swift.git", branch: "main"),
        .package(url: "https://github.com/DePasqualeOrg/swift-tokenizers-mlx.git", branch: "main"),
        .package(url: "https://github.com/DePasqualeOrg/swift-hf-api-mlx.git", branch: "main")
    ],
    targets: [
        .target(
            name: "WatsonDomain",
            path: "Sources/WatsonDomain"
        ),
        .target(
            name: "WatsonAppCore",
            dependencies: ["WatsonDomain"],
            path: "Sources/WatsonAppCore"
        ),
        .target(
            name: "WatsonMLX",
            dependencies: [
                "WatsonDomain",
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXRandom", package: "mlx-swift"),
                .product(name: "MLXNN", package: "mlx-swift"),
                .product(name: "MLXLMTokenizers", package: "swift-tokenizers-mlx"),
                .product(name: "MLXLMHFAPI", package: "swift-hf-api-mlx")
            ],
            path: "Sources/WatsonMLX"
        ),
        .executableTarget(
            name: "WatsonChat",
            dependencies: [
                "WatsonDomain",
                "WatsonAppCore",
                "WatsonMLX"
            ],
            path: "Sources/WatsonChat"
        ),
        .testTarget(
            name: "WatsonDomainTests",
            dependencies: ["WatsonDomain"],
            path: "Tests/WatsonDomainTests"
        ),
        .testTarget(
            name: "WatsonAppCoreTests",
            dependencies: ["WatsonAppCore", "WatsonDomain"],
            path: "Tests/WatsonAppCoreTests"
        ),
        .testTarget(
            name: "WatsonMLXTests",
            dependencies: ["WatsonMLX", "WatsonDomain"],
            path: "Tests/WatsonMLXTests"
        )
    ]
)
