import Foundation
import Observation
import WatsonDomain

@MainActor
@Observable
public final class ChatViewModel {
    public var messages: [ChatMessage] = []
    public var isGenerating: Bool = false
    public var isModelLoading: Bool = false
    public var isAwaitingAssistantResponse: Bool = false
    public var currentModel: ModelConfiguration = .gemma4_E2B
    public var statusMessage: String = ""
    public var autoRoutingEnabled: Bool = true
    public var routingLock: ModelRoutingLock = .none

    public var isBusy: Bool { isGenerating || isModelLoading }
    public var showsStopButton: Bool { generationTask != nil }

    private let providerFactory: (ProviderKind) -> any InferenceProvider
    private let routingPolicy: RoutingPolicy
    private let simpleArithmeticRegex = try! NSRegularExpression(
        pattern: #"^\s*([+-]?\d+(?:\.\d+)?)\s*([+\-*/xX×÷])\s*([+-]?\d+(?:\.\d+)?)\s*(?:=\s*\??)?\s*(?:[^\d+\-*/xX×÷.]*)$"#
    )
    private var providerKind: ProviderKind
    private var provider: any InferenceProvider
    private var generationTask: Task<Void, Never>?
    private var modelSwitchTask: Task<Void, Never>?
    private var routingStreakTarget: ModelConfiguration?
    private var routingStreakCount: Int = 0

    public init(
        initialModel: ModelConfiguration = .gemma4_E2B,
        autoLoadInitialModel: Bool = true,
        routingPolicy: RoutingPolicy = .balanced,
        providerFactory: @escaping (ProviderKind) -> any InferenceProvider
    ) {
        self.currentModel = initialModel
        self.routingPolicy = routingPolicy
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
        resetRoutingHysteresis()
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

        if let quickReply = quickReplyForSimpleArithmetic(in: trimmedText) {
            messages.append(ChatMessage(role: .user, content: trimmedText))
            messages.append(ChatMessage(role: .assistant, content: quickReply))
            isAwaitingAssistantResponse = false
            statusMessage = "준비 완료"
            return
        }

        await routeModelIfNeeded(for: trimmedText)
        if isModelLoading {
            return
        }

        // 사용자 메시지 추가
        let userMessage = ChatMessage(role: .user, content: trimmedText)
        messages.append(userMessage)

        isGenerating = true
        isAwaitingAssistantResponse = true
        var assistantID: UUID?

        defer {
            isGenerating = false
            isAwaitingAssistantResponse = false
        }

        do {
            let generationOptions = buildGenerationOptions(for: currentModel)
            let stream = try await provider.generate(
                messages: messages,
                options: generationOptions
            )

            for try await token in stream {
                try Task.checkCancellation()

                guard !token.isEmpty else { continue }

                if let existingID = assistantID,
                    let index = messages.firstIndex(where: { $0.id == existingID })
                {
                    messages[index].content += token
                } else {
                    let newAssistantID = UUID()
                    assistantID = newAssistantID
                    messages.append(ChatMessage(id: newAssistantID, role: .assistant, content: token))
                    isAwaitingAssistantResponse = false
                }
            }

            try Task.checkCancellation()
            statusMessage = "준비 완료"
        } catch is CancellationError {
            statusMessage = "생성 중지됨"
        } catch {
            let errorMessage = "[오류]: \(error.localizedDescription)"
            if let existingID = assistantID,
                let index = messages.firstIndex(where: { $0.id == existingID })
            {
                let suffix = messages[index].content.isEmpty ? errorMessage : "\n\n\(errorMessage)"
                messages[index].content += suffix
            } else {
                messages.append(ChatMessage(role: .assistant, content: errorMessage))
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

    private func routeModelIfNeeded(for userText: String) async {
        guard autoRoutingEnabled else {
            resetRoutingHysteresis()
            return
        }

        if let lockedModel = routingLock.targetModel {
            resetRoutingHysteresis()
            if lockedModel != currentModel {
                await switchModel(to: lockedModel)
            }
            return
        }

        let recommendedModel = routingPolicy.recommendedModel(
            forUserText: userText,
            messages: messages
        )
        guard recommendedModel != currentModel else {
            resetRoutingHysteresis()
            return
        }

        if routingStreakTarget == recommendedModel {
            routingStreakCount += 1
        } else {
            routingStreakTarget = recommendedModel
            routingStreakCount = 1
        }

        guard routingStreakCount >= routingPolicy.switchStreakThreshold else {
            return
        }

        resetRoutingHysteresis()
        await switchModel(to: recommendedModel)
    }

    private func resetRoutingHysteresis() {
        routingStreakTarget = nil
        routingStreakCount = 0
    }

    private func buildGenerationOptions(for model: ModelConfiguration) -> GenerationOptions {
        let promptOptions = PromptFormatter.GemmaOptions(
            contextBudgetCharacters: contextBudget(for: model),
            recentMessagesToKeep: model == .gemma4_E2B ? 6 : 10,
            summaryCharacterLimit: model == .gemma4_E2B ? 320 : 560
        )

        return GenerationOptions(
            maxTokens: model.maxTokens,
            temperature: 0.0,
            topP: 1.0,
            repetitionPenalty: 1.0,
            flushIntervalSeconds: model == .gemma4_E2B ? 0.025 : 0.035,
            flushTokenThreshold: model == .gemma4_E2B ? 6 : 10,
            promptOptions: promptOptions
        )
    }

    private func contextBudget(for model: ModelConfiguration) -> Int {
        switch model.id {
        case ModelConfiguration.gemma4_E2B.id:
            return 8_000
        case ModelConfiguration.gemma4_E4B.id:
            return 14_000
        default:
            return 18_000
        }
    }

    private func quickReplyForSimpleArithmetic(in text: String) -> String? {
        if text.range(of: #"[A-Za-z]"#, options: .regularExpression) != nil {
            return nil
        }

        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = simpleArithmeticRegex.firstMatch(in: text, range: fullRange) else {
            return nil
        }
        guard
            let lhsRange = Range(match.range(at: 1), in: text),
            let operatorRange = Range(match.range(at: 2), in: text),
            let rhsRange = Range(match.range(at: 3), in: text),
            let lhs = Double(text[lhsRange]),
            let rhs = Double(text[rhsRange])
        else {
            return nil
        }

        let operatorSymbol = text[operatorRange]
        let result: Double
        switch operatorSymbol {
        case "+":
            result = lhs + rhs
        case "-":
            result = lhs - rhs
        case "*", "x", "X", "×":
            result = lhs * rhs
        case "/", "÷":
            guard abs(rhs) > 1e-12 else {
                return "0으로 나눌 수 없습니다."
            }
            result = lhs / rhs
        default:
            return nil
        }

        return formatArithmeticResult(result)
    }

    private func formatArithmeticResult(_ value: Double) -> String {
        let normalizedValue = abs(value) < 1e-12 ? 0.0 : value
        let roundedValue = normalizedValue.rounded()
        if abs(normalizedValue - roundedValue) < 1e-9,
            roundedValue >= Double(Int64.min),
            roundedValue <= Double(Int64.max)
        {
            return String(Int64(roundedValue))
        }

        return String(format: "%.10g", normalizedValue)
    }
}
