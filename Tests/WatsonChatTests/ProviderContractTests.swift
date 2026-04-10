import XCTest
@testable import WatsonChat

final class ProviderContractTests: XCTestCase {
    func test_gemmaModels_expressExplicitProviderSelectionIntent() {
        XCTAssertEqual(ModelConfiguration.gemma4_E2B.providerKind, .mlxNative)
        XCTAssertEqual(ModelConfiguration.gemma4_E4B.providerKind, .mlxNative)
        XCTAssertEqual(ModelConfiguration.gemma4_26B_A4B.providerKind, .mlxNative)

        XCTAssertEqual(ModelConfiguration.gemma4_E2B.format, .gemma4)
        XCTAssertEqual(ModelConfiguration.gemma4_E4B.format, .gemma4)
        XCTAssertEqual(ModelConfiguration.gemma4_26B_A4B.format, .gemma4)

        XCTAssertEqual(ModelConfiguration.gemma4_E2B.architecture, .dense)
        XCTAssertEqual(ModelConfiguration.gemma4_E4B.architecture, .dense)
        XCTAssertEqual(ModelConfiguration.gemma4_26B_A4B.architecture, .moe)

        XCTAssertEqual(ModelConfiguration.gemma4_E2B.quantizationHint, .none)
        XCTAssertEqual(ModelConfiguration.gemma4_E4B.quantizationHint, .none)
        XCTAssertEqual(ModelConfiguration.gemma4_26B_A4B.quantizationHint, .a4b)

        XCTAssertEqual(ModelConfiguration.gemma4_E2B.recommendedContextWindow, 131_072)
        XCTAssertEqual(ModelConfiguration.gemma4_E4B.recommendedContextWindow, 131_072)
        XCTAssertEqual(ModelConfiguration.gemma4_26B_A4B.recommendedContextWindow, 262_144)
    }

    func test_availableModels_includesGemma426BA4BEntry() {
        XCTAssertEqual(
            ModelConfiguration.availableModels.map(\.id),
            [
                "Gemma 4 E2B",
                "Gemma 4 E4B",
                "Gemma 4 26B A4B"
            ]
        )
    }

    func test_mockProvider_supportsLoadGenerateAndUnloadContract() async throws {
        let provider = MockInferenceProvider()
        let supportedConfiguration = ModelConfiguration(
            id: "Fixture",
            modelPathOrID: "local/fixture",
            providerKind: .mlxNative,
            format: .gemma4,
            architecture: .dense,
            quantizationHint: .none,
            recommendedContextWindow: 131_072,
            maxTokens: 3
        )
        let unsupportedConfiguration = ModelConfiguration(
            id: "Fixture",
            modelPathOrID: "local/fixture",
            providerKind: .mlxNative,
            format: .llama3,
            architecture: .dense,
            quantizationHint: .none,
            recommendedContextWindow: 131_072,
            maxTokens: 3
        )

        XCTAssertTrue(provider.supports(config: supportedConfiguration))
        XCTAssertFalse(provider.supports(config: unsupportedConfiguration))

        do {
            _ = try await provider.generate(
                messages: [ChatMessage(role: .user, content: "Hi")],
                maxTokens: 2
            )
            XCTFail("Expected modelNotLoaded before loadModel")
        } catch InferenceProviderError.modelNotLoaded {
        } catch {
            XCTFail("Expected modelNotLoaded before loadModel, got \(error)")
        }

        do {
            try await provider.loadModel(config: unsupportedConfiguration)
            XCTFail("Expected unsupportedConfiguration for llama3 fixture")
        } catch InferenceProviderError.unsupportedConfiguration(let returnedConfiguration) {
            XCTAssertEqual(returnedConfiguration, unsupportedConfiguration)
        } catch {
            XCTFail("Expected unsupportedConfiguration for llama3 fixture, got \(error)")
        }

        try await provider.loadModel(config: supportedConfiguration)

        let messages = [
            ChatMessage(role: .system, content: "Keep answers concise."),
            ChatMessage(role: .user, content: "Explain the contract."),
        ]
        let stream = try await provider.generate(messages: messages, maxTokens: 3)
        let tokens = try await collectTokens(from: stream)

        XCTAssertEqual(tokens, ["token-1", "token-2", "token-3"])

        let afterGenerateState = await provider.state()
        XCTAssertEqual(afterGenerateState.lifecycle, ["load", "generate"])
        XCTAssertEqual(afterGenerateState.loadedConfiguration, supportedConfiguration)
        XCTAssertEqual(afterGenerateState.lastGeneratedMessages, messages)
        XCTAssertEqual(afterGenerateState.lastGeneratedMaxTokens, 3)

        await provider.unload()

        let afterUnloadState = await provider.state()
        XCTAssertEqual(afterUnloadState.lifecycle, ["load", "generate", "unload"])
        XCTAssertNil(afterUnloadState.loadedConfiguration)

        do {
            _ = try await provider.generate(
                messages: [ChatMessage(role: .user, content: "Again")],
                maxTokens: 1
            )
            XCTFail("Expected modelNotLoaded after unload")
        } catch InferenceProviderError.modelNotLoaded {
        } catch {
            XCTFail("Expected modelNotLoaded after unload, got \(error)")
        }
    }
}

private actor MockInferenceProvider: InferenceProvider {
    private var lifecycle: [String] = []
    private var loadedConfiguration: ModelConfiguration?
    private var lastGeneratedMessages: [ChatMessage] = []
    private var lastGeneratedMaxTokens: Int?

    nonisolated func supports(config: ModelConfiguration) -> Bool {
        config.providerKind == .mlxNative && config.format == .gemma4
    }

    func loadModel(config: ModelConfiguration) async throws {
        guard supports(config: config) else {
            throw InferenceProviderError.unsupportedConfiguration(config)
        }

        lifecycle.append("load")
        loadedConfiguration = config
    }

    func generate(
        messages: [ChatMessage],
        maxTokens: Int
    ) async throws -> AsyncThrowingStream<String, Error> {
        guard loadedConfiguration != nil else {
            throw InferenceProviderError.modelNotLoaded
        }

        lifecycle.append("generate")
        lastGeneratedMessages = messages
        lastGeneratedMaxTokens = maxTokens

        return AsyncThrowingStream { continuation in
            for tokenIndex in 1...maxTokens {
                continuation.yield("token-\(tokenIndex)")
            }
            continuation.finish()
        }
    }

    func unload() async {
        lifecycle.append("unload")
        loadedConfiguration = nil
    }

    func state() -> State {
        State(
            lifecycle: lifecycle,
            loadedConfiguration: loadedConfiguration,
            lastGeneratedMessages: lastGeneratedMessages,
            lastGeneratedMaxTokens: lastGeneratedMaxTokens
        )
    }

    struct State: Sendable {
        let lifecycle: [String]
        let loadedConfiguration: ModelConfiguration?
        let lastGeneratedMessages: [ChatMessage]
        let lastGeneratedMaxTokens: Int?
    }
}

private func collectTokens(from stream: AsyncThrowingStream<String, Error>) async throws -> [String] {
    var tokens: [String] = []
    for try await token in stream {
        tokens.append(token)
    }
    return tokens
}
