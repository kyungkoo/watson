import Foundation
import MLXLMHFAPI
import MLXLMCommon
import MLXLMTokenizers
import WatsonDomain

internal enum MLXWeightLoadingStrategy {
    case gemma4TextOnly
    case compatibility
}

internal struct MLXLoadingPlan {
    let model: MLXLoadedModel
    let weightStrategy: MLXWeightLoadingStrategy
}

internal struct MLXPreparedModel {
    let modelDirectory: URL
    let loadingPlan: MLXLoadingPlan
    let stopTokenIDs: [Int]
}

internal struct MLXModelLoader {
    func prepareModel(
        modelID: String,
        onStateChange: @Sendable @escaping (ModelLoadState) -> Void = { _ in }
    ) async throws -> MLXPreparedModel {
        print("[\(modelID)] 가중치 및 설정 다운로드 중...")
        let hub = HubClient.default
        let progressRelay = DownloadProgressRelay(onStateChange: onStateChange)

        let modelDirectory = try await hub.download(
            id: modelID,
            revision: "main",
            matching: ["*.json", "*.safetensors", "*.model"],
            useLatest: false,
            progressHandler: { progress in
                let percent = progressRelay.report(progress)
                if let percent {
                    print("다운로드 진행: \(percent)%")
                }
            }
        )

        let configFile = modelDirectory.appendingPathComponent("config.json")
        let configData = try Data(contentsOf: configFile)
        let rootJSON = try parseJSONObject(from: configData)

        return MLXPreparedModel(
            modelDirectory: modelDirectory,
            loadingPlan: try buildLoadingPlan(from: configData, rootJSON: rootJSON),
            stopTokenIDs: try resolveStopTokenIDs(from: modelDirectory, rootJSON: rootJSON)
        )
    }

    func loadTokenizer(from modelDirectory: URL) async throws -> any MLXLMCommon.Tokenizer {
        let loader = TokenizersLoader()
        return try await loader.load(from: modelDirectory)
    }

    private func buildLoadingPlan(from configData: Data, rootJSON: [String: Any]) throws -> MLXLoadingPlan {
        if isGemma4TextModel(rootJSON: rootJSON) {
            let textConfig = try JSONDecoder().decode(Gemma4TextConfiguration.self, from: configData)
            return MLXLoadingPlan(
                model: .gemma4Text(Gemma4TextLanguageModel(textConfig)),
                weightStrategy: .gemma4TextOnly
            )
        }

        if let rootConfig = try? JSONDecoder().decode(GemmaRootConfiguration.self, from: configData) {
            return MLXLoadingPlan(
                model: .gemma(GemmaModel(rootConfig.textConfig)),
                weightStrategy: .compatibility
            )
        }

        if let directConfig = try? JSONDecoder().decode(GemmaConfiguration.self, from: configData) {
            return MLXLoadingPlan(
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

private final class DownloadProgressRelay: @unchecked Sendable {
    private let lock = NSLock()
    private let onStateChange: @Sendable (ModelLoadState) -> Void
    private var lastReportedPercent: Int?

    init(onStateChange: @escaping @Sendable (ModelLoadState) -> Void) {
        self.onStateChange = onStateChange
    }

    func report(_ progress: Progress) -> Int? {
        let percent = min(100, max(0, Int(progress.fractionCompleted * 100)))

        lock.lock()
        guard percent != lastReportedPercent else {
            lock.unlock()
            return nil
        }
        lastReportedPercent = percent
        lock.unlock()

        onStateChange(.downloading(percent: percent))
        return percent
    }
}
