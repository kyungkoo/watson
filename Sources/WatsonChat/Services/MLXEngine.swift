import Foundation
import MLX
import MLXRandom
import MLXNN

public enum MLXError: LocalizedError {
    case modelNotLoaded
    case loadingError(String)
    case generationError(String)
    case memoryError
    case invalidPrompt
    
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
        }
    }
}

public actor MLXEngine {
    private var isLoaded = false
    private var modelID: String = ""
    
    // TODO: 실제 모델 로드 후 참조할 변수들
    // private var model: LLMModel? 
    // private var tokenizer: Tokenizer?

    public init() {}

    /// HuggingFace ID 또는 로컬 경로를 통해 MLX 가중치를 로드합니다.
    public func loadModel(config: ModelConfiguration) async throws {
        self.isLoaded = false
        self.modelID = config.modelPathOrID
        
        do {
            // 실제 MLX 로드 로직이 들어갈 자리입니다.
            // HuggingFace 허브에서 파일을 다운로드하거나 로컬 경로에서 로드합니다.
            
            // 모델 로딩 시뮬레이션
            try await Task.sleep(for: .seconds(1.5)) 
            
            // 시뮬레이션 중 오류 발생 상황 (예: 네트워크 오류 등)
            // if (config.modelPathOrID.isEmpty) {
            //     throw MLXError.loadingError("모델 경로가 비어있습니다.")
            // }
            
            self.isLoaded = true
        } catch let error as MLXError {
            throw error
        } catch {
            throw MLXError.loadingError(error.localizedDescription)
        }
    }

    /// 프롬프트를 받아 비동기 스트림으로 토큰을 하나씩 반환합니다.
    public func generate(prompt: String, maxTokens: Int) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let generationTask = Task(priority: .userInitiated) {
                guard isLoaded else {
                    continuation.finish(throwing: MLXError.modelNotLoaded)
                    return
                }
                
                guard !prompt.isEmpty else {
                    continuation.finish(throwing: MLXError.invalidPrompt)
                    return
                }
                
                do {
                    // 실제 추론 로직 (MLX를 통한 토큰 생성)
                    // let tokenStream = try await model.generate(prompt: prompt)
                    // for try await token in tokenStream { continuation.yield(token) }
                    
                    // --- 시뮬레이션용 가짜 응답 ---
                    let dummyResponse = "안녕하세요! \(modelID) 모델이 로컬에서 정상적으로 구동되고 있습니다. 무엇을 도와드릴까요?"
                    for char in dummyResponse {
                        if Task.isCancelled { break }
                        try await Task.sleep(for: .milliseconds(30))
                        continuation.yield(String(char))
                    }
                    // ----------------------------
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: MLXError.generationError(error.localizedDescription))
                }
            }
            
            continuation.onTermination = { @Sendable _ in
                generationTask.cancel()
            }
        }
    }
}
