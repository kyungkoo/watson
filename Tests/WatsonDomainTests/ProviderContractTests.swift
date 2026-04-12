import XCTest
@testable import WatsonDomain

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

        XCTAssertEqual(ModelConfiguration.gemma4_E2B.maxTokens, 4_096)
        XCTAssertEqual(ModelConfiguration.gemma4_E4B.maxTokens, 2_048)
        XCTAssertEqual(ModelConfiguration.gemma4_26B_A4B.maxTokens, 8_192)
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

        let afterDefaultGenerateState = await provider.state()
        XCTAssertEqual(afterDefaultGenerateState.lifecycle, ["load", "generate"])
        XCTAssertEqual(afterDefaultGenerateState.loadedConfiguration, supportedConfiguration)
        XCTAssertEqual(afterDefaultGenerateState.lastGeneratedMessages, messages)
        XCTAssertEqual(afterDefaultGenerateState.lastGeneratedMaxTokens, 3)
        XCTAssertEqual(afterDefaultGenerateState.lastGenerationOptions?.temperature, 0.0)
        XCTAssertEqual(afterDefaultGenerateState.lastGenerationOptions?.topP, 1.0)
        XCTAssertEqual(afterDefaultGenerateState.lastGenerationOptions?.repetitionPenalty, 1.0)

        let customOptions = GenerationOptions(
            maxTokens: 2,
            temperature: 0.35,
            topP: 0.88,
            repetitionPenalty: 1.12
        )
        let customStream = try await provider.generate(messages: messages, options: customOptions)
        let customTokens = try await collectTokens(from: customStream)
        XCTAssertEqual(customTokens, ["token-1", "token-2"])

        let afterCustomGenerateState = await provider.state()
        XCTAssertEqual(afterCustomGenerateState.lifecycle, ["load", "generate", "generate"])
        XCTAssertEqual(afterCustomGenerateState.lastGeneratedMaxTokens, 2)
        XCTAssertEqual(afterCustomGenerateState.lastGenerationOptions, customOptions)

        await provider.unload()

        let afterUnloadState = await provider.state()
        XCTAssertEqual(afterUnloadState.lifecycle, ["load", "generate", "generate", "unload"])
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

    func test_progressAwareLoadModel_defaultImplementationDelegatesToLegacyLoadMethod() async throws {
        let provider = LegacyOnlyMockInferenceProvider()
        let configuration = ModelConfiguration(
            id: "Fixture",
            modelPathOrID: "local/fixture",
            providerKind: .mlxNative,
            format: .gemma4,
            architecture: .dense,
            quantizationHint: .none,
            recommendedContextWindow: 131_072,
            maxTokens: 3
        )

        let emittedStates = RecordedLoadStates()
        try await provider.loadModel(config: configuration) { state in
            emittedStates.append(state)
        }

        let state = await provider.state()
        XCTAssertEqual(state.lifecycle, ["load"])
        XCTAssertEqual(state.loadedConfiguration, configuration)
        XCTAssertTrue(emittedStates.snapshot().isEmpty)
    }
}

private actor MockInferenceProvider: InferenceProvider {
    private var lifecycle: [String] = []
    private var loadedConfiguration: ModelConfiguration?
    private var lastGeneratedMessages: [ChatMessage] = []
    private var lastGeneratedMaxTokens: Int?
    private var lastGenerationOptions: GenerationOptions?

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
        options: GenerationOptions
    ) async throws -> AsyncThrowingStream<String, Error> {
        guard loadedConfiguration != nil else {
            throw InferenceProviderError.modelNotLoaded
        }

        lifecycle.append("generate")
        lastGeneratedMessages = messages
        lastGeneratedMaxTokens = options.maxTokens
        lastGenerationOptions = options

        return AsyncThrowingStream { continuation in
            for tokenIndex in 1...options.maxTokens {
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
            lastGeneratedMaxTokens: lastGeneratedMaxTokens,
            lastGenerationOptions: lastGenerationOptions
        )
    }

    struct State: Sendable {
        let lifecycle: [String]
        let loadedConfiguration: ModelConfiguration?
        let lastGeneratedMessages: [ChatMessage]
        let lastGeneratedMaxTokens: Int?
        let lastGenerationOptions: GenerationOptions?
    }
}

private actor LegacyOnlyMockInferenceProvider: InferenceProvider {
    private var lifecycle: [String] = []
    private var loadedConfiguration: ModelConfiguration?

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
        options: GenerationOptions
    ) async throws -> AsyncThrowingStream<String, Error> {
        guard loadedConfiguration != nil else {
            throw InferenceProviderError.modelNotLoaded
        }

        return AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }

    func unload() async {
        lifecycle.append("unload")
        loadedConfiguration = nil
    }

    func state() -> State {
        State(lifecycle: lifecycle, loadedConfiguration: loadedConfiguration)
    }

    struct State: Sendable {
        let lifecycle: [String]
        let loadedConfiguration: ModelConfiguration?
    }
}

private final class RecordedLoadStates: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [ModelLoadState] = []

    func append(_ state: ModelLoadState) {
        lock.lock()
        values.append(state)
        lock.unlock()
    }

    func snapshot() -> [ModelLoadState] {
        lock.lock()
        defer { lock.unlock() }
        return values
    }
}

private func collectTokens(from stream: AsyncThrowingStream<String, Error>) async throws -> [String] {
    var tokens: [String] = []
    for try await token in stream {
        tokens.append(token)
    }
    return tokens
}
