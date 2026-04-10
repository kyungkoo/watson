import XCTest
@testable import WatsonChat

final class PromptFormatterTests: XCTestCase {
    func test_userAndAssistantRoles_renderGemmaTurnBlocks() {
        let messages = [
            ChatMessage(role: .user, content: "Hello"),
            ChatMessage(role: .assistant, content: "Hi there")
        ]

        let prompt = PromptFormatter.formatGemma(messages: messages)
        let expected = "<|turn>user\nHello<turn|>\n<|turn>model\nHi there<turn|>\n<|turn>model\n"

        XCTAssertEqual(prompt, expected)
    }

    func test_finalPrompt_endsWithOpenAssistantTurnMarker() {
        let prompt = PromptFormatter.formatGemma(messages: [
            ChatMessage(role: .user, content: "Question?")
        ])

        XCTAssertTrue(prompt.hasSuffix("<|turn>model\n"))
    }

    func test_systemRole_mapsIntoUserRoleBlock() {
        let prompt = PromptFormatter.formatGemma(messages: [
            ChatMessage(role: .system, content: "You are helpful.")
        ])
        let expected = "<|turn>user\nYou are helpful.<turn|>\n<|turn>model\n"

        XCTAssertEqual(prompt, expected)
    }
}
