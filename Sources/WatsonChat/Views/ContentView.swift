import SwiftUI

struct ContentView: View {
    @Bindable var viewModel: ChatViewModel
    @State private var inputText: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationSplitView {
            List {
                Text("대화 기록 (구현 예정)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("채팅 목록")
            .navigationSplitViewColumnWidth(min: 200, ideal: 240)
        } detail: {
            VStack(spacing: 0) {
                // 대화 로그
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            if viewModel.messages.isEmpty {
                                ContentUnavailableView("Gemma와 대화를 시작하세요", systemImage: "sparkles", description: Text("질문을 입력하고 Enter를 누르세요."))
                                    .padding(.top, 100)
                            } else {
                                ForEach(viewModel.messages) { message in
                                    MessageBubbleView(message: message)
                                        .id(message.id)
                                }
                            }
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.messages.last?.content) { _, _ in
                        if let lastID = viewModel.messages.last?.id {
                            proxy.scrollTo(lastID, anchor: .bottom)
                        }
                    }
                }
                
                Divider()
                
                // 입력 바
                HStack(alignment: .center, spacing: 12) {
                    TextField("메시지를 입력하세요...", text: $inputText)
                        .textFieldStyle(.roundedBorder)
                        .focused($isFocused)
                        .onSubmit {
                            if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isGenerating {
                                sendMessage()
                            }
                        }
                    
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .symbolRenderingMode(.hierarchical)
                    }
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isGenerating)
                    .buttonStyle(.plain)
                }
                .padding()
                .background(.background)
            }
            .navigationTitle(viewModel.currentModel.id)
            .subtitle(viewModel.statusMessage)
            .onAppear {
                // 앱이 화면에 뜰 때 터미널로부터 포커스를 가로채고 정규 앱으로 승격
                #if os(macOS)
                NSApp.setActivationPolicy(.regular)
                NSApplication.shared.activate(ignoringOtherApps: true)
                for window in NSApp.windows {
                    window.makeKeyAndOrderFront(nil)
                }
                #endif
                
                // 텍스트 필드에 포커스 부여
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isFocused = true
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("모델 선택", selection: $viewModel.currentModel) {
                        ForEach(ModelConfiguration.availableModels) { model in
                            Text(model.id).tag(model)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: viewModel.currentModel) { _, newModel in
                        Task { await viewModel.switchModel(to: newModel) }
                    }
                }
                
                if viewModel.isGenerating {
                    ToolbarItem(placement: .primaryAction) {
                        ProgressView().controlSize(.small)
                    }
                }
            }
        }
    }
    
    private func sendMessage() {
        guard !inputText.isEmpty else { return }
        let text = inputText
        inputText = ""
        Task { await viewModel.sendMessage(text) }
    }
}

extension View {
    func subtitle(_ text: String) -> some View {
        self.toolbar {
            ToolbarItem(placement: .status) {
                Text(text).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}
