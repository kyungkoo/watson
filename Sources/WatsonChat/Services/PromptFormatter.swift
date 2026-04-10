import Foundation

public struct PromptFormatter: Sendable {

    /// 대화 배열을 Gemma 포맷의 단일 String으로 변환합니다.
    public static func formatGemma(messages: [ChatMessage]) -> String {
        var prompt = ""

        for message in messages {
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
}
