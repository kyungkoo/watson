import Foundation
import Observation

@MainActor
@Observable
public final class ChatViewModel {
    public var messages: [ChatMessage] = []
    public var isGenerating: Bool = false
    public var isModelLoading: Bool = false
    public var currentModel: ModelConfiguration = .gemma4_E2B
    public var statusMessage: String = ""

    public var isBusy: Bool { isGenerating || isModelLoading }
    public var showsStopButton: Bool { generationTask != nil }

    private let providerFactory: (ProviderKind) -> any InferenceProvider
    private var providerKind: ProviderKind
    private var provider: any InferenceProvider
    private var generationTask: Task<Void, Never>?
    private var modelSwitchTask: Task<Void, Never>?

    public init(
        initialModel: ModelConfiguration = .gemma4_E2B,
        autoLoadInitialModel: Bool = true,
        providerFactory: @escaping (ProviderKind) -> any InferenceProvider = { kind in
            InferenceProviderFactory.makeProvider(for: kind)
        }
    ) {
        self.currentModel = initialModel
        self.providerFactory = providerFactory
        self.providerKind = initialModel.providerKind
        self.provider = providerFactory(initialModel.providerKind)

        if autoLoadInitialModel {
            selectModel(initialModel)
        }
    }

    public func selectModel(_ config: ModelConfiguration) {
        generationTask?.cancel()
        modelSwitchTask?.cancel()
        modelSwitchTask = Task { [weak self] in
            guard let self else { return }
            await self.switchModel(to: config)
            await MainActor.run {
                self.modelSwitchTask = nil
            }
        }
    }

    public func switchModel(to config: ModelConfiguration) async {
        self.currentModel = config
        self.isModelLoading = true
        self.statusMessage = "\(config.id) 로드 중..."

        defer {
            self.isModelLoading = false
        }

        do {
            await configureProviderIfNeeded(for: config)
            guard provider.supports(config: config) else {
                throw InferenceProviderError.unsupportedConfiguration(config)
            }

            try await provider.loadModel(config: config)
            self.statusMessage = "준비 완료"
        } catch {
            self.statusMessage = "로드 실패: \(error.localizedDescription)"
        }
    }

    public func submitMessage(_ text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty, !isBusy, generationTask == nil else { return }

        generationTask = Task { [weak self] in
            guard let self else { return }
            await self.sendMessage(trimmedText)
            await MainActor.run {
                self.generationTask = nil
            }
        }
    }

    public func sendMessage(_ text: String) async {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty && !isGenerating && !isModelLoading else { return }

        // 사용자 메시지 추가
        let userMessage = ChatMessage(role: .user, content: trimmedText)
        messages.append(userMessage)

        // 어시스턴트 메시지 생성 (UI용)
        let assistantID = UUID()
        messages.append(ChatMessage(id: assistantID, role: .assistant, content: ""))

        isGenerating = true

        defer {
            isGenerating = false
        }

        do {
            let stream = try await provider.generate(
                messages: Array(messages.dropLast()),
                maxTokens: currentModel.maxTokens
            )

            for try await token in stream {
                try Task.checkCancellation()
                if let index = messages.firstIndex(where: { $0.id == assistantID }) {
                    messages[index].content += token
                }
            }

            try Task.checkCancellation()
            statusMessage = "준비 완료"
        } catch is CancellationError {
            statusMessage = "생성 중지됨"
        } catch {
            if let index = messages.firstIndex(where: { $0.id == assistantID }) {
                let errorMessage = "\n\n[오류]: \(error.localizedDescription)"
                messages[index].content += errorMessage
            }

            statusMessage = "생성 실패: \(error.localizedDescription)"
        }
    }

    public func stopGeneration() {
        guard generationTask != nil else { return }
        statusMessage = "중지 요청 중..."
        generationTask?.cancel()
    }

    public func cancelActiveTasks() {
        generationTask?.cancel()
        modelSwitchTask?.cancel()
        generationTask = nil
        modelSwitchTask = nil
    }

    private func configureProviderIfNeeded(for config: ModelConfiguration) async {
        guard config.providerKind != providerKind else {
            return
        }

        await provider.unload()
        provider = providerFactory(config.providerKind)
        providerKind = config.providerKind
    }
}
