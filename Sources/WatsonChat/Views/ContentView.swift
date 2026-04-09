import SwiftUI

struct ContentView: View {
    @Bindable var viewModel: ChatViewModel
    @State private var inputText: String = ""

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
                            ForEach(viewModel.messages) { message in
                                MessageBubbleView(message: message)
                                    .id(message.id)
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
                HStack(alignment: .bottom) {
                    TextField("Gemma 4에게 질문하기...", text: $inputText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...10)
                        .onSubmit { sendMessage() }
                    
                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .symbolRenderingMode(.hierarchical)
                    }
                    .disabled(inputText.isEmpty || viewModel.isGenerating)
                    .buttonStyle(.borderedProminent)
                    .padding(.bottom, 2)
                }
                .padding()
            }
            .navigationTitle(viewModel.currentModel.id)
            .subtitle(viewModel.statusMessage)
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
