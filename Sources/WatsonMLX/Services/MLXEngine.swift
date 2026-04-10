import Foundation
import MLX
import MLXNN
import MLXLMHFAPI
import MLXLMTokenizers
import MLXLMCommon
import WatsonDomain

public enum MLXError: LocalizedError {
    case modelNotLoaded
    case loadingError(String)
    case generationError(String)
    case memoryError
    case invalidPrompt
    case unsupportedConfiguration(WatsonDomain.ModelConfiguration)
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
    private let modelLoader = MLXModelLoader()
    private let weightMapper = MLXWeightMapper()
    private let generator = MLXGenerator()

    private var model: MLXLoadedModel?
    private var tokenizer: (any MLXLMCommon.Tokenizer)?
    private var isLoaded = false
    private var modelID = ""
    private var stopTokenIDs: [Int] = [1]

    public init() {
        Memory.cacheLimit = 1024 * 1024 * 512
    }

    public nonisolated func supports(config: WatsonDomain.ModelConfiguration) -> Bool {
        config.providerKind == .mlxNative && config.format == .gemma4
    }

    public func loadModel(config: WatsonDomain.ModelConfiguration) async throws {
        guard supports(config: config) else {
            throw MLXError.unsupportedConfiguration(config)
        }

        isLoaded = false
        model = nil
        tokenizer = nil
        modelID = config.modelPathOrID
        stopTokenIDs = [1]

        do {
            let preparedModel = try await modelLoader.prepareModel(modelID: modelID)
            let weights = try weightMapper.loadWeights(
                from: preparedModel.modelDirectory,
                strategy: preparedModel.loadingPlan.weightStrategy
            )
            preparedModel.loadingPlan.model.update(parameters: weights)

            tokenizer = try await modelLoader.loadTokenizer(from: preparedModel.modelDirectory)
            model = preparedModel.loadingPlan.model
            stopTokenIDs = preparedModel.stopTokenIDs
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

    public func generate(prompt: String, options: GenerationOptions) -> AsyncThrowingStream<String, Error> {
        generator.generate(
            prompt: prompt,
            options: options,
            isLoaded: isLoaded,
            model: model,
            tokenizer: tokenizer,
            stopTokenIDs: stopTokenIDs
        )
    }

    public func unload() {
        model = nil
        tokenizer = nil
        isLoaded = false
        modelID = ""
        stopTokenIDs = [1]
    }
}
