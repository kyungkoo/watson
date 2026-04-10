import Foundation
import MLX
import MLXNN
import MLXLMHFAPI
import MLXLMTokenizers
import MLXLMCommon

public enum MLXError: LocalizedError {
    case modelNotLoaded
    case loadingError(String)
    case generationError(String)
    case memoryError
    case invalidPrompt
    case unsupportedConfiguration(ModelConfiguration)
    case unsupportedMultimodal(String)

    public var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "모델이 아직 로드되지 않았습니다."
        case .loadingError(let message):
            return "모델 로드 중 오류 발생: \(message)"
        case .generationError(let message):
            return "텍스트 생성 중 오류 발생: \(message)"
        case .memoryError:
            return "메모리가 부족하여 모델을 로드하거나 실행할 수 없습니다."
        case .invalidPrompt:
            return "프롬프트 형식이 잘못되었습니다."
        case .unsupportedConfiguration(let config):
            return "현재 MLX provider는 \(config.id) 설정을 지원하지 않습니다."
        case .unsupportedMultimodal(let message):
            return message
        }
    }
}

public actor MLXEngine {
    private enum WeightLoadingStrategy {
        case gemma4TextOnly
        case compatibility
    }

    private struct LoadingPlan {
        let model: LoadedModel
        let weightStrategy: WeightLoadingStrategy
    }

    private enum LoadedModel {
        case gemma(GemmaModel)
        case gemma4Text(Gemma4TextLanguageModel)

        func forward(_ input: MLXArray) -> MLXArray {
            switch self {
            case .gemma(let model):
                return model(input)
            case .gemma4Text(let model):
                return model(input)
            }
        }

        func update(parameters: ModuleParameters) {
            switch self {
            case .gemma(let model):
                model.update(parameters: parameters)
            case .gemma4Text(let model):
                model.update(parameters: parameters)
            }
        }
    }

    private var model: LoadedModel?
    private var tokenizer: (any MLXLMCommon.Tokenizer)?
    private var isLoaded = false
    private var modelID = ""
    private var stopTokenIDs: [Int] = [1]

    public init() {
        Memory.cacheLimit = 1024 * 1024 * 512
    }

    public nonisolated func supports(config: ModelConfiguration) -> Bool {
        config.providerKind == .mlxNative && config.format == .gemma4
    }

    public func loadModel(config: ModelConfiguration) async throws {
        guard supports(config: config) else {
            throw MLXError.unsupportedConfiguration(config)
        }

        isLoaded = false
        model = nil
        tokenizer = nil
        modelID = config.modelPathOrID
        stopTokenIDs = [1]

        do {
            print("[\(modelID)] 가중치 및 설정 다운로드 중...")
            let hub = HubClient.default

            let modelDirectory = try await hub.download(
                id: modelID,
                revision: "main",
                matching: ["*.json", "*.safetensors", "*.model"],
                useLatest: false,
                progressHandler: { progress in
                    print("다운로드 진행: \(Int(progress.fractionCompleted * 100))%")
                }
            )

            let configFile = modelDirectory.appendingPathComponent("config.json")
            let configData = try Data(contentsOf: configFile)
            let rootJSON = try parseJSONObject(from: configData)

            let loadingPlan = try buildLoadingPlan(from: configData, rootJSON: rootJSON)
            stopTokenIDs = try resolveStopTokenIDs(from: modelDirectory, rootJSON: rootJSON)

            let weights = try loadWeights(from: modelDirectory, strategy: loadingPlan.weightStrategy)
            loadingPlan.model.update(parameters: weights)

            let loader = TokenizersLoader()
            tokenizer = try await loader.load(from: modelDirectory)

            model = loadingPlan.model
            isLoaded = true
            print("[\(modelID)] 모델 로드 완료 (GPU 준비됨)")
        } catch let error as MLXError {
            print("로드 오류: \(error)")
            throw error
        } catch {
            print("로드 오류: \(error)")
            throw MLXError.loadingError(error.localizedDescription)
        }
    }

    public func generate(prompt: String, maxTokens: Int) -> AsyncThrowingStream<String, Error> {
        let isLoaded = self.isLoaded
        let model = self.model
        let tokenizer = self.tokenizer
        let stopTokenIDs = Set(self.stopTokenIDs)
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

    public func unload() {
        model = nil
        tokenizer = nil
        isLoaded = false
        modelID = ""
        stopTokenIDs = [1]
    }

    private func buildLoadingPlan(from configData: Data, rootJSON: [String: Any]) throws -> LoadingPlan {
        if isGemma4TextModel(rootJSON: rootJSON) {
            let textConfig = try JSONDecoder().decode(Gemma4TextConfiguration.self, from: configData)
            return LoadingPlan(
                model: .gemma4Text(Gemma4TextLanguageModel(textConfig)),
                weightStrategy: .gemma4TextOnly
            )
        }

        if let rootConfig = try? JSONDecoder().decode(GemmaRootConfiguration.self, from: configData) {
            return LoadingPlan(
                model: .gemma(GemmaModel(rootConfig.textConfig)),
                weightStrategy: .compatibility
            )
        }

        if let directConfig = try? JSONDecoder().decode(GemmaConfiguration.self, from: configData) {
            return LoadingPlan(
                model: .gemma(GemmaModel(directConfig)),
                weightStrategy: .compatibility
            )
        }

        if hasMultimodalOnlyConfiguration(rootJSON: rootJSON) {
            throw MLXError.unsupportedMultimodal(
                "멀티모달 입력은 아직 지원하지 않습니다. Gemma4 text_config / language_model 경로의 텍스트 생성만 지원합니다."
            )
        }

        throw MLXError.loadingError("지원하지 않는 모델 설정 형식입니다.")
    }

    private func loadWeights(from directory: URL, strategy: WeightLoadingStrategy) throws -> ModuleParameters {
        let fileManager = FileManager.default
        let files = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        let safetensorsFiles = files
            .filter { $0.pathExtension == "safetensors" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        guard !safetensorsFiles.isEmpty else {
            throw MLXError.loadingError("safetensors 가중치 파일을 찾지 못했습니다.")
        }

        var allWeights = [String: MLXArray]()
        for file in safetensorsFiles {
            let weights = try MLX.loadArrays(url: file)
            for (key, value) in weights {
                allWeights[key] = value
            }
        }

        let filteredWeights = try filterWeights(allWeights, strategy: strategy)
        let mappedWeights = try mapWeights(filteredWeights, strategy: strategy)
        return ModuleParameters.unflattened(mappedWeights)
    }

    private func filterWeights(
        _ weights: [String: MLXArray],
        strategy: WeightLoadingStrategy
    ) throws -> [String: MLXArray] {
        switch strategy {
        case .compatibility:
            return weights
        case .gemma4TextOnly:
            let preferredPrefix = "model.language_model."
            let fallbackPrefix = "language_model."

            let preferredWeights = weights.filter { $0.key.hasPrefix(preferredPrefix) }
            if !preferredWeights.isEmpty {
                return preferredWeights
            }

            let fallbackWeights = weights.filter { $0.key.hasPrefix(fallbackPrefix) }
            if !fallbackWeights.isEmpty {
                return fallbackWeights
            }

            throw MLXError.unsupportedMultimodal(
                "Gemma4 텍스트 로드 경로를 찾지 못했습니다. model.language_model.* 가중치만 지원합니다."
            )
        }
    }

    private func mapWeights(
        _ weights: [String: MLXArray],
        strategy: WeightLoadingStrategy
    ) throws -> [String: MLXArray] {
        switch strategy {
        case .compatibility:
            return mapCompatibilityWeights(weights)
        case .gemma4TextOnly:
            return try mapGemma4TextWeights(weights)
        }
    }

    private func mapGemma4TextWeights(_ weights: [String: MLXArray]) throws -> [String: MLXArray] {
        var mappedWeights = [String: MLXArray]()

        for (key, value) in weights {
            guard let normalizedKey = normalizeGemma4WeightKey(key) else {
                continue
            }
            mappedWeights[normalizedKey] = value
        }

        try validateGemma4RequiredKeys(in: Set(mappedWeights.keys))
        return mappedWeights
    }

    private func mapCompatibilityWeights(_ weights: [String: MLXArray]) -> [String: MLXArray] {
        var flatMappedWeights = [String: MLXArray]()

        for (key, value) in weights {
            guard let normalizedKey = normalizeCompatibilityWeightKey(key) else {
                continue
            }

            var newKey = normalizedKey
            let mapping = [
                "embed_tokens.weight": "embed.weight",
                "input_layernorm.weight": "attentionNorm.weight",
                "post_attention_layernorm.weight": "ffnNorm.weight",
                "pre_feedforward_layernorm.weight": "ffnNorm.weight",
                "self_attn.q_proj.weight": "attention.wq.weight",
                "self_attn.k_proj.weight": "attention.wk.weight",
                "self_attn.v_proj.weight": "attention.wv.weight",
                "self_attn.o_proj.weight": "attention.wo.weight",
                "mlp.gate_proj.weight": "feedForward.gate.weight",
                "mlp.up_proj.weight": "feedForward.up.weight",
                "mlp.down_proj.weight": "feedForward.down.weight",
                "norm.weight": "norm.weight"
            ]

            for (old, new) in mapping {
                newKey = newKey.replacingOccurrences(of: old, with: new)
            }

            flatMappedWeights[newKey] = value
        }

        return flatMappedWeights
    }

    private func validateGemma4RequiredKeys(in keys: Set<String>) throws {
        let requiredKeys = [
            "embed_tokens.weight",
            "layers.0.self_attn.q_proj.weight",
            "layers.0.self_attn.k_proj.weight",
            "layers.0.self_attn.v_proj.weight",
            "layers.0.mlp.gate_proj.weight",
            "norm.weight"
        ]

        let missing = requiredKeys.filter { !keys.contains($0) }
        guard missing.isEmpty else {
            throw MLXError.loadingError(
                "Gemma4 language_model 필수 가중치가 누락되었습니다: \(missing.joined(separator: ", "))"
            )
        }
    }

    private func normalizeGemma4WeightKey(_ key: String) -> String? {
        if key == "__metadata__" {
            return nil
        }

        let ignoredSuffixes = [
            ".scales",
            ".biases",
            ".inv_freq"
        ]
        if ignoredSuffixes.contains(where: { key.hasSuffix($0) }) {
            return nil
        }

        let normalizedKey = stripKnownPrefixes(
            from: key,
            prefixes: ["model.language_model.", "language_model.", "model."]
        )

        let ignoredFragments = [
            "vision_model",
            "vision_tower",
            "multi_modal_projector",
            "audio_model",
            "audio_tower",
            "image_newline",
            "mm_projector",
            "lm_head",
            "rotary_emb"
        ]
        if ignoredFragments.contains(where: { normalizedKey.contains($0) }) {
            return nil
        }

        if normalizedKey.isEmpty {
            return nil
        }

        return normalizedKey
    }

    private func normalizeCompatibilityWeightKey(_ key: String) -> String? {
        let ignoredSuffixes = [
            ".scales",
            ".biases",
            ".inv_freq"
        ]
        if ignoredSuffixes.contains(where: { key.hasSuffix($0) }) {
            return nil
        }

        let normalizedKey = stripKnownPrefixes(
            from: key,
            prefixes: ["model.language_model.", "language_model.", "model."]
        )

        let ignoredFragments = [
            "vision_tower",
            "multi_modal_projector",
            "q_norm",
            "k_norm",
            "post_feedforward_layernorm",
            "per_layer_input",
            "per_layer_projection",
            "layer_scalar",
            "lm_head"
        ]
        if ignoredFragments.contains(where: { normalizedKey.contains($0) }) {
            return nil
        }

        return normalizedKey
    }

    private func stripKnownPrefixes(from key: String, prefixes: [String]) -> String {
        var result = key
        var stripped = true

        while stripped {
            stripped = false
            for prefix in prefixes where result.hasPrefix(prefix) {
                result.removeFirst(prefix.count)
                stripped = true
                break
            }
        }

        return result
    }

    private func parseJSONObject(from data: Data) throws -> [String: Any] {
        let json = try JSONSerialization.jsonObject(with: data)
        guard let dictionary = json as? [String: Any] else {
            throw MLXError.loadingError("config.json 형식이 올바르지 않습니다.")
        }
        return dictionary
    }

    private func isGemma4TextModel(rootJSON: [String: Any]) -> Bool {
        let modelType = (rootJSON["model_type"] as? String)?.lowercased()
        let textConfig = rootJSON["text_config"] as? [String: Any]
        let textModelType = (textConfig?["model_type"] as? String)?.lowercased()

        return modelType == "gemma4" || textModelType == "gemma4" || textModelType == "gemma4_text"
    }

    private func hasMultimodalOnlyConfiguration(rootJSON: [String: Any]) -> Bool {
        let hasTextConfig = rootJSON["text_config"] != nil
        let hasVisionConfig = rootJSON["vision_config"] != nil
        return hasVisionConfig && !hasTextConfig
    }

    private func resolveStopTokenIDs(from modelDirectory: URL, rootJSON: [String: Any]) throws -> [Int] {
        let generationConfigFile = modelDirectory.appendingPathComponent("generation_config.json")
        if FileManager.default.fileExists(atPath: generationConfigFile.path) {
            let generationConfigData = try Data(contentsOf: generationConfigFile)
            let generationJSON = try parseJSONObject(from: generationConfigData)
            if let stopTokenIDs = extractStopTokenIDs(from: generationJSON), !stopTokenIDs.isEmpty {
                return stopTokenIDs
            }
        }

        if let stopTokenIDs = extractStopTokenIDs(from: rootJSON), !stopTokenIDs.isEmpty {
            return stopTokenIDs
        }

        return [1]
    }

    private func extractStopTokenIDs(from json: [String: Any]) -> [Int]? {
        guard let eosToken = json["eos_token_id"] else {
            return nil
        }

        if let token = eosToken as? Int {
            return [token]
        }

        if let token = eosToken as? NSNumber {
            return [token.intValue]
        }

        if let tokens = eosToken as? [Int] {
            return tokens
        }

        if let tokens = eosToken as? [NSNumber] {
            return tokens.map(\.intValue)
        }

        return nil
    }
}
