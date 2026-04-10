import Foundation

public enum InferenceProviderError: LocalizedError {
    case unsupportedConfiguration(ModelConfiguration)
    case unsupportedPromptFormat(PromptFormat)
    case modelNotLoaded

    public var errorDescription: String? {
        switch self {
        case .unsupportedConfiguration(let config):
            return "\(config.id)은(는) 현재 선택된 provider에서 지원되지 않습니다."
        case .unsupportedPromptFormat(let format):
            return "지원되지 않는 프롬프트 형식입니다: \(String(describing: format))"
        case .modelNotLoaded:
            return "모델이 아직 로드되지 않았습니다."
        }
    }
}

public protocol InferenceProvider: Sendable {
    func supports(config: ModelConfiguration) -> Bool
    func loadModel(config: ModelConfiguration) async throws
    func generate(messages: [ChatMessage], maxTokens: Int) async throws -> AsyncThrowingStream<String, Error>
    func unload() async
}

public enum InferenceProviderFactory {
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
        guard supports(config: config) else {
            throw InferenceProviderError.unsupportedConfiguration(config)
        }

        try await engine.loadModel(config: config)
        loadedConfiguration = config
    }

    public func generate(
        messages: [ChatMessage],
        maxTokens: Int
    ) async throws -> AsyncThrowingStream<String, Error> {
        guard let loadedConfiguration else {
            throw InferenceProviderError.modelNotLoaded
        }

        let prompt: String
        switch loadedConfiguration.format {
        case .gemma4:
            prompt = PromptFormatter.formatGemma(messages: messages)
        case .llama3:
            throw InferenceProviderError.unsupportedPromptFormat(loadedConfiguration.format)
        }

        return await engine.generate(prompt: prompt, maxTokens: maxTokens)
    }

    public func unload() async {
        engine = MLXEngine()
        loadedConfiguration = nil
    }
}
