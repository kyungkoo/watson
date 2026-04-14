import XCTest
import WatsonDomain
@testable import WatsonAppCore

@MainActor
final class ChatViewModelTests: XCTestCase {
    func test_init_defaultsToE4BAndDisablesAutoRouting() {
        let provider = ScriptedInferenceProvider(tokens: ["ok"], tokenDelayNanos: 0)
        let viewModel = ChatViewModel(
            autoLoadInitialModel: false,
            providerFactory: { _ in provider }
        )

        XCTAssertEqual(viewModel.currentModel, .gemma4_E4B)
        XCTAssertFalse(viewModel.autoRoutingEnabled)
    }

    func test_submitMessage_ignoresWhitespaceOnlyInput() async {
        let provider = ScriptedInferenceProvider(tokens: ["ok"], tokenDelayNanos: 0)
        let viewModel = ChatViewModel(
            initialModel: .gemma4_E2B,
            autoLoadInitialModel: false,
            providerFactory: { _ in provider }
        )

        await viewModel.switchModel(to: .gemma4_E2B)
        viewModel.submitMessage("   \n\t")

        try? await Task.sleep(nanoseconds: 30_000_000)

        XCTAssertTrue(viewModel.messages.isEmpty)
        XCTAssertEqual(viewModel.statusMessage, "준비 완료")
    }

    func test_submitMessage_simpleArithmetic_respondsImmediatelyWithoutModelCall() async {
        let provider = ScriptedInferenceProvider(tokens: ["실패"], tokenDelayNanos: 0)
        let viewModel = ChatViewModel(
            initialModel: .gemma4_E2B,
            autoLoadInitialModel: false,
            providerFactory: { _ in provider }
        )

        viewModel.submitMessage("10 - 10 = ?")

        let finished = await waitUntil(timeout: 1.0) {
            viewModel.messages.count == 2 && !viewModel.isGenerating && !viewModel.showsStopButton
        }

        XCTAssertTrue(finished)
        XCTAssertEqual(viewModel.messages[0].role, .user)
        XCTAssertEqual(viewModel.messages[0].content, "10 - 10 = ?")
        XCTAssertEqual(viewModel.messages[1].role, .assistant)
        XCTAssertEqual(viewModel.messages[1].content, "0")
        XCTAssertEqual(viewModel.statusMessage, "준비 완료")

        let state = await provider.state()
        XCTAssertTrue(state.loadCalls.isEmpty)
    }

    func test_submitMessage_simpleArithmeticWithKoreanSuffix_respondsImmediately() async {
        let provider = ScriptedInferenceProvider(tokens: ["실패"], tokenDelayNanos: 0)
        let viewModel = ChatViewModel(
            initialModel: .gemma4_E2B,
            autoLoadInitialModel: false,
            providerFactory: { _ in provider }
        )

        viewModel.submitMessage("10-10은 뭐지?")

        let finished = await waitUntil(timeout: 1.0) {
            viewModel.messages.count == 2 && !viewModel.isGenerating
        }

        XCTAssertTrue(finished)
        XCTAssertEqual(viewModel.messages[1].content, "0")

        let state = await provider.state()
        XCTAssertTrue(state.loadCalls.isEmpty)
    }

    func test_submitMessage_streamsAssistantTokens() async {
        let provider = ScriptedInferenceProvider(tokens: ["안", "녕"], tokenDelayNanos: 5_000_000)
        let viewModel = ChatViewModel(
            initialModel: .gemma4_E2B,
            autoLoadInitialModel: false,
            providerFactory: { _ in provider }
        )

        await viewModel.switchModel(to: .gemma4_E2B)
        viewModel.submitMessage("안녕")

        let finished = await waitUntil(timeout: 1.0) {
            !viewModel.isGenerating && !viewModel.showsStopButton && viewModel.messages.count == 2
        }

        XCTAssertTrue(finished)
        XCTAssertEqual(viewModel.messages.count, 2)
        XCTAssertEqual(viewModel.messages[0].role, .user)
        XCTAssertEqual(viewModel.messages[0].content, "안녕")
        XCTAssertEqual(viewModel.messages[1].role, .assistant)
        XCTAssertEqual(viewModel.messages[1].content, "안녕")
        XCTAssertEqual(viewModel.statusMessage, "준비 완료")
    }

