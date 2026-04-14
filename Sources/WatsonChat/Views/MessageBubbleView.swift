import SwiftUI
import WatsonDomain

struct MessageBubbleView: View {
    private static let copilotAutopilotBubbleGreen = Color(
        red: 150.0 / 255.0,
        green: 224.0 / 255.0,
        blue: 216.0 / 255.0
    )

    let message: ChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == .user { Spacer(minLength: 48) }

            Text(message.content)
                .font(.body)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(bubbleBackground)
                .foregroundStyle(textColor)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .textSelection(.enabled)
                .frame(maxWidth: 720, alignment: message.role == .user ? .trailing : .leading)

            if message.role != .user { Spacer(minLength: 48) }
        }
        .frame(maxWidth: .infinity)
    }

    private var bubbleBackground: some ShapeStyle {
        switch message.role {
        case .user:
            return AnyShapeStyle(.blue)
        case .assistant:
            return AnyShapeStyle(Self.copilotAutopilotBubbleGreen)
        case .system:
            return AnyShapeStyle(.orange.opacity(0.15))
        }
    }

    private var textColor: Color {
        switch message.role {
        case .user:
            return .white
        case .assistant, .system:
            return .primary
        }
    }
}

struct AssistantTypingIndicatorBubbleView: View {
    var body: some View {
        HStack {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("답변 작성 중...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityLabel("응답 생성 중")

            Spacer(minLength: 48)
        }
        .frame(maxWidth: .infinity)
    }
}
