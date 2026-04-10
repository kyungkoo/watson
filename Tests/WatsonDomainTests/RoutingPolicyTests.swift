import XCTest
@testable import WatsonDomain

final class RoutingPolicyTests: XCTestCase {
    func test_complexUserMessage_prefersE4B() {
        let policy = RoutingPolicy(
            longRequestCharacterThreshold: 40,
            longConversationCharacterThreshold: 200,
            longConversationMessageThreshold: 8,
            switchStreakThreshold: 2
        )

        let recommended = policy.recommendedModel(
            forUserText: String(repeating: "복잡", count: 20),
            messages: []
        )

        XCTAssertEqual(recommended, .gemma4_E4B)
    }

    func test_shortRequest_prefersE2B() {
        let policy = RoutingPolicy(
            longRequestCharacterThreshold: 80,
            longConversationCharacterThreshold: 300,
            longConversationMessageThreshold: 10,
            switchStreakThreshold: 2
        )

        let recommended = policy.recommendedModel(
            forUserText: "간단히 설명해줘",
            messages: [ChatMessage(role: .assistant, content: "알겠습니다.")]
        )

        XCTAssertEqual(recommended, .gemma4_E2B)
    }
}