    func test_submitMessage_doesNotAppendAssistantMessageBeforeFirstToken() async {
        let provider = ScriptedInferenceProvider(tokens: ["첫", "토큰"], tokenDelayNanos: 120_000_000)
        let viewModel = ChatViewModel(
            initialModel: .gemma4_E2B,
            autoLoadInitialModel: false,
            providerFactory: { _ in provider }
        )

        await viewModel.switchModel(to: .gemma4_E2B)
        viewModel.submitMessage("응답 대기")

        let waitingWithoutAssistantBubble = await waitUntil(timeout: 1.0) {
            viewModel.isGenerating && viewModel.messages.count == 1
        }
        XCTAssertTrue(waitingWithoutAssistantBubble)
        XCTAssertEqual(viewModel.messages.first?.role, .user)

        let firstTokenRendered = await waitUntil(timeout: 1.0) {
            viewModel.messages.count == 2 && !viewModel.messages[1].content.isEmpty
        }
        XCTAssertTrue(firstTokenRendered)
        XCTAssertEqual(viewModel.messages[1].role, .assistant)
    }

    func test_stopGeneration_cancelsStreamingTask() async {
        let provider = ScriptedInferenceProvider(tokens: Array(repeating: "토큰", count: 50), tokenDelayNanos: 20_000_000)
        let viewModel = ChatViewModel(
            initialModel: .gemma4_E2B,
            autoLoadInitialModel: false,
            providerFactory: { _ in provider }
        )

        await viewModel.switchModel(to: .gemma4_E2B)
        viewModel.submitMessage("중지 테스트")

        let started = await waitUntil(timeout: 1.0) {
            viewModel.isGenerating && viewModel.showsStopButton
        }
        XCTAssertTrue(started)

        viewModel.stopGeneration()

        let stopped = await waitUntil(timeout: 1.0) {
            !viewModel.isGenerating && !viewModel.showsStopButton
        }

        XCTAssertTrue(stopped)
        XCTAssertEqual(viewModel.statusMessage, "생성 중지됨")
        XCTAssertEqual(viewModel.messages.first?.role, .user)
        XCTAssertLessThanOrEqual(viewModel.messages.count, 2)

        if viewModel.messages.count == 2 {
            XCTAssertEqual(viewModel.messages[1].role, .assistant)
            XCTAssertFalse(viewModel.messages[1].content.isEmpty)
            XCTAssertLessThan(viewModel.messages[1].content.count, 50 * 2)
        }
    }

    func test_selectModel_runsViewModelOwnedLoadTask() async {
        let provider = ScriptedInferenceProvider(tokens: ["ok"], tokenDelayNanos: 0, loadDelayNanos: 40_000_000)
        let viewModel = ChatViewModel(
            initialModel: .gemma4_E2B,
            autoLoadInitialModel: false,
            providerFactory: { _ in provider }
        )

        viewModel.selectModel(.gemma4_E4B)

        let loadingObserved = await waitUntil(timeout: 1.0) { viewModel.isModelLoading }
        let loaded = await waitUntil(timeout: 1.0) {
            !viewModel.isModelLoading && viewModel.statusMessage == "준비 완료"
        }

        XCTAssertTrue(loadingObserved)
        XCTAssertTrue(loaded)
        XCTAssertEqual(viewModel.currentModel, .gemma4_E4B)

        let state = await provider.state()
        XCTAssertEqual(state.loadCalls.count, 1)
        XCTAssertEqual(state.loadCalls.first, .gemma4_E4B)
    }

    func test_submitMessage_withE4B_shortQuestion_usesFastGenerationOptions() async throws {
        let provider = ScriptedInferenceProvider(tokens: ["ok"], tokenDelayNanos: 0)
        let viewModel = ChatViewModel(
            initialModel: .gemma4_E4B,
            autoLoadInitialModel: false,
            providerFactory: { _ in provider }
        )

        await viewModel.switchModel(to: .gemma4_E4B)
        viewModel.submitMessage("서울은 수도야?")

        let finished = await waitUntil(timeout: 1.0) {
            !viewModel.isGenerating && viewModel.messages.count == 2
        }
        XCTAssertTrue(finished)

        let state = await provider.state()
        let options = try XCTUnwrap(state.lastGenerationOptions)
        XCTAssertEqual(options.maxTokens, 2_048)
        XCTAssertEqual(options.temperature, 0.0, accuracy: 0.0001)
        XCTAssertEqual(options.topP, 1.0, accuracy: 0.0001)
        XCTAssertEqual(options.repetitionPenalty, 1.0, accuracy: 0.0001)
        XCTAssertEqual(options.promptOptions.contextBudgetCharacters, 10_000)
        XCTAssertEqual(options.promptOptions.recentMessagesToKeep, 8)
        XCTAssertEqual(options.promptOptions.summaryCharacterLimit, 400)
        XCTAssertEqual(options.flushTokenThreshold, 4)
        XCTAssertEqual(options.flushIntervalSeconds, 0.015, accuracy: 0.0001)
    }

