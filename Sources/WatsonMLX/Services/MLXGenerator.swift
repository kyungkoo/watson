import Foundation
import MLX
import MLXLMCommon
import WatsonDomain

internal struct MLXGenerator {
    func generate(
        prompt: String,
        options: GenerationOptions,
        isLoaded: Bool,
        model: MLXLoadedModel?,
        tokenizer: (any MLXLMCommon.Tokenizer)?,
        stopTokenIDs: [Int]
    ) -> AsyncThrowingStream<String, Error> {
        let stopTokenIDs = Set(stopTokenIDs)
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)

        return AsyncThrowingStream<String, Error> { continuation in
            let generationTask = Task(priority: .userInitiated) {
                guard isLoaded, let model = model, let tokenizer = tokenizer else {
                    continuation.finish(throwing: MLXError.modelNotLoaded)
                    return
                }

                guard !trimmedPrompt.isEmpty else {
                    continuation.finish(throwing: MLXError.invalidPrompt)
                    return
                }

                var tokenIDs = tokenizer.encode(text: prompt, addSpecialTokens: true)
                var count = 0
                var generatedTokenIDs: [Int] = []
                var pendingTokenIDs: [Int] = []
                var lastFlushTime = Date()

                while count < options.maxTokens {
                    if Task.isCancelled {
                        break
                    }

                    let input = MLXArray(tokenIDs).reshaped(1, -1)
                    let logits = model.forward(input)
                    let lastLogits = logits[0, -1, 0...]

                    let nextTokenID = nextTokenID(
                        from: lastLogits,
                        generatedTokenIDs: generatedTokenIDs,
                        options: options
                    )

                    if stopTokenIDs.contains(nextTokenID) {
                        break
                    }

                    tokenIDs.append(nextTokenID)
                    generatedTokenIDs.append(nextTokenID)
                    pendingTokenIDs.append(nextTokenID)

                    let now = Date()
                    let shouldFlush = pendingTokenIDs.count >= options.flushTokenThreshold
                        || now.timeIntervalSince(lastFlushTime) >= options.flushIntervalSeconds
                    if shouldFlush {
                        flushPendingTokens(
                            pendingTokenIDs: &pendingTokenIDs,
                            tokenizer: tokenizer,
                            continuation: continuation
                        )
                        lastFlushTime = now
                    }

                    count += 1
                    await Task.yield()
                }

                flushPendingTokens(
                    pendingTokenIDs: &pendingTokenIDs,
                    tokenizer: tokenizer,
                    continuation: continuation
                )
                continuation.finish()
            }

            continuation.onTermination = { @Sendable _ in
                generationTask.cancel()
            }
        }
    }

    private func flushPendingTokens(
        pendingTokenIDs: inout [Int],
        tokenizer: any MLXLMCommon.Tokenizer,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) {
        guard !pendingTokenIDs.isEmpty else { return }
        let chunk = tokenizer.decode(tokenIds: pendingTokenIDs, skipSpecialTokens: true)
        pendingTokenIDs.removeAll(keepingCapacity: true)
        if !chunk.isEmpty {
            continuation.yield(chunk)
        }
    }

    private func nextTokenID(
        from logits: MLXArray,
        generatedTokenIDs: [Int],
        options: GenerationOptions
    ) -> Int {
        // 기본은 빠르고 안정적인 greedy decoding
        let shouldSample = options.temperature > 0.0001 || options.topP < 0.999
        guard shouldSample else {
            let nextTokenArray = argMax(logits, axis: -1)
            return Int(nextTokenArray.item(Int32.self))
        }

        var values = logits.asArray(Float.self)
        applyRepetitionPenalty(
            logits: &values,
            generatedTokenIDs: generatedTokenIDs,
            penalty: options.repetitionPenalty
        )

        return sampleFromTopPLogits(
            logits: values,
            temperature: options.temperature,
            topP: options.topP
        )
    }

    private func applyRepetitionPenalty(
        logits: inout [Float],
        generatedTokenIDs: [Int],
        penalty: Float
    ) {
        guard penalty > 1.0, !generatedTokenIDs.isEmpty else { return }

        let trackedTokenIDs = Set(generatedTokenIDs.suffix(128))
        for tokenID in trackedTokenIDs where tokenID >= 0 && tokenID < logits.count {
            let logit = logits[tokenID]
            logits[tokenID] = logit >= 0 ? (logit / penalty) : (logit * penalty)
        }
    }

    private func sampleFromTopPLogits(
        logits: [Float],
        temperature: Float,
        topP: Float
    ) -> Int {
        guard !logits.isEmpty else { return 0 }

        let clippedTemperature = max(0.05, temperature)
        let clippedTopP = Double(min(1.0, max(0.01, topP)))
        let maxLogit = logits.max() ?? 0

        var weightedLogits: [(index: Int, weight: Double)] = []
        weightedLogits.reserveCapacity(logits.count)
        for (index, logit) in logits.enumerated() {
            let scaled = Double((logit - maxLogit) / clippedTemperature)
            let stabilized = min(80.0, max(-80.0, scaled))
            let weight = exp(stabilized)
            if weight.isFinite && weight > 0 {
                weightedLogits.append((index, weight))
            }
        }

        guard !weightedLogits.isEmpty else {
            let greedyIndex = logits.indices.max(by: { logits[$0] < logits[$1] }) ?? 0
            return greedyIndex
        }

        weightedLogits.sort { $0.weight > $1.weight }

        let totalWeight = weightedLogits.reduce(into: 0.0) { partialResult, element in
            partialResult += element.weight
        }
        guard totalWeight > 0 else {
            return weightedLogits[0].index
        }

        var nucleus: [(index: Int, weight: Double)] = []
        nucleus.reserveCapacity(weightedLogits.count)

        var cumulative = 0.0
        for entry in weightedLogits {
            nucleus.append(entry)
            cumulative += entry.weight
            if cumulative / totalWeight >= clippedTopP {
                break
            }
        }

        let nucleusTotal = nucleus.reduce(into: 0.0) { partialResult, entry in
            partialResult += entry.weight
        }
        guard nucleusTotal > 0 else {
            return nucleus[0].index
        }

        let pivot = Double.random(in: 0..<1)
        var sampled = 0.0
        for entry in nucleus {
            sampled += entry.weight / nucleusTotal
            if pivot <= sampled {
                return entry.index
            }
        }

        return nucleus.last?.index ?? weightedLogits[0].index
    }
}
