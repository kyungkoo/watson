import XCTest
@testable import WatsonChat

final class Gemma4SmokeTests: XCTestCase {
    func test_gemma4E2B_loadsAndGeneratesShortKoreanText() async throws {
        guard ProcessInfo.processInfo.environment["WATSON_RUN_GEMMA4_SMOKE"] == "1" else {
            throw XCTSkip("WATSON_RUN_GEMMA4_SMOKE=1 환경에서만 실행합니다.")
        }
        guard hasAccessibleMetalLibrary() else {
            throw XCTSkip("MLX Metal 라이브러리를 찾지 못해 스모크 테스트를 건너뜁니다.")
        }

        let provider = MLXNativeInferenceProvider()
        let config = ModelConfiguration.gemma4_E2B

        XCTAssertTrue(provider.supports(config: config))

        try await provider.loadModel(config: config)

        let stream = try await provider.generate(
            messages: [ChatMessage(role: .user, content: "안녕")],
            maxTokens: 24
        )

        var generated = ""
        for try await token in stream {
            generated += token
        }

        await provider.unload()
        XCTAssertFalse(generated.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private func hasAccessibleMetalLibrary() -> Bool {
        let executableDirectory = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
        let workingDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let candidatePaths: [URL] = [
            executableDirectory.appendingPathComponent("mlx.metallib"),
            executableDirectory.appendingPathComponent("Resources/mlx.metallib"),
            executableDirectory.appendingPathComponent("default.metallib"),
            executableDirectory.appendingPathComponent("Resources/default.metallib"),
            workingDirectory.appendingPathComponent("default.metallib")
        ]

        let fileManager = FileManager.default
        return candidatePaths.contains(where: { fileManager.fileExists(atPath: $0.path) })
    }
}
