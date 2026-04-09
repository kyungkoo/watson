import SwiftUI
import Foundation

@MainActor
@Observable
public final class ChatViewModel {
    public var messages: [ChatMessage] = []
    public var isGenerating: Bool = false
    public var currentModel: ModelConfiguration = .gemma4_E2B
    public var statusMessage: String = ""
    
    private let engine = MLXEngine()
    
    public init() {
        Task {
            await switchModel(to: currentModel)
        }
    }
    
    public func switchModel(to config: ModelConfiguration) async {
        self.currentModel = config
        self.isGenerating = true
        self.statusMessage = "\(config.id) 로드 중..."
        
        defer {
            self.isGenerating = false
        }
        
        do {
            try await engine.loadModel(config: config)
            self.statusMessage = "준비 완료"
        } catch {
            self.statusMessage = "로드 실패: \(error.localizedDescription)"
        }
    }
    
    public func sendMessage(_ text: String) async {
        guard !text.isEmpty && !isGenerating else { return }
        
        // 사용자 메시지 추가
        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)
        
        // 어시스턴트 메시지 생성 (UI용)
        let assistantID = UUID()
        messages.append(ChatMessage(id: assistantID, role: .assistant, content: ""))
        
        isGenerating = true
        
        defer {
            isGenerating = false
        }
        
        // 프롬프트 생성 (이전 대화 전체 포함)
        let prompt = PromptFormatter.formatGemma(messages: messages.dropLast())
        
        do {
            let stream = await engine.generate(prompt: prompt, maxTokens: currentModel.maxTokens)
            
            for try await token in stream {
                if let index = messages.firstIndex(where: { $0.id == assistantID }) {
                    messages[index].content += token
                }
            }
        } catch {
            if let index = messages.firstIndex(where: { $0.id == assistantID }) {
                let errorMessage = "\n\n[오류]: \(error.localizedDescription)"
                messages[index].content += errorMessage
            }
        }
    }
}
