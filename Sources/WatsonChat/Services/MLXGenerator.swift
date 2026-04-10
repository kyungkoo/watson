import Foundation
import MLX
import MLXLMCommon

internal struct MLXGenerator {
    func generate(
        prompt: String,
        maxTokens: Int,
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
                var emittedText = ""

                while count < maxTokens {
                    if Task.isCancelled {
                        break
                    }

                    let input = MLXArray(tokenIDs).reshaped(1, -1)
                    let logits = model.forward(input)
                    let lastLogits = logits[0, -1, 0...]

                    let nextTokenArray = argMax(lastLogits, axis: -1)
                    let nextTokenID = Int(nextTokenArray.item(Int32.self))

                    if stopTokenIDs.contains(nextTokenID) {
                        break
                    }

                    tokenIDs.append(nextTokenID)
                    generatedTokenIDs.append(nextTokenID)

                    let decodedText = tokenizer.decode(
                        tokenIds: generatedTokenIDs,
                        skipSpecialTokens: true
                    )
                    let commonPrefix = emittedText.commonPrefix(with: decodedText)
                    let delta = String(decodedText.dropFirst(commonPrefix.count))
                    if !delta.isEmpty {
                        continuation.yield(delta)
                    }
                    emittedText = decodedText

                    count += 1
                    await Task.yield()
                }

                continuation.finish()
            }

            continuation.onTermination = { @Sendable _ in
                generationTask.cancel()
            }
        }
    }
}
