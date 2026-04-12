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
    func loadModel(
        config: ModelConfiguration,
        onStateChange: @Sendable @escaping (ModelLoadState) -> Void
    ) async throws
    func generate(messages: [ChatMessage], options: GenerationOptions) async throws -> AsyncThrowingStream<String, Error>
    func unload() async
}

public extension InferenceProvider {
    func loadModel(
        config: ModelConfiguration,
        onStateChange: @Sendable @escaping (ModelLoadState) -> Void
    ) async throws {
        try await loadModel(config: config)
    }

    func generate(
        messages: [ChatMessage],
        maxTokens: Int
    ) async throws -> AsyncThrowingStream<String, Error> {
        try await generate(messages: messages, options: GenerationOptions(maxTokens: maxTokens))
    }
}
