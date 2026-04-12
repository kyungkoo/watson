import Foundation
import WatsonDomain

public enum MLXProviderFactory {
    public static func makeProvider(for kind: ProviderKind) -> any InferenceProvider {
        switch kind {
        case .mlxNative:
            return MLXNativeInferenceProvider()
        }
    }
}

public actor MLXNativeInferenceProvider: InferenceProvider {
    private var engine = MLXEngine()
    private var loadedConfiguration: ModelConfiguration?

    public init() {}

    public nonisolated func supports(config: ModelConfiguration) -> Bool {
        config.providerKind == .mlxNative && config.format == .gemma4
    }

    public func loadModel(config: ModelConfiguration) async throws {
        try await loadModel(config: config, onStateChange: { _ in })
    }

    public func loadModel(
        config: ModelConfiguration,
        onStateChange: @Sendable @escaping (ModelLoadState) -> Void
    ) async throws {
        guard supports(config: config) else {
            throw InferenceProviderError.unsupportedConfiguration(config)
        }

        try await engine.loadModel(config: config, onStateChange: onStateChange)
        loadedConfiguration = config
    }

    public func generate(
        messages: [ChatMessage],
        options: GenerationOptions
    ) async throws -> AsyncThrowingStream<String, Error> {
        guard let loadedConfiguration else {
            throw InferenceProviderError.modelNotLoaded
        }

        let prompt: String
        switch loadedConfiguration.format {
        case .gemma4:
            prompt = PromptFormatter.formatGemma(messages: messages, options: options.promptOptions)
        case .llama3:
            throw InferenceProviderError.unsupportedPromptFormat(loadedConfiguration.format)
        }

        return await engine.generate(prompt: prompt, options: options)
    }

    public func unload() async {
        engine = MLXEngine()
        loadedConfiguration = nil
    }
}
