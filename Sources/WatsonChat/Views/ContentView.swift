import SwiftUI
import WatsonAppCore
import WatsonDomain

struct ContentView: View {
    private static let typingIndicatorScrollID = "assistant-typing-indicator"

    @Bindable var viewModel: ChatViewModel
    @State private var inputText: String = ""
    @State private var codeModeEnabled: Bool = false
    @State private var reasoningModeEnabled: Bool = false
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            Divider()

            VStack(spacing: 0) {
                header
                Divider()
                conversationArea
                Divider()
                composer
            }
        }
        .onAppear {
            #if os(macOS)
            NSApp.setActivationPolicy(.regular)
            NSApplication.shared.activate(ignoringOtherApps: true)
            for window in NSApp.windows {
                window.makeKeyAndOrderFront(nil)
            }
            #endif
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                isFocused = true
            }
        }
        .onChange(of: viewModel.routingLock) { _, newLock in
            guard viewModel.autoRoutingEnabled, let targetModel = newLock.targetModel else { return }
            viewModel.selectModel(targetModel)
        }
        .onChange(of: viewModel.autoRoutingEnabled) { _, isEnabled in
            guard isEnabled, let targetModel = viewModel.routingLock.targetModel else { return }
            viewModel.selectModel(targetModel)
        }
        .onDisappear {
            viewModel.cancelActiveTasks()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "aqi.medium")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.tint)
                Text("Watson")
                    .font(.title3.weight(.semibold))
            }
            .padding(.top, 14)

            Button {
                inputText = ""
                isFocused = true
            } label: {
                Label("새 대화", systemImage: "square.and.pencil")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Text("최근 대화")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                SidebarRow(title: "Gemma와 시작하기", subtitle: "오늘")
                SidebarRow(title: "모델 비교 질문", subtitle: "어제")
                SidebarRow(title: "코드 리뷰 요청", subtitle: "3일 전")
            }

            Spacer()
        }
        .padding(16)
        .frame(width: 260)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Watson macOS Chat")
                    .font(.title3.weight(.semibold))
                Text(viewModel.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            Picker("모델 선택", selection: $viewModel.currentModel) {
                ForEach(ModelConfiguration.availableModels) { model in
                    Text(model.id).tag(model)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 190)
            .onChange(of: viewModel.currentModel) { _, newModel in
                viewModel.selectModel(newModel)
            }

            Menu {
                Toggle("자동 라우팅", isOn: $viewModel.autoRoutingEnabled)
                Picker("라우팅 잠금", selection: $viewModel.routingLock) {
                    Text("잠금 없음").tag(ModelRoutingLock.none)
                    Text("E2B 고정").tag(ModelRoutingLock.forceE2B)
                    Text("E4B 고정").tag(ModelRoutingLock.forceE4B)
                }
            } label: {
                Label("설정", systemImage: "slider.horizontal.3")
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var conversationArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 14) {
                    if viewModel.messages.isEmpty {
                        ContentUnavailableView(
                            "Gemma와 대화를 시작하세요",
                            systemImage: "sparkles",
                            description: Text("질문을 입력하고 Enter를 누르면 답변을 생성합니다.")
                        )
                        .padding(.top, 96)
                    } else {
                        ForEach(viewModel.messages) { message in
                            MessageBubbleView(message: message)
                                .id(message.id)
                        }

                        if viewModel.isAwaitingAssistantResponse {
                            AssistantTypingIndicatorBubbleView()
                                .id(Self.typingIndicatorScrollID)
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 20)
                .frame(maxWidth: 980)
                .frame(maxWidth: .infinity)
            }
            .onChange(of: viewModel.messages.last?.content) { _, _ in
                if let lastID = viewModel.messages.last?.id {
                    proxy.scrollTo(lastID, anchor: .bottom)
                }
            }
            .onChange(of: viewModel.isAwaitingAssistantResponse) { _, isAwaiting in
                if isAwaiting {
                    proxy.scrollTo(Self.typingIndicatorScrollID, anchor: .bottom)
                } else if let lastID = viewModel.messages.last?.id {
                    proxy.scrollTo(lastID, anchor: .bottom)
                }
            }
        }
    }

    private var composer: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                TogglePillButton(title: "Code", isOn: $codeModeEnabled)
                TogglePillButton(title: "Reasoning", isOn: $reasoningModeEnabled)
                Spacer()
            }

            HStack(alignment: .bottom, spacing: 10) {
                TextField("메시지를 입력하세요...", text: $inputText, axis: .vertical)
                    .lineLimit(1...6)
                    .focused($isFocused)
                    .onSubmit {
                        if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isBusy {
                            sendMessage()
                        }
                    }
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(nsColor: .textBackgroundColor))
                    )

                if viewModel.showsStopButton {
                    Button(action: stopGeneration) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(.red, in: Circle())
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(.blue, in: Circle())
                    }
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isBusy)
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func sendMessage() {
        guard !inputText.isEmpty else { return }
        let text = inputText
        inputText = ""
        viewModel.submitMessage(text)
    }

    private func stopGeneration() {
        viewModel.stopGeneration()
    }
}

private struct SidebarRow: View {
    let title: String
    let subtitle: String

    var body: some View {
        Button {
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
    }
}

private struct TogglePillButton: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(isOn ? .white : .primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(isOn ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                )
        }
        .buttonStyle(.plain)
    }
}
