// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WatsonChat",
    platforms: [
        .macOS("15.0") // 현재 실제 SDK 상한선을 고려하여 15.0(Sequoia) 이상으로 설정하되, 요구하신 Tahoe 환경을 타겟팅합니다.
    ],
    products: [
        .executable(name: "WatsonChat", targets: ["WatsonChat"])
    ],
    dependencies: [
        .package(url: "https://github.com/ml-explore/mlx-swift.git", branch: "main")
    ],
    targets: [
        .executableTarget(
            name: "WatsonChat",
            dependencies: [
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXRandom", package: "mlx-swift"),
                .product(name: "MLXNN", package: "mlx-swift")
            ],
            path: "Sources/WatsonChat"
        )
    ]
)
