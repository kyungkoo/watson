import Foundation

public struct PromptFormatter: Sendable {
    
    /// 대화 배열을 Gemma 포맷의 단일 String으로 변환합니다.
    public static func formatGemma(messages: [ChatMessage]) -> String {
        var prompt = ""
        
        // BOS (Begin of Sequence) 토큰으로 시작하는 것이 권장됩니다.
        for message in messages {
            switch message.role {
            case .system:
                // Gemma는 명시적인 시스템 프롬프트를 사용자 턴에 포함하는 것이 권장됩니다.
                prompt += "<start_of_turn>user\n\(message.content)<end_of_turn>\n"
            case .user:
                prompt += "<start_of_turn>user\n\(message.content)<end_of_turn>\n"
            case .assistant:
                prompt += "<start_of_turn>model\n\(message.content)<end_of_turn>\n"
            }
        }
        
        // 마지막에는 모델의 답변을 유도하기 위해 모델 턴을 엽니다.
        prompt += "<start_of_turn>model\n"
        return prompt
    }
}
