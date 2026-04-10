import Foundation
import MLX
import MLXNN

internal enum MLXLoadedModel {
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

internal struct MLXWeightMapper {
    func loadWeights(from directory: URL, strategy: MLXWeightLoadingStrategy) throws -> ModuleParameters {
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
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
        strategy: MLXWeightLoadingStrategy
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
        strategy: MLXWeightLoadingStrategy
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
}
