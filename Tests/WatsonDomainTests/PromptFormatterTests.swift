import XCTest
@testable import WatsonDomain

final class PromptFormatterTests: XCTestCase {
    func test_userAndAssistantRoles_renderGemmaTurnBlocks() {
        let messages = [
            ChatMessage(role: .user, content: "Hello"),
            ChatMessage(role: .assistant, content: "Hi there")
        ]

        let prompt = PromptFormatter.formatGemma(
            messages: messages,
            options: .init(defaultSystemInstruction: "")
        )
        let expected = "<|turn>user\nHello<turn|>\n<|turn>model\nHi there<turn|>\n<|turn>model\n"

        XCTAssertEqual(prompt, expected)
    }

    func test_finalPrompt_endsWithOpenAssistantTurnMarker() {
        let prompt = PromptFormatter.formatGemma(
            messages: [
                ChatMessage(role: .user, content: "Question?")
            ],
            options: .init(defaultSystemInstruction: "")
        )

        XCTAssertTrue(prompt.hasSuffix("<|turn>model\n"))
    }

    func test_systemRole_mapsIntoUserRoleBlock() {
        let prompt = PromptFormatter.formatGemma(
            messages: [
                ChatMessage(role: .system, content: "You are helpful.")
            ],
            options: .init(defaultSystemInstruction: "")
        )
        let expected = "<|turn>user\nYou are helpful.<turn|>\n<|turn>model\n"

        XCTAssertEqual(prompt, expected)
    }

    func test_customDefaultSystemInstruction_isPrependedBeforeConversation() {
        let options = PromptFormatter.GemmaOptions(
            defaultSystemInstruction: "규칙: 요구사항을 빠짐없이 따르세요.",
            contextBudgetCharacters: 2_000,
            recentMessagesToKeep: 6,
            summaryCharacterLimit: 240
        )
        let prompt = PromptFormatter.formatGemma(
            messages: [
                ChatMessage(role: .user, content: "요약해줘")
            ],
            options: options
        )

        XCTAssertTrue(prompt.contains("<|turn>user\n규칙: 요구사항을 빠짐없이 따르세요.<turn|>\n"))
        XCTAssertTrue(prompt.contains("<|turn>user\n요약해줘<turn|>\n"))
        XCTAssertTrue(prompt.hasSuffix("<|turn>model\n"))
    }

    func test_defaultSystemInstruction_includesDirectAnswerAndRichResponseGuidance() {
        let prompt = PromptFormatter.formatGemma(
            messages: [
                ChatMessage(role: .user, content: "10 - 10 = ?")
            ]
        )

        XCTAssertTrue(prompt.contains("질문이 명확한 경우(예: 단순 산술)는 확인 질문 없이 바로 간결하게 답하세요."))
        XCTAssertTrue(prompt.contains("설명이나 비교를 요청받으면 결론만 짧게 말하지 말고 이유, 예시, 대안을 함께 제시하세요."))
    }

    func test_longConversation_appliesContextCompressionWithSummary() {
        let oldUser = String(repeating: "오래된질문", count: 60)
        let oldAssistant = String(repeating: "오래된답변", count: 60)
        let newUser = String(repeating: "최신질문", count: 20)
        let newAssistant = String(repeating: "최신답변", count: 20)

        let messages: [ChatMessage] = [
            ChatMessage(role: .user, content: oldUser),
            ChatMessage(role: .assistant, content: oldAssistant),
            ChatMessage(role: .user, content: oldUser),
            ChatMessage(role: .assistant, content: oldAssistant),
            ChatMessage(role: .user, content: newUser),
            ChatMessage(role: .assistant, content: newAssistant),
            ChatMessage(role: .user, content: newUser)
        ]

        let options = PromptFormatter.GemmaOptions(
            defaultSystemInstruction: "지시를 정확히 따르세요.",
            contextBudgetCharacters: 500,
            recentMessagesToKeep: 4,
            summaryCharacterLimit: 160
        )

        let prompt = PromptFormatter.formatGemma(messages: messages, options: options)

        XCTAssertTrue(prompt.contains("[대화 요약]"))
        XCTAssertTrue(prompt.contains("사용자 맥락:"))
        XCTAssertTrue(prompt.contains(newUser))
        XCTAssertFalse(prompt.contains(oldUser + oldUser))
    }

    func test_summaryMessage_usesStructuredSectionsWhenBudgetAllows() {
        let oldUser = String(repeating: "오래된 요구사항 ", count: 40)
        let oldAssistant = String(repeating: "기존 응답 요약 ", count: 40)
        let messages: [ChatMessage] = [
            ChatMessage(role: .user, content: oldUser),
            ChatMessage(role: .assistant, content: oldAssistant),
            ChatMessage(role: .user, content: oldUser),
            ChatMessage(role: .assistant, content: "좋아"),
            ChatMessage(role: .user, content: "추천")
        ]

        let options = PromptFormatter.GemmaOptions(
            defaultSystemInstruction: "지시를 정확히 따르세요.",
            contextBudgetCharacters: 512,
            recentMessagesToKeep: 2,
            summaryCharacterLimit: 280
        )

        let prompt = PromptFormatter.formatGemma(messages: messages, options: options)

        XCTAssertTrue(prompt.contains("[대화 요약]"))
        XCTAssertTrue(prompt.contains("사용자 맥락:"))
        XCTAssertTrue(prompt.contains("이미 도출된 내용:"))
    }
}
