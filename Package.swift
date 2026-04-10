// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "WatsonChat",
    platforms: [
        .macOS("15.0")
    ],
    products: [
        .executable(name: "WatsonChat", targets: ["WatsonChat"])
    ],
    dependencies: [
        .package(url: "https://github.com/ml-explore/mlx-swift.git", branch: "main"),
        .package(url: "https://github.com/DePasqualeOrg/swift-tokenizers-mlx.git", branch: "main"),
        .package(url: "https://github.com/DePasqualeOrg/swift-hf-api-mlx.git", branch: "main")
    ],
    targets: [
        .executableTarget(
            name: "WatsonChat",
            dependencies: [
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXRandom", package: "mlx-swift"),
                .product(name: "MLXNN", package: "mlx-swift"),
                .product(name: "MLXLMTokenizers", package: "swift-tokenizers-mlx"),
                .product(name: "MLXLMHFAPI", package: "swift-hf-api-mlx")
            ],
            path: "Sources/WatsonChat"
        ),
        .testTarget(
            name: "WatsonChatTests",
            dependencies: ["WatsonChat"],
            path: "Tests/WatsonChatTests"
        )
    ]
)
