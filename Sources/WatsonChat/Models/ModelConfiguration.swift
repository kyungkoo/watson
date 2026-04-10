import Foundation

public enum ProviderKind: String, Sendable, Hashable, CaseIterable {
    case mlxNative
}

public enum PromptFormat: Sendable, Hashable {
    case gemma4
    case llama3
}

public struct ModelConfiguration: Identifiable, Sendable, Hashable {
    public let id: String
    public let modelPathOrID: String
    public let providerKind: ProviderKind
    public let format: PromptFormat
    public let maxTokens: Int
    
    // Gemma 4 파생 모델들 정의
    public static let gemma4_E2B = ModelConfiguration(
        id: "Gemma 4 E2B",
        modelPathOrID: "google/gemma-4-e2b-it", // 예시 레포지토리 ID
        providerKind: .mlxNative,
        format: .gemma4,
        maxTokens: 4096
    )
    
    public static let gemma4_E4B = ModelConfiguration(
        id: "Gemma 4 E4B",
        modelPathOrID: "google/gemma-4-e4b-it",
        providerKind: .mlxNative,
        format: .gemma4,
        maxTokens: 8192
    )
    
    public static let availableModels: [ModelConfiguration] = [.gemma4_E2B, .gemma4_E4B]
}
