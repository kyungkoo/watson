import Foundation

public struct GenerationOptions: Sendable, Hashable {
    public var maxTokens: Int
    public var temperature: Float
    public var topP: Float
    public var repetitionPenalty: Float
    public var flushIntervalSeconds: TimeInterval
    public var flushTokenThreshold: Int
    public var promptOptions: PromptFormatter.GemmaOptions

    public init(
        maxTokens: Int,
        temperature: Float = 0.0,
        topP: Float = 1.0,
        repetitionPenalty: Float = 1.0,
        flushIntervalSeconds: TimeInterval = 0.03,
        flushTokenThreshold: Int = 8,
        promptOptions: PromptFormatter.GemmaOptions = .default
    ) {
        self.maxTokens = max(1, maxTokens)
        self.temperature = max(0.0, temperature)
        self.topP = min(1.0, max(0.0, topP))
        self.repetitionPenalty = max(1.0, repetitionPenalty)
        self.flushIntervalSeconds = max(0.005, flushIntervalSeconds)
        self.flushTokenThreshold = max(1, flushTokenThreshold)
        self.promptOptions = promptOptions
    }
}