    func test_submitMessage_withE4B_openEndedRequest_usesRicherGenerationOptions() async throws {
        let provider = ScriptedInferenceProvider(tokens: ["ok"], tokenDelayNanos: 0)
        let viewModel = ChatViewModel(
            initialModel: .gemma4_E4B,
            autoLoadInitialModel: false,
            providerFactory: { _ in provider }
        )

        await viewModel.switchModel(to: .gemma4_E4B)
        viewModel.submitMessage("SwiftUI와 AppKit을 비교해서 장단점과 예시를 함께 설명해줘")

        let finished = await waitUntil(timeout: 1.0) {
            !viewModel.isGenerating && viewModel.messages.count == 2
        }
        XCTAssertTrue(finished)

        let state = await provider.state()
        let options = try XCTUnwrap(state.lastGenerationOptions)
        XCTAssertEqual(options.maxTokens, 2_048)
        XCTAssertEqual(options.temperature, 0.25, accuracy: 0.0001)
        XCTAssertEqual(options.topP, 0.92, accuracy: 0.0001)
        XCTAssertEqual(options.repetitionPenalty, 1.08, accuracy: 0.0001)
        XCTAssertEqual(options.promptOptions.contextBudgetCharacters, 18_000)
        XCTAssertEqual(options.promptOptions.recentMessagesToKeep, 10)
        XCTAssertEqual(options.promptOptions.summaryCharacterLimit, 640)
        XCTAssertEqual(options.flushTokenThreshold, 3)
        XCTAssertEqual(options.flushIntervalSeconds, 0.012, accuracy: 0.0001)
        XCTAssertTrue(options.promptOptions.defaultSystemInstruction.contains("이유와 예시"))
        XCTAssertTrue(options.promptOptions.defaultSystemInstruction.contains("trade-off"))
    }

    func test_selectModel_updatesStatusMessageFromDownloadProgressToFinalizing() async {
        let provider = ScriptedInferenceProvider(
            tokens: ["ok"],
            tokenDelayNanos: 0,
            loadScripts: [
                .gemma4_E4B: .init(
                    scheduledStates: [
                        .init(delayNanos: 20_000_000, state: .downloading(percent: 42)),
                        .init(delayNanos: 20_000_000, state: .finalizing),
                    ],
                    completionDelayNanos: 20_000_000
                )
            ]
        )
        let viewModel = ChatViewModel(
            initialModel: .gemma4_E2B,
            autoLoadInitialModel: false,
            providerFactory: { _ in provider }
        )

        viewModel.selectModel(.gemma4_E4B)

        let sawDownloading = await waitUntil(timeout: 1.0) {
            viewModel.isModelLoading && viewModel.statusMessage == "Gemma 4 E4B 다운로드 42%"
        }
        XCTAssertTrue(sawDownloading)

        let sawFinalizing = await waitUntil(timeout: 1.0) {
            viewModel.isModelLoading && viewModel.statusMessage == "Gemma 4 E4B 적용 중..."
        }
        let loaded = await waitUntil(timeout: 1.0) {
            !viewModel.isModelLoading && viewModel.statusMessage == "준비 완료"
        }

        XCTAssertTrue(sawFinalizing)
        XCTAssertTrue(loaded)
    }

