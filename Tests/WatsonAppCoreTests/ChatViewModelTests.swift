import XCTest
import WatsonDomain
@testable import WatsonAppCore

@MainActor
final class ChatViewModelTests: XCTestCase {
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
    private let loadDelayNanos: UInt64

    private(set) var loadCalls: [ModelConfiguration] = []
    private var loadedConfiguration: ModelConfiguration?

    init(tokens: [String], tokenDelayNanos: UInt64, loadDelayNanos: UInt64 = 0) {
        self.tokens = tokens
        self.tokenDelayNanos = tokenDelayNanos
        self.loadDelayNanos = loadDelayNanos
    }

    nonisolated func supports(config: ModelConfiguration) -> Bool {
        config.providerKind == .mlxNative && config.format == .gemma4
    }

    func loadModel(config: ModelConfiguration) async throws {
        if loadDelayNanos > 0 {
            try? await Task.sleep(nanoseconds: loadDelayNanos)
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
        State(loadCalls: loadCalls, loadedConfiguration: loadedConfiguration)
    }

    struct State: Sendable {
        let loadCalls: [ModelConfiguration]
        let loadedConfiguration: ModelConfiguration?
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
