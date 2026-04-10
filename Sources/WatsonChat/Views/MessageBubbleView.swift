import SwiftUI
import WatsonDomain

struct MessageBubbleView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.role == .user { Spacer() }
            
            Text(message.content)
                .padding(12)
                .background(bubbleBackground)
                .foregroundColor(message.role == .user ? .white : .primary)
                .cornerRadius(12)
                .textSelection(.enabled) 
            
            if message.role == .assistant || message.role == .system { Spacer() }
        }
    }
    
    private var bubbleBackground: Color {
        switch message.role {
        case .user: return .blue.opacity(0.8)
        case .assistant: return .gray.opacity(0.2)
        case .system: return .orange.opacity(0.1)
        }
    }
}

struct AssistantTypingIndicatorBubbleView: View {
    var body: some View {
        HStack {
            ProgressView()
                .controlSize(.small)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(.gray.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityLabel("응답 생성 중")

            Spacer()
        }
    }
}