    func test_selectModel_withoutProgressStartsWithFinalizingStatus() async {
        let provider = ScriptedInferenceProvider(tokens: ["ok"], tokenDelayNanos: 0, loadDelayNanos: 60_000_000)
        let viewModel = ChatViewModel(
            initialModel: .gemma4_E2B,
            autoLoadInitialModel: false,
            providerFactory: { _ in provider }
        )

        viewModel.selectModel(.gemma4_E4B)

        let started = await waitUntil(timeout: 1.0) {
            viewModel.isModelLoading && viewModel.statusMessage == "Gemma 4 E4B 적용 중..."
        }
        let loaded = await waitUntil(timeout: 1.0) {
            !viewModel.isModelLoading && viewModel.statusMessage == "준비 완료"
        }

        XCTAssertTrue(started)
        XCTAssertTrue(loaded)
    }

    func test_selectModel_ignoresStaleProgressAndCompletionFromCanceledLoad() async {
        let provider = ScriptedInferenceProvider(
            tokens: ["ok"],
            tokenDelayNanos: 0,
            loadScripts: [
                .gemma4_E4B: .init(
                    scheduledStates: [
                        .init(delayNanos: 20_000_000, state: .downloading(percent: 25)),
                        .init(delayNanos: 100_000_000, state: .finalizing),
                    ],
                    completionDelayNanos: 80_000_000
                ),
                .gemma4_E2B: .init(completionDelayNanos: 10_000_000)
            ]
        )
        let viewModel = ChatViewModel(
            initialModel: .gemma4_E2B,
            autoLoadInitialModel: false,
            providerFactory: { _ in provider }
        )

        viewModel.selectModel(.gemma4_E4B)

        let sawFirstProgress = await waitUntil(timeout: 1.0) {
            viewModel.statusMessage == "Gemma 4 E4B 다운로드 25%"
        }
        XCTAssertTrue(sawFirstProgress)

        viewModel.selectModel(.gemma4_E2B)

        let loadedReplacement = await waitUntil(timeout: 1.0) {
            !viewModel.isModelLoading
                && viewModel.currentModel == .gemma4_E2B
                && viewModel.statusMessage == "준비 완료"
        }
        XCTAssertTrue(loadedReplacement)

        try? await Task.sleep(nanoseconds: 250_000_000)

        XCTAssertEqual(viewModel.currentModel, .gemma4_E2B)
        XCTAssertEqual(viewModel.statusMessage, "준비 완료")
        XCTAssertFalse(viewModel.isModelLoading)
    }

    func test_autoRouting_switchesToE4BAfterHysteresisForComplexTurns() async {
        let provider = ScriptedInferenceProvider(tokens: ["ok"], tokenDelayNanos: 0)
        let policy = RoutingPolicy(
            longRequestCharacterThreshold: 20,
            longConversationCharacterThreshold: 200,
            longConversationMessageThreshold: 8,
            switchStreakThreshold: 2
        )
        let viewModel = ChatViewModel(
            initialModel: .gemma4_E2B,
            autoLoadInitialModel: false,
            routingPolicy: policy,
            providerFactory: { _ in provider }
        )

        viewModel.autoRoutingEnabled = true
        await viewModel.switchModel(to: .gemma4_E2B)

        viewModel.submitMessage(String(repeating: "복잡", count: 12))
        _ = await waitUntil(timeout: 1.0) { !viewModel.isGenerating && viewModel.messages.count == 2 }
        XCTAssertEqual(viewModel.currentModel, .gemma4_E2B)

        viewModel.submitMessage(String(repeating: "복잡", count: 12))
        let finished = await waitUntil(timeout: 1.0) {
            !viewModel.isGenerating && viewModel.messages.count == 4
        }
        XCTAssertTrue(finished)
        XCTAssertEqual(viewModel.currentModel, .gemma4_E4B)

        let state = await provider.state()
        XCTAssertEqual(state.loadCalls, [.gemma4_E2B, .gemma4_E4B])
    }

    func test_routingLock_forceE2B_preventsAutomaticUpgrade() async {
        let provider = ScriptedInferenceProvider(tokens: ["ok"], tokenDelayNanos: 0)
        let policy = RoutingPolicy(
            longRequestCharacterThreshold: 20,
            longConversationCharacterThreshold: 200,
            longConversationMessageThreshold: 8,
            switchStreakThreshold: 2
        )
        let viewModel = ChatViewModel(
            initialModel: .gemma4_E2B,
            autoLoadInitialModel: false,
            routingPolicy: policy,
            providerFactory: { _ in provider }
        )

        viewModel.autoRoutingEnabled = true
        viewModel.routingLock = .forceE2B
        await viewModel.switchModel(to: .gemma4_E2B)

        viewModel.submitMessage(String(repeating: "복잡", count: 12))
        _ = await waitUntil(timeout: 1.0) { !viewModel.isGenerating && viewModel.messages.count == 2 }
        viewModel.submitMessage(String(repeating: "복잡", count: 12))
        let finished = await waitUntil(timeout: 1.0) {
            !viewModel.isGenerating && viewModel.messages.count == 4
        }

        XCTAssertTrue(finished)
        XCTAssertEqual(viewModel.currentModel, .gemma4_E2B)

        let state = await provider.state()
        XCTAssertEqual(state.loadCalls, [.gemma4_E2B])
    }
}

