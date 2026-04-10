import Foundation
import MLX
import MLXNN

/// Gemma 4 config.json의 루트 구조
public struct GemmaRootConfiguration: Codable, Sendable {
    public let textConfig: GemmaConfiguration
    
    enum CodingKeys: String, CodingKey {
        case textConfig = "text_config"
    }
}

/// Gemma 모델의 상세 설정값들
public struct GemmaConfiguration: Codable, Sendable {
    public let modelType: String
    public let hiddenSize: Int
    public let numHiddenLayers: Int
    public let numAttentionHeads: Int
    public let numKeyValueHeads: Int
    public let intermediateSize: Int
    public let vocabSize: Int
    public let rmsNormEps: Float
    public let headDim: Int
    
    enum CodingKeys: String, CodingKey {
        case modelType = "model_type"
        case hiddenSize = "hidden_size"
        case numHiddenLayers = "num_hidden_layers"
        case numAttentionHeads = "num_attention_heads"
        case numKeyValueHeads = "num_key_value_heads"
        case intermediateSize = "intermediate_size"
        case vocabSize = "vocab_size"
        case rmsNormEps = "rms_norm_eps"
        case headDim = "head_dim"
    }
}

/// Attention 레이어 (RoPE 적용)
final class Attention: Module {
    let heads: Int
    let kvHeads: Int
    let scale: Float
    
    let wq: Linear
    let wk: Linear
    let wv: Linear
    let wo: Linear
    
    let rope: RoPE
    
    init(_ config: GemmaConfiguration) {
        self.heads = config.numAttentionHeads
        self.kvHeads = config.numKeyValueHeads
        self.scale = pow(Float(config.headDim), -0.5)
        
        self.wq = Linear(config.hiddenSize, config.numAttentionHeads * config.headDim, bias: false)
        self.wk = Linear(config.hiddenSize, config.numKeyValueHeads * config.headDim, bias: false)
        self.wv = Linear(config.hiddenSize, config.numKeyValueHeads * config.headDim, bias: false)
        self.wo = Linear(config.numAttentionHeads * config.headDim, config.hiddenSize, bias: false)
        
        self.rope = RoPE(dimensions: config.headDim, traditional: false)
    }
    
    func callAsFunction(_ x: MLXArray, mask: MLXArray? = nil) -> MLXArray {
        let q = wq(x)
        let k = wk(x)
        let v = wv(x)
        
        let B = x.dim(0)
        let L = x.dim(1)
        
        // Multi-head 분리
        let q_split = q.reshaped(B, L, heads, -1).transposed(0, 2, 1, 3)
        let k_split = k.reshaped(B, L, kvHeads, -1).transposed(0, 2, 1, 3)
        let v_split = v.reshaped(B, L, kvHeads, -1).transposed(0, 2, 1, 3)
        
        // RoPE 적용
        let q_rope = rope(q_split)
        let k_rope = rope(k_split)
        
        // Scaled Dot-Product Attention
        var scores = matmul(q_rope, k_rope.transposed(0, 1, 3, 2)) * scale
        if let mask = mask {
            scores = scores + mask
        }
        let weights = softmax(scores, axis: -1)
        let out = matmul(weights, v_split).transposed(0, 2, 1, 3).reshaped(B, L, -1)
        
        return wo(out)
    }
}

/// Feed Forward 레이어 (GeGLU)
final class MLP: Module {
    let gate: Linear
    let up: Linear
    let down: Linear
    
    init(_ config: GemmaConfiguration) {
        self.gate = Linear(config.hiddenSize, config.intermediateSize, bias: false)
        self.up = Linear(config.hiddenSize, config.intermediateSize, bias: false)
        self.down = Linear(config.intermediateSize, config.hiddenSize, bias: false)
    }
    
    func callAsFunction(_ x: MLXArray) -> MLXArray {
        return down(gelu(gate(x)) * up(x))
    }
}

/// Transformer Layer Block
final class TransformerBlock: Module {
    let attention: Attention
    let feedForward: MLP
    let attentionNorm: RMSNorm
    let ffnNorm: RMSNorm
    
    init(_ config: GemmaConfiguration) {
        self.attention = Attention(config)
        self.feedForward = MLP(config)
        self.attentionNorm = RMSNorm(dimensions: config.hiddenSize, eps: config.rmsNormEps)
        self.ffnNorm = RMSNorm(dimensions: config.hiddenSize, eps: config.rmsNormEps)
    }
    
    func callAsFunction(_ x: MLXArray, mask: MLXArray? = nil) -> MLXArray {
        var h = x + attention(attentionNorm(x), mask: mask)
        h = h + feedForward(ffnNorm(h))
        return h
    }
}

/// Gemma 메인 모델 클래스
public final class GemmaModel: Module {
    let embed: Embedding
    let layers: [TransformerBlock]
    let norm: RMSNorm
    
    public init(_ config: GemmaConfiguration) {
        self.embed = Embedding(embeddingCount: config.vocabSize, dimensions: config.hiddenSize)
        self.layers = (0..<config.numHiddenLayers).map { _ in TransformerBlock(config) }
        self.norm = RMSNorm(dimensions: config.hiddenSize, eps: config.rmsNormEps)
    }
    
    public func callAsFunction(_ x: MLXArray) -> MLXArray {
        var h = embed(x)
        
        // Causal Mask 생성
        let mask = MultiHeadAttention.createAdditiveCausalMask(x.dim(1))
        
        for layer in layers {
            h = layer(h, mask: mask)
        }
        
        h = norm(h)
        return matmul(h, embed.weight.transposed())
    }
}
