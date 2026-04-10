import Foundation

public enum ProviderKind: String, Sendable, Hashable, CaseIterable {
    case mlxNative
}

public enum PromptFormat: Sendable, Hashable {
    case gemma4
    case llama3
}

public struct ModelConfiguration: Identifiable, Sendable, Hashable {
    public enum Architecture: String, Sendable, Hashable {
        case dense
        case moe
    }

    public enum QuantizationHint: String, Sendable, Hashable {
        case none
        case a4b
    }

    public let id: String
    public let modelPathOrID: String
    public let providerKind: ProviderKind
    public let format: PromptFormat
    public let architecture: Architecture
    public let quantizationHint: QuantizationHint
    public let recommendedContextWindow: Int
    public let maxTokens: Int

    public init(
        id: String,
        modelPathOrID: String,
        providerKind: ProviderKind,
        format: PromptFormat,
        architecture: Architecture = .dense,
        quantizationHint: QuantizationHint = .none,
        recommendedContextWindow: Int = 131_072,
        maxTokens: Int
    ) {
        self.id = id
        self.modelPathOrID = modelPathOrID
        self.providerKind = providerKind
        self.format = format
        self.architecture = architecture
        self.quantizationHint = quantizationHint
        self.recommendedContextWindow = recommendedContextWindow
        self.maxTokens = maxTokens
    }

    // Gemma 4 파생 모델들 정의
    public static let gemma4_E2B = ModelConfiguration(
        id: "Gemma 4 E2B",
        modelPathOrID: "google/gemma-4-e2b-it",
        providerKind: .mlxNative,
        format: .gemma4,
        architecture: .dense,
        quantizationHint: .none,
        recommendedContextWindow: 131_072,
        maxTokens: 4096
    )

    public static let gemma4_E4B = ModelConfiguration(
        id: "Gemma 4 E4B",
        modelPathOrID: "google/gemma-4-e4b-it",
        providerKind: .mlxNative,
        format: .gemma4,
        architecture: .dense,
        quantizationHint: .none,
        recommendedContextWindow: 131_072,
        maxTokens: 8192
    )

    public static let gemma4_26B_A4B = ModelConfiguration(
        id: "Gemma 4 26B A4B",
        modelPathOrID: "google/gemma-4-26B-A4B-it",
        providerKind: .mlxNative,
        format: .gemma4,
        architecture: .moe,
        quantizationHint: .a4b,
        recommendedContextWindow: 262_144,
        maxTokens: 8192
    )

    public static let availableModels: [ModelConfiguration] = [
        .gemma4_E2B,
        .gemma4_E4B,
        .gemma4_26B_A4B
    ]
}