private actor ScriptedInferenceProvider: InferenceProvider {
    private let tokens: [String]
    private let tokenDelayNanos: UInt64
    private let defaultLoadScript: LoadScript
    private let loadScripts: [ModelConfiguration: LoadScript]

    private(set) var loadCalls: [ModelConfiguration] = []
    private var loadedConfiguration: ModelConfiguration?
    private var lastGenerationOptions: GenerationOptions?

    init(
        tokens: [String],
        tokenDelayNanos: UInt64,
        loadDelayNanos: UInt64 = 0,
        loadScripts: [ModelConfiguration: LoadScript] = [:]
    ) {
        self.tokens = tokens
        self.tokenDelayNanos = tokenDelayNanos
        self.defaultLoadScript = LoadScript(completionDelayNanos: loadDelayNanos)
        self.loadScripts = loadScripts
    }

    nonisolated func supports(config: ModelConfiguration) -> Bool {
        config.providerKind == .mlxNative && config.format == .gemma4
    }

    func loadModel(config: ModelConfiguration) async throws {
        try await loadModel(config: config, onStateChange: { _ in })
    }

    func loadModel(
        config: ModelConfiguration,
        onStateChange: @Sendable @escaping (ModelLoadState) -> Void
    ) async throws {
        let script = loadScripts[config] ?? defaultLoadScript

        for scheduledState in script.scheduledStates {
            if scheduledState.delayNanos > 0 {
                try? await Task.sleep(nanoseconds: scheduledState.delayNanos)
            }
            onStateChange(scheduledState.state)
        }

        if script.completionDelayNanos > 0 {
            try? await Task.sleep(nanoseconds: script.completionDelayNanos)
        }

        loadCalls.append(config)
        loadedConfiguration = config
    }

    func generate(
        messages: [ChatMessage],
        options: GenerationOptions
    ) async throws -> AsyncThrowingStream<String, Error> {
        guard loadedConfiguration != nil else {
            throw InferenceProviderError.modelNotLoaded
        }

        lastGenerationOptions = options

        let scheduledTokens = Array(tokens.prefix(options.maxTokens))
        return AsyncThrowingStream { continuation in
            let task = Task {
                for token in scheduledTokens {
                    if Task.isCancelled { break }
                    if tokenDelayNanos > 0 {
                        try? await Task.sleep(nanoseconds: tokenDelayNanos)
                    }
                    continuation.yield(token)
                }
                continuation.finish()
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    func unload() async {
        loadedConfiguration = nil
    }

    func state() -> State {
        State(
            loadCalls: loadCalls,
            loadedConfiguration: loadedConfiguration,
            lastGenerationOptions: lastGenerationOptions
        )
    }

    struct State: Sendable {
        let loadCalls: [ModelConfiguration]
        let loadedConfiguration: ModelConfiguration?
        let lastGenerationOptions: GenerationOptions?
    }

    struct LoadScript: Sendable {
        let scheduledStates: [ScheduledLoadState]
        let completionDelayNanos: UInt64

        init(
            scheduledStates: [ScheduledLoadState] = [],
            completionDelayNanos: UInt64 = 0
        ) {
            self.scheduledStates = scheduledStates
            self.completionDelayNanos = completionDelayNanos
        }
    }

    struct ScheduledLoadState: Sendable {
        let delayNanos: UInt64
        let state: ModelLoadState
    }
}

@MainActor
private func waitUntil(
    timeout: TimeInterval,
    intervalNanos: UInt64 = 10_000_000,
    condition: @escaping @MainActor () -> Bool
) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() {
            return true
        }
        try? await Task.sleep(nanoseconds: intervalNanos)
    }
    return condition()
}
