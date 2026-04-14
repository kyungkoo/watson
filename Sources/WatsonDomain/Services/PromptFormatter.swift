import Foundation

public struct PromptFormatter: Sendable {
    public struct GemmaOptions: Sendable, Hashable {
        public static let `default` = GemmaOptions()

        public var defaultSystemInstruction: String
        public var contextBudgetCharacters: Int
        public var recentMessagesToKeep: Int
        public var summaryCharacterLimit: Int

        public init(
            defaultSystemInstruction: String = """
            당신은 Watson Chat의 한국어 어시스턴트입니다.
            - 사용자의 요구사항을 누락하지 마세요.
            - 출력 형식/제약 조건이 있으면 우선 준수하세요.
            - 질문이 명확한 경우(예: 단순 산술)는 확인 질문 없이 바로 간결하게 답하세요.
            - 설명이나 비교를 요청받으면 결론만 짧게 말하지 말고 이유, 예시, 대안을 함께 제시하세요.
            - 확실하지 않은 내용은 추측하지 말고 불확실성을 명시하세요.
            """,
            contextBudgetCharacters: Int = 12_000,
            recentMessagesToKeep: Int = 8,
            summaryCharacterLimit: Int = 480
        ) {
            self.defaultSystemInstruction = defaultSystemInstruction
            self.contextBudgetCharacters = max(512, contextBudgetCharacters)
            self.recentMessagesToKeep = max(2, recentMessagesToKeep)
            self.summaryCharacterLimit = max(80, summaryCharacterLimit)
        }
    }

