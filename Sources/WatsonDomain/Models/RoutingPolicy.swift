import Foundation

public enum ModelRoutingLock: String, Sendable, Hashable, CaseIterable {
    case none
    case forceE2B
    case forceE4B

    public var targetModel: ModelConfiguration? {
        switch self {
        case .none:
            return nil
        case .forceE2B:
            return .gemma4_E2B
        case .forceE4B:
            return .gemma4_E4B
        }
    }
}

public struct RoutingPolicy: Sendable, Hashable {
    public static let balanced = RoutingPolicy()

    public var longRequestCharacterThreshold: Int
    public var longConversationCharacterThreshold: Int
    public var longConversationMessageThreshold: Int
    public var switchStreakThreshold: Int

    public init(
        longRequestCharacterThreshold: Int = 320,
        longConversationCharacterThreshold: Int = 2_200,
        longConversationMessageThreshold: Int = 10,
        switchStreakThreshold: Int = 2
    ) {
        self.longRequestCharacterThreshold = max(1, longRequestCharacterThreshold)
        self.longConversationCharacterThreshold = max(1, longConversationCharacterThreshold)
        self.longConversationMessageThreshold = max(1, longConversationMessageThreshold)
        self.switchStreakThreshold = max(1, switchStreakThreshold)
    }

    public func recommendedModel(forUserText text: String, messages: [ChatMessage]) -> ModelConfiguration {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let conversationMessages = messages.filter { $0.role != .system }
        let conversationCharacters = conversationMessages.reduce(into: 0) { partialResult, message in
            partialResult += message.content.count
        }

        let isLongRequest = normalized.count >= longRequestCharacterThreshold
        let isLongConversation = conversationCharacters + normalized.count >= longConversationCharacterThreshold
            || conversationMessages.count >= longConversationMessageThreshold

        return (isLongRequest || isLongConversation) ? .gemma4_E4B : .gemma4_E2B
    }
}