    /// 대화 배열을 Gemma 포맷의 단일 String으로 변환합니다.
    public static func formatGemma(
        messages: [ChatMessage],
        options: GemmaOptions = .default
    ) -> String {
        let normalizedMessages = messages.filter { !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let explicitSystemInstructions = normalizedMessages
            .filter { $0.role == .system }
            .map(\.content)
        let dialogueMessages = normalizedMessages.filter { $0.role != .system }
        let compressedDialogue = compressConversation(messages: dialogueMessages, options: options)

        var promptMessages: [ChatMessage] = []
        let mergedSystemInstruction = mergeSystemInstructions(
            defaultInstruction: options.defaultSystemInstruction,
            explicitInstructions: explicitSystemInstructions
        )
        if !mergedSystemInstruction.isEmpty {
            promptMessages.append(ChatMessage(role: .system, content: mergedSystemInstruction))
        }
        promptMessages.append(contentsOf: compressedDialogue)

        var prompt = ""

        for message in promptMessages {
            switch message.role {
            case .system:
                // Gemma 시스템 지시는 사용자 턴에 포함합니다.
                prompt += "<|turn>user\n\(message.content)<turn|>\n"
            case .user:
                prompt += "<|turn>user\n\(message.content)<turn|>\n"
            case .assistant:
                prompt += "<|turn>model\n\(message.content)<turn|>\n"
            }
        }

        // 마지막에는 모델의 답변을 유도하기 위해 모델 턴을 엽니다.
        prompt += "<|turn>model\n"
        return prompt
    }

    private static func mergeSystemInstructions(
        defaultInstruction: String,
        explicitInstructions: [String]
    ) -> String {
        let sections = [defaultInstruction] + explicitInstructions
        return sections
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    private static func compressConversation(
        messages: [ChatMessage],
        options: GemmaOptions
    ) -> [ChatMessage] {
        guard !messages.isEmpty else { return [] }

        let maxCharacters = options.contextBudgetCharacters
        if totalCharacters(in: messages) <= maxCharacters {
            return messages
        }

        let recentCount = min(options.recentMessagesToKeep, messages.count)
        let recentMessages = Array(messages.suffix(recentCount))
        let olderMessages = Array(messages.dropLast(recentCount))

        let summaryMessage = buildSummaryMessage(
            from: olderMessages,
            summaryCharacterLimit: options.summaryCharacterLimit
        )

        var reducedRecentMessages = recentMessages
        while totalCharacters(in: reducedRecentMessages) + summaryMessage.content.count > maxCharacters,
            reducedRecentMessages.count > 2
        {
            reducedRecentMessages.removeFirst()
        }

        if totalCharacters(in: reducedRecentMessages) + summaryMessage.content.count > maxCharacters {
            return reducedRecentMessages
        }

        return [summaryMessage] + reducedRecentMessages
    }

    private static func buildSummaryMessage(
        from messages: [ChatMessage],
        summaryCharacterLimit: Int
    ) -> ChatMessage {
        guard !messages.isEmpty else {
            return ChatMessage(role: .system, content: "[대화 요약]\n(이전 대화 없음)")
        }

        var lines: [String] = ["[대화 요약]"]
        var usedCharacters = lines[0].count
        let maxLineCharacters = 60

        let userContext = summaryEntries(
            from: messages,
            role: .user,
            maxEntries: 1,
            maxLineCharacters: maxLineCharacters
        )
        let assistantContext = summaryEntries(
            from: messages,
            role: .assistant,
            maxEntries: 1,
            maxLineCharacters: maxLineCharacters
        )
        let pendingUserRequest = latestPendingUserRequest(
            in: messages,
            maxLineCharacters: maxLineCharacters
        )

        appendSection(
            title: "사용자 맥락:",
            entries: userContext,
            lines: &lines,
            usedCharacters: &usedCharacters,
            summaryCharacterLimit: summaryCharacterLimit
        )
        appendSection(
            title: "이미 도출된 내용:",
            entries: assistantContext,
            lines: &lines,
            usedCharacters: &usedCharacters,
            summaryCharacterLimit: summaryCharacterLimit
        )

        if let pendingUserRequest, userContext.last != pendingUserRequest {
            appendSection(
                title: "남아 있는 사용자 요청:",
                entries: [pendingUserRequest],
                lines: &lines,
                usedCharacters: &usedCharacters,
                summaryCharacterLimit: summaryCharacterLimit
            )
        }

        if lines.count == 1 {
            lines.append("- (요약할 이전 대화가 없습니다)")
        }

        return ChatMessage(role: .system, content: lines.joined(separator: "\n"))
    }

    private static func summaryEntries(
        from messages: [ChatMessage],
        role: ChatMessage.Role,
        maxEntries: Int,
        maxLineCharacters: Int
    ) -> [String] {
        messages
            .filter { $0.role == role }
            .suffix(maxEntries)
            .compactMap { clippedSummaryLine(from: $0.content, maxLineCharacters: maxLineCharacters) }
    }

    private static func latestPendingUserRequest(
        in messages: [ChatMessage],
        maxLineCharacters: Int
    ) -> String? {
        guard messages.last?.role == .user else {
            return nil
        }

        return clippedSummaryLine(
            from: messages.last?.content ?? "",
            maxLineCharacters: maxLineCharacters
        )
    }

    private static func clippedSummaryLine(
        from text: String,
        maxLineCharacters: Int
    ) -> String? {
        let normalizedText = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedText.isEmpty else { return nil }

        let clippedText = String(normalizedText.prefix(maxLineCharacters))
        let suffix = normalizedText.count > maxLineCharacters ? "…" : ""
        return "- \(clippedText)\(suffix)"
    }

    private static func appendSection(
        title: String,
        entries: [String],
        lines: inout [String],
        usedCharacters: inout Int,
        summaryCharacterLimit: Int
    ) {
        guard !entries.isEmpty else { return }
        guard appendSummaryLine(
            title,
            lines: &lines,
            usedCharacters: &usedCharacters,
            summaryCharacterLimit: summaryCharacterLimit
        ) else {
            return
        }

        for entry in entries {
            guard appendSummaryLine(
                entry,
                lines: &lines,
                usedCharacters: &usedCharacters,
                summaryCharacterLimit: summaryCharacterLimit
            ) else {
                break
            }
        }
    }

    @discardableResult
    private static func appendSummaryLine(
        _ line: String,
        lines: inout [String],
        usedCharacters: inout Int,
        summaryCharacterLimit: Int
    ) -> Bool {
        let projectedCharacters = usedCharacters + line.count + 1
        guard projectedCharacters <= summaryCharacterLimit else {
            return false
        }

        lines.append(line)
        usedCharacters = projectedCharacters
        return true
    }

    private static func totalCharacters(in messages: [ChatMessage]) -> Int {
        messages.reduce(into: 0) { partialResult, message in
            partialResult += message.content.count
        }
    }
}
