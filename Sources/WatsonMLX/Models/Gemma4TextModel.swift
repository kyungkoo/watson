import Foundation
import MLX
import MLXNN

public struct Gemma4RootConfiguration: Codable, Sendable {
    public let textConfig: Gemma4TextConfiguration

    enum CodingKeys: String, CodingKey {
        case textConfig = "text_config"
    }
}

struct Gemma4RoPEConfiguration: Codable, Sendable {
    let ropeTheta: Float
    let ropeType: String?
    let partialRotaryFactor: Float?

    enum CodingKeys: String, CodingKey {
        case ropeTheta = "rope_theta"
        case ropeType = "rope_type"
        case partialRotaryFactor = "partial_rotary_factor"
    }
}

public struct Gemma4TextConfiguration: Codable, Sendable {
    public let modelType: String
    public let hiddenSize: Int
    public let intermediateSize: Int
    public let numHiddenLayers: Int
    public let numAttentionHeads: Int
    public let numKeyValueHeads: Int
    public let numGlobalKeyValueHeads: Int?
    public let headDim: Int
    public let globalHeadDim: Int?
    public let hiddenActivation: String
    public let maxPositionEmbeddings: Int
    public let rmsNormEps: Float
    public let vocabSize: Int
    public let vocabSizePerLayerInput: Int
    public let tieWordEmbeddings: Bool
    public let attentionBias: Bool
    public let attentionKEqV: Bool
    public let slidingWindow: Int
    public let layerTypes: [String]
    public let hiddenSizePerLayerInput: Int
    public let numKVSharedLayers: Int
    public let enableMoeBlock: Bool
    public let numExperts: Int
    public let topKExperts: Int
    public let moeIntermediateSize: Int
    public let useDoubleWideMLP: Bool
    public let finalLogitSoftcapping: Float?
    let ropeParameters: [String: Gemma4RoPEConfiguration]

    enum CodingKeys: String, CodingKey {
        case modelType = "model_type"
        case hiddenSize = "hidden_size"
        case intermediateSize = "intermediate_size"
        case numHiddenLayers = "num_hidden_layers"
        case numAttentionHeads = "num_attention_heads"
        case numKeyValueHeads = "num_key_value_heads"
        case numGlobalKeyValueHeads = "num_global_key_value_heads"
        case headDim = "head_dim"
        case globalHeadDim = "global_head_dim"
        case hiddenActivation = "hidden_activation"
        case maxPositionEmbeddings = "max_position_embeddings"
        case rmsNormEps = "rms_norm_eps"
        case vocabSize = "vocab_size"
        case vocabSizePerLayerInput = "vocab_size_per_layer_input"
        case tieWordEmbeddings = "tie_word_embeddings"
        case attentionBias = "attention_bias"
        case attentionKEqV = "attention_k_eq_v"
        case slidingWindow = "sliding_window"
        case layerTypes = "layer_types"
        case hiddenSizePerLayerInput = "hidden_size_per_layer_input"
        case numKVSharedLayers = "num_kv_shared_layers"
        case enableMoeBlock = "enable_moe_block"
        case numExperts = "num_experts"
        case topKExperts = "top_k_experts"
        case moeIntermediateSize = "moe_intermediate_size"
        case useDoubleWideMLP = "use_double_wide_mlp"
        case finalLogitSoftcapping = "final_logit_softcapping"
        case ropeParameters = "rope_parameters"
    }

    enum RootCodingKeys: String, CodingKey {
        case textConfig = "text_config"
    }

    public init(from decoder: Decoder) throws {
        let root = try decoder.container(keyedBy: RootCodingKeys.self)
        let container =
            if root.contains(.textConfig) {
                try root.nestedContainer(keyedBy: CodingKeys.self, forKey: .textConfig)
            } else {
                try decoder.container(keyedBy: CodingKeys.self)
            }

        modelType = try container.decodeIfPresent(String.self, forKey: .modelType) ?? "gemma4_text"
        hiddenSize = try container.decode(Int.self, forKey: .hiddenSize)
        intermediateSize = try container.decode(Int.self, forKey: .intermediateSize)
        numHiddenLayers = try container.decode(Int.self, forKey: .numHiddenLayers)
        numAttentionHeads = try container.decode(Int.self, forKey: .numAttentionHeads)
        numKeyValueHeads = try container.decode(Int.self, forKey: .numKeyValueHeads)
        numGlobalKeyValueHeads = try container.decodeIfPresent(Int.self, forKey: .numGlobalKeyValueHeads)
        headDim = try container.decode(Int.self, forKey: .headDim)
        globalHeadDim = try container.decodeIfPresent(Int.self, forKey: .globalHeadDim)
        hiddenActivation =
            try container.decodeIfPresent(String.self, forKey: .hiddenActivation) ?? "gelu_pytorch_tanh"
        maxPositionEmbeddings =
            try container.decodeIfPresent(Int.self, forKey: .maxPositionEmbeddings) ?? 131_072
        rmsNormEps = try container.decodeIfPresent(Float.self, forKey: .rmsNormEps) ?? 1e-6
        vocabSize = try container.decodeIfPresent(Int.self, forKey: .vocabSize) ?? 262_144
        vocabSizePerLayerInput =
            try container.decodeIfPresent(Int.self, forKey: .vocabSizePerLayerInput) ?? vocabSize
        tieWordEmbeddings = try container.decodeIfPresent(Bool.self, forKey: .tieWordEmbeddings) ?? true
        attentionBias = try container.decodeIfPresent(Bool.self, forKey: .attentionBias) ?? false
        attentionKEqV = try container.decodeIfPresent(Bool.self, forKey: .attentionKEqV) ?? false
        slidingWindow = try container.decodeIfPresent(Int.self, forKey: .slidingWindow) ?? 512
        hiddenSizePerLayerInput =
            try container.decodeIfPresent(Int.self, forKey: .hiddenSizePerLayerInput) ?? 256
        numKVSharedLayers = try container.decodeIfPresent(Int.self, forKey: .numKVSharedLayers) ?? 0
        enableMoeBlock = try container.decodeIfPresent(Bool.self, forKey: .enableMoeBlock) ?? false
        numExperts = try container.decodeIfPresent(Int.self, forKey: .numExperts) ?? (enableMoeBlock ? 1 : 0)
        topKExperts = try container.decodeIfPresent(Int.self, forKey: .topKExperts) ?? (enableMoeBlock ? 1 : 0)
        moeIntermediateSize =
            try container.decodeIfPresent(Int.self, forKey: .moeIntermediateSize) ?? intermediateSize
        useDoubleWideMLP = try container.decodeIfPresent(Bool.self, forKey: .useDoubleWideMLP) ?? false
        finalLogitSoftcapping =
            try container.decodeIfPresent(Float.self, forKey: .finalLogitSoftcapping)

        let defaultRopeParameters: [String: Gemma4RoPEConfiguration] = [
            "sliding_attention": .init(ropeTheta: 10_000, ropeType: "default", partialRotaryFactor: nil),
            "full_attention": .init(
                ropeTheta: 1_000_000,
                ropeType: "proportional",
                partialRotaryFactor: 0.25
            ),
        ]
        ropeParameters =
            try container.decodeIfPresent([String: Gemma4RoPEConfiguration].self, forKey: .ropeParameters)
            ?? defaultRopeParameters

        let decodedLayerTypes = try container.decodeIfPresent([String].self, forKey: .layerTypes)
        if var layerTypes = decodedLayerTypes {
            if layerTypes.count < numHiddenLayers {
                layerTypes.append(
                    contentsOf: Array(repeating: "full_attention", count: numHiddenLayers - layerTypes.count))
            }
            if layerTypes.count > numHiddenLayers {
                layerTypes = Array(layerTypes.prefix(numHiddenLayers))
            }
            self.layerTypes = layerTypes
        } else {
            let generated = (0 ..< numHiddenLayers).map { index in
                ((index + 1) % 6 == 0) ? "full_attention" : "sliding_attention"
            }
            self.layerTypes = generated
        }
    }

    public func layerType(for layerIndex: Int) -> String {
        layerTypes[layerIndex]
    }

    public func headDimension(for layerIndex: Int) -> Int {
        layerType(for: layerIndex) == "full_attention" ? (globalHeadDim ?? headDim) : headDim
    }

    fileprivate func ropeConfiguration(for layerIndex: Int) -> Gemma4RoPEConfiguration {
        let layerType = layerType(for: layerIndex)
        return ropeParameters[layerType]
            ?? (layerType == "full_attention"
                ? Gemma4RoPEConfiguration(
                    ropeTheta: 1_000_000,
                    ropeType: "proportional",
                    partialRotaryFactor: 0.25
                )
                : Gemma4RoPEConfiguration(
                    ropeTheta: 10_000,
                    ropeType: "default",
                    partialRotaryFactor: nil
                ))
    }
}

private enum Gemma4TextMath {
    static func activation(_ name: String, _ x: MLXArray) -> MLXArray {
        switch name {
        case "gelu":
            return gelu(x)
        case "silu":
            return silu(x)
        default:
            return geluApproximate(x)
        }
    }

    static func embeddingScale(dimensions: Int) -> Float {
        sqrt(Float(dimensions))
    }

    static func projectionScale(dimensions: Int) -> Float {
        1 / sqrt(Float(dimensions))
    }

    static func layerInputScale() -> Float {
        1 / sqrt(2)
    }

    static func makeAdditiveCausalMask(
        sequenceLength: Int,
        windowSize: Int?,
        dtype: DType
    ) -> MLXArray? {
        guard sequenceLength > 1 else {
            return nil
        }

        let indices = MLXArray(0 ..< sequenceLength)
        let queryPositions = expandedDimensions(indices, axis: 1)
        let keyPositions = expandedDimensions(indices, axis: 0)
        var visible = queryPositions .>= keyPositions

        if let windowSize {
            visible = visible & (queryPositions .< keyPositions + windowSize)
        }

        let mask = `where`(visible, MLXArray(0.0, dtype: dtype), MLXArray(-1e9, dtype: dtype))
        return expandedDimensions(expandedDimensions(mask, axis: 0), axis: 0)
    }
}

final class Gemma4RMSNormNoScale: Module {
    private let eps: Float

    init(eps: Float) {
        self.eps = eps
        super.init()
    }

    func callAsFunction(_ x: MLXArray) -> MLXArray {
        MLXFast.rmsNorm(x, weight: MLXArray.mlxNone, eps: eps)
    }
}

final class Gemma4ProportionalRoPE: Module {
    private let headDimension: Int
    private let freqs: MLXArray

    init(headDimension: Int, base: Float, partialRotaryFactor: Float) {
        self.headDimension = headDimension

        let clampedPartialFactor = max(0, min(partialRotaryFactor, 1))
        let ropeAngles = Int((clampedPartialFactor * Float(headDimension)) / 2)
        let rotatedDimension = max(0, min(headDimension, ropeAngles * 2))

        if rotatedDimension == 0 {
            self.freqs = MLXArray.zeros([headDimension / 2], dtype: .float32)
            super.init()
            return
        }

        let indices = MLXArray(stride(from: 0, to: rotatedDimension, by: 2)).asType(.float32)
        var rotatedFrequencies = 1.0 / pow(base, indices / Float(headDimension))

        let fullFrequencyCount = headDimension / 2
        if rotatedFrequencies.dim(0) < fullFrequencyCount {
            let unrotatedCount = fullFrequencyCount - rotatedFrequencies.dim(0)
            let zeros = MLXArray.zeros([unrotatedCount], dtype: .float32)
            rotatedFrequencies = concatenated([rotatedFrequencies, zeros], axis: 0)
        }

        self.freqs = rotatedFrequencies
        super.init()
    }

    func callAsFunction(_ x: MLXArray) -> MLXArray {
        MLXFast.RoPE(
            x,
            dimensions: headDimension,
            traditional: false,
            base: nil,
            scale: 1.0,
            offset: 0,
            freqs: freqs
        )
    }
}

final class Gemma4TextAttention: Module {
    private let config: Gemma4TextConfiguration
    private let layerIndex: Int
    private let layerType: String
    private let headDim: Int
    private let kvHeads: Int
    private let attentionHeads: Int
    private let repeats: Int
    private let scale: Float
    private let isKVSharedLayer: Bool
    private let kvSharedLayerIndex: Int?
    private let storeFullLengthKV: Bool
    private let rope: RoPE
    private let proportionalRoPE: Gemma4ProportionalRoPE?

    @ModuleInfo(key: "q_proj") var qProj: Linear
    @ModuleInfo(key: "k_proj") var kProj: Linear
    @ModuleInfo(key: "v_proj") var vProj: Linear
    @ModuleInfo(key: "o_proj") var oProj: Linear
    @ModuleInfo(key: "q_norm") var qNorm: RMSNorm
    @ModuleInfo(key: "k_norm") var kNorm: RMSNorm
    @ModuleInfo(key: "v_norm") var vNorm: Gemma4RMSNormNoScale

    init(_ config: Gemma4TextConfiguration, layerIndex: Int) {
        self.config = config
        self.layerIndex = layerIndex
        self.layerType = config.layerType(for: layerIndex)
        self.attentionHeads = config.numAttentionHeads
        self.kvHeads = config.numKeyValueHeads
        self.repeats = max(1, config.numAttentionHeads / max(config.numKeyValueHeads, 1))
        self.headDim = config.headDimension(for: layerIndex)
        self.scale = 1.0

        let firstKVSharedLayerIndex = config.numHiddenLayers - config.numKVSharedLayers
        if config.numKVSharedLayers > 0 && layerIndex >= firstKVSharedLayerIndex {
            self.isKVSharedLayer = true
            let previousLayerTypes = Array(config.layerTypes.prefix(max(firstKVSharedLayerIndex, 0)))
            self.kvSharedLayerIndex = previousLayerTypes.lastIndex(of: layerType)
            self.storeFullLengthKV = false
        } else {
            self.isKVSharedLayer = false
            self.kvSharedLayerIndex = nil
            let previousLayerTypes = Array(config.layerTypes.prefix(max(firstKVSharedLayerIndex, 0)))
            self.storeFullLengthKV = previousLayerTypes.lastIndex(of: layerType) == layerIndex
        }

        let ropeConfig = config.ropeConfiguration(for: layerIndex)
        self.rope = RoPE(
            dimensions: headDim,
            traditional: false,
            base: ropeConfig.ropeTheta
        )
        if ropeConfig.ropeType == "proportional" {
            self.proportionalRoPE = Gemma4ProportionalRoPE(
                headDimension: headDim,
                base: ropeConfig.ropeTheta,
                partialRotaryFactor: ropeConfig.partialRotaryFactor ?? 1.0
            )
        } else {
            self.proportionalRoPE = nil
        }

        self._qProj.wrappedValue = Linear(
            config.hiddenSize,
            config.numAttentionHeads * headDim,
            bias: config.attentionBias
        )
        self._kProj.wrappedValue = Linear(
            config.hiddenSize,
            config.numKeyValueHeads * headDim,
            bias: config.attentionBias
        )
        self._vProj.wrappedValue = Linear(
            config.hiddenSize,
            config.numKeyValueHeads * headDim,
            bias: config.attentionBias
        )
        self._oProj.wrappedValue = Linear(
            config.numAttentionHeads * headDim,
            config.hiddenSize,
            bias: config.attentionBias
        )
        self._qNorm.wrappedValue = RMSNorm(dimensions: headDim, eps: config.rmsNormEps)
        self._kNorm.wrappedValue = RMSNorm(dimensions: headDim, eps: config.rmsNormEps)
        self._vNorm.wrappedValue = Gemma4RMSNormNoScale(eps: config.rmsNormEps)

        super.init()
    }

    func callAsFunction(
        _ x: MLXArray,
        mask: MLXArray?,
        sharedKVStates: inout [Int: (keys: MLXArray, values: MLXArray)]
    ) -> MLXArray {
        let batchSize = x.dim(0)
        let sequenceLength = x.dim(1)

        var queries = qProj(x).reshaped(batchSize, sequenceLength, attentionHeads, headDim)
        var keys: MLXArray
        var values: MLXArray

        if isKVSharedLayer, let kvSharedLayerIndex, let sharedKV = sharedKVStates[kvSharedLayerIndex] {
            keys = sharedKV.keys
            values = sharedKV.values
        } else {
            keys = kProj(x).reshaped(batchSize, sequenceLength, kvHeads, headDim)
            values = vProj(x).reshaped(batchSize, sequenceLength, kvHeads, headDim)
            keys = kNorm(keys).transposed(0, 2, 1, 3)
            values = vNorm(values).transposed(0, 2, 1, 3)
        }

        queries = qNorm(queries).transposed(0, 2, 1, 3)

        if isKVSharedLayer {
            if let proportionalRoPE {
                queries = proportionalRoPE(queries)
            } else {
                queries = rope(queries)
            }
        } else {
            if let proportionalRoPE {
                queries = proportionalRoPE(queries)
                keys = proportionalRoPE(keys)
            } else {
                queries = rope(queries)
                keys = rope(keys)
            }

            if storeFullLengthKV {
                sharedKVStates[layerIndex] = (keys: keys, values: values)
            }
        }

        if repeats > 1 {
            keys = repeated(keys, count: repeats, axis: 1)
            values = repeated(values, count: repeats, axis: 1)
        }

        var scores = matmul(queries, keys.transposed(0, 1, 3, 2)) * scale
        if let mask {
            scores = scores + mask.asType(scores.dtype)
        }

        let weights = softmax(scores.asType(.float32), axis: -1).asType(values.dtype)
        let attended = matmul(weights, values)
            .transposed(0, 2, 1, 3)
            .reshaped(batchSize, sequenceLength, attentionHeads * headDim)

        return oProj(attended)
    }
}

final class Gemma4TextMLP: Module {
    private let activationName: String

    @ModuleInfo(key: "gate_proj") var gateProj: Linear
    @ModuleInfo(key: "up_proj") var upProj: Linear
    @ModuleInfo(key: "down_proj") var downProj: Linear

    init(_ config: Gemma4TextConfiguration, layerIndex: Int) {
        self.activationName = config.hiddenActivation
        let firstKVSharedLayerIndex = config.numHiddenLayers - config.numKVSharedLayers
        let isKVSharedLayer = config.numKVSharedLayers > 0 && layerIndex >= firstKVSharedLayerIndex
        let intermediateSize = config.intermediateSize * ((config.useDoubleWideMLP && isKVSharedLayer) ? 2 : 1)
        self._gateProj.wrappedValue = Linear(
            config.hiddenSize,
            intermediateSize,
            bias: false
        )
        self._upProj.wrappedValue = Linear(
            config.hiddenSize,
            intermediateSize,
            bias: false
        )
        self._downProj.wrappedValue = Linear(
            intermediateSize,
            config.hiddenSize,
            bias: false
        )

        super.init()
    }

    func callAsFunction(_ x: MLXArray) -> MLXArray {
        let gate = Gemma4TextMath.activation(activationName, gateProj(x))
        return downProj(gate * upProj(x))
    }
}

final class Gemma4TextRouter: Module {
    private let numExperts: Int
    private let topKExperts: Int
    private let scalarRootSize: Float

    @ModuleInfo(key: "norm") var norm: Gemma4RMSNormNoScale
    @ModuleInfo(key: "proj") var proj: Linear
    @ParameterInfo(key: "scale") var scale: MLXArray
    @ParameterInfo(key: "per_expert_scale") var perExpertScale: MLXArray

    init(_ config: Gemma4TextConfiguration) {
        self.numExperts = max(config.numExperts, 1)
        self.topKExperts = max(1, min(config.topKExperts, numExperts))
        self.scalarRootSize = pow(Float(config.hiddenSize), -0.5)

        self._norm.wrappedValue = Gemma4RMSNormNoScale(eps: config.rmsNormEps)
        self._proj.wrappedValue = Linear(config.hiddenSize, numExperts, bias: false)
        self._scale.wrappedValue = MLXArray.ones([config.hiddenSize], dtype: .float32)
        self._perExpertScale.wrappedValue = MLXArray.ones([numExperts], dtype: .float32)

        super.init()
    }

    func callAsFunction(_ hiddenStates: MLXArray) -> (
        routerProbabilities: MLXArray,
        topKWeights: MLXArray,
        topKIndex: MLXArray
    ) {
        var hiddenStates = norm(hiddenStates)
        hiddenStates = hiddenStates * scale.asType(hiddenStates.dtype) * scalarRootSize

        let expertScores = proj(hiddenStates)
        let routerProbabilities = softmax(expertScores.asType(.float32), axis: -1)

        let topKIndex = argPartition(-routerProbabilities, kth: topKExperts - 1, axis: -1)[
            .ellipsis, ..<topKExperts
        ]
        var topKWeights = takeAlong(routerProbabilities, topKIndex, axis: -1)
        topKWeights = topKWeights / (topKWeights.sum(axis: -1, keepDims: true) + 1e-20)
        topKWeights = topKWeights * perExpertScale[topKIndex].asType(topKWeights.dtype)

        return (routerProbabilities, topKWeights, topKIndex)
    }
}

final class Gemma4TextExperts: Module {
    private let numExperts: Int
    private let hiddenSize: Int
    private let intermediateSize: Int
    private let activationName: String

    @ParameterInfo(key: "gate_up_proj") var gateUpProj: MLXArray
    @ParameterInfo(key: "down_proj") var downProj: MLXArray

    init(_ config: Gemma4TextConfiguration) {
        self.numExperts = max(config.numExperts, 1)
        self.hiddenSize = config.hiddenSize
        self.intermediateSize = max(config.moeIntermediateSize, 1)
        self.activationName = config.hiddenActivation

        self._gateUpProj.wrappedValue = MLXArray.zeros(
            [numExperts, 2 * intermediateSize, hiddenSize],
            dtype: .float32
        )
        self._downProj.wrappedValue = MLXArray.zeros(
            [numExperts, hiddenSize, intermediateSize],
            dtype: .float32
        )

        super.init()
    }

    func callAsFunction(
        _ hiddenStates: MLXArray,
        topKIndex: MLXArray,
        topKWeights: MLXArray
    ) -> MLXArray {
        var combined = MLXArray.zeros([hiddenStates.dim(0), hiddenSize], dtype: hiddenStates.dtype)
        let routingWeights = topKWeights.asType(hiddenStates.dtype)

        for expertIndex in 0 ..< numExperts {
            let gateUpWeight = gateUpProj[expertIndex, 0..., 0...].asType(hiddenStates.dtype)
            let downWeight = downProj[expertIndex, 0..., 0...].asType(hiddenStates.dtype)

            let projected = matmul(hiddenStates, gateUpWeight.transposed())
            let gate = projected[0..., ..<intermediateSize]
            let up = projected[0..., intermediateSize...]

            let expertOutput = matmul(
                Gemma4TextMath.activation(activationName, gate) * up,
                downWeight.transposed()
            )
            let expertMask = (topKIndex .== MLXArray(expertIndex)).asType(hiddenStates.dtype)
            let expertRouting = (expertMask * routingWeights).sum(axis: -1, keepDims: true)

            combined = combined + expertOutput * expertRouting
        }

        return combined
    }
}

private enum Gemma4TextFeedForwardPath {
    case dense
    case mixtureOfExperts
}

final class Gemma4TextDecoderLayer: Module {
    private let activationName: String
    private let feedForwardPath: Gemma4TextFeedForwardPath
    private let usesPerLayerInput: Bool

    @ModuleInfo(key: "self_attn") var selfAttention: Gemma4TextAttention
    @ModuleInfo var mlp: Gemma4TextMLP
    @ModuleInfo(key: "router") var router: Gemma4TextRouter?
    @ModuleInfo(key: "experts") var experts: Gemma4TextExperts?
    @ModuleInfo(key: "input_layernorm") var inputLayerNorm: RMSNorm
    @ModuleInfo(key: "post_attention_layernorm") var postAttentionLayerNorm: RMSNorm
    @ModuleInfo(key: "pre_feedforward_layernorm") var preFeedforwardLayerNorm: RMSNorm
    @ModuleInfo(key: "post_feedforward_layernorm") var postFeedforwardLayerNorm: RMSNorm
    @ModuleInfo(key: "post_feedforward_layernorm_1") var postFeedforwardLayerNorm1: RMSNorm?
    @ModuleInfo(key: "post_feedforward_layernorm_2") var postFeedforwardLayerNorm2: RMSNorm?
    @ModuleInfo(key: "pre_feedforward_layernorm_2") var preFeedforwardLayerNorm2: RMSNorm?
    @ModuleInfo(key: "per_layer_input_gate") var perLayerInputGate: Linear
    @ModuleInfo(key: "per_layer_projection") var perLayerProjection: Linear
    @ModuleInfo(key: "post_per_layer_input_norm") var postPerLayerInputNorm: RMSNorm
    @ParameterInfo(key: "layer_scalar") var layerScalar: MLXArray

    init(_ config: Gemma4TextConfiguration, layerIndex: Int) {
        self.activationName = config.hiddenActivation
        self.feedForwardPath = config.enableMoeBlock ? .mixtureOfExperts : .dense
        self.usesPerLayerInput = config.hiddenSizePerLayerInput > 0

        self._selfAttention.wrappedValue = Gemma4TextAttention(config, layerIndex: layerIndex)
        self._mlp.wrappedValue = Gemma4TextMLP(config, layerIndex: layerIndex)
        if config.enableMoeBlock {
            self._router.wrappedValue = Gemma4TextRouter(config)
            self._experts.wrappedValue = Gemma4TextExperts(config)
        }
        self._inputLayerNorm.wrappedValue = RMSNorm(dimensions: config.hiddenSize, eps: config.rmsNormEps)
        self._postAttentionLayerNorm.wrappedValue = RMSNorm(
            dimensions: config.hiddenSize,
            eps: config.rmsNormEps
        )
        self._preFeedforwardLayerNorm.wrappedValue = RMSNorm(
            dimensions: config.hiddenSize,
            eps: config.rmsNormEps
        )
        self._postFeedforwardLayerNorm.wrappedValue = RMSNorm(
            dimensions: config.hiddenSize,
            eps: config.rmsNormEps
        )
        if config.enableMoeBlock {
            self._postFeedforwardLayerNorm1.wrappedValue = RMSNorm(
                dimensions: config.hiddenSize,
                eps: config.rmsNormEps
            )
            self._postFeedforwardLayerNorm2.wrappedValue = RMSNorm(
                dimensions: config.hiddenSize,
                eps: config.rmsNormEps
            )
            self._preFeedforwardLayerNorm2.wrappedValue = RMSNorm(
                dimensions: config.hiddenSize,
                eps: config.rmsNormEps
            )
        }
        self._perLayerInputGate.wrappedValue = Linear(
            config.hiddenSize,
            max(config.hiddenSizePerLayerInput, 1),
            bias: false
        )
        self._perLayerProjection.wrappedValue = Linear(
            max(config.hiddenSizePerLayerInput, 1),
            config.hiddenSize,
            bias: false
        )
        self._postPerLayerInputNorm.wrappedValue = RMSNorm(
            dimensions: config.hiddenSize,
            eps: config.rmsNormEps
        )
        self._layerScalar.wrappedValue = MLXArray(1.0)

        super.init()
    }

    func callAsFunction(
        _ x: MLXArray,
        mask: MLXArray?,
        perLayerInput: MLXArray?,
        sharedKVStates: inout [Int: (keys: MLXArray, values: MLXArray)]
    ) -> MLXArray {
        var hiddenStates = x

        let attentionOutput = selfAttention(
            inputLayerNorm(hiddenStates),
            mask: mask,
            sharedKVStates: &sharedKVStates
        )
        hiddenStates = hiddenStates + postAttentionLayerNorm(attentionOutput)

        let feedForwardResidual = hiddenStates
        let feedForwardInput = preFeedforwardLayerNorm(feedForwardResidual)
        let feedForwardOutput = applyFeedForward(
            feedForwardInput,
            residual: feedForwardResidual
        )
        hiddenStates = feedForwardResidual + postFeedforwardLayerNorm(feedForwardOutput)

        if usesPerLayerInput, let perLayerInput {
            let gated = Gemma4TextMath.activation(activationName, perLayerInputGate(hiddenStates))
            let projected = perLayerProjection(gated * perLayerInput)
            hiddenStates = hiddenStates + postPerLayerInputNorm(projected)
        }

        return hiddenStates * layerScalar.asType(hiddenStates.dtype)
    }

    private func applyFeedForward(_ hiddenStates: MLXArray, residual: MLXArray) -> MLXArray {
        switch feedForwardPath {
        case .dense:
            return mlp(hiddenStates)
        case .mixtureOfExperts:
            guard
                let router,
                let experts,
                let postFeedforwardLayerNorm1,
                let postFeedforwardLayerNorm2,
                let preFeedforwardLayerNorm2
            else {
                return mlp(hiddenStates)
            }

            let denseOutput = postFeedforwardLayerNorm1(mlp(hiddenStates))
            let flattenedResidual = residual.reshaped(-1, residual.dim(-1))
            let (_, topKWeights, topKIndex) = router(flattenedResidual)
            let moeOutput = experts(
                preFeedforwardLayerNorm2(flattenedResidual),
                topKIndex: topKIndex,
                topKWeights: topKWeights
            )
            .reshaped(residual.dim(0), residual.dim(1), residual.dim(2))

            return denseOutput + postFeedforwardLayerNorm2(moeOutput)
        }
    }
}

public final class Gemma4TextLanguageModel: Module {
    public let config: Gemma4TextConfiguration

    @ModuleInfo(key: "embed_tokens") var embedTokens: Embedding
    @ModuleInfo(key: "embed_tokens_per_layer") var embedTokensPerLayer: Embedding
    @ModuleInfo var layers: [Gemma4TextDecoderLayer]
    @ModuleInfo var norm: RMSNorm
    @ModuleInfo(key: "per_layer_model_projection") var perLayerModelProjection: Linear
    @ModuleInfo(key: "per_layer_projection_norm") var perLayerProjectionNorm: RMSNorm

    public var vocabularySize: Int { config.vocabSize }

    private let embeddingScale: Float
    private let perLayerEmbeddingScale: Float
    private let perLayerProjectionScale: Float
    private let perLayerInputScale: Float

    public init(_ config: Gemma4TextConfiguration) {
        self.config = config
        self.embeddingScale = Gemma4TextMath.embeddingScale(dimensions: config.hiddenSize)
        self.perLayerEmbeddingScale = Gemma4TextMath.embeddingScale(
            dimensions: max(config.hiddenSizePerLayerInput, 1))
        self.perLayerProjectionScale = Gemma4TextMath.projectionScale(dimensions: config.hiddenSize)
        self.perLayerInputScale = Gemma4TextMath.layerInputScale()

        self._embedTokens.wrappedValue = Embedding(
            embeddingCount: config.vocabSize,
            dimensions: config.hiddenSize
        )
        self._embedTokensPerLayer.wrappedValue = Embedding(
            embeddingCount: config.vocabSizePerLayerInput,
            dimensions: max(config.numHiddenLayers * config.hiddenSizePerLayerInput, 1)
        )
        self._layers.wrappedValue = (0 ..< config.numHiddenLayers).map { layerIndex in
            Gemma4TextDecoderLayer(config, layerIndex: layerIndex)
        }
        self._norm.wrappedValue = RMSNorm(dimensions: config.hiddenSize, eps: config.rmsNormEps)
        self._perLayerModelProjection.wrappedValue = Linear(
            config.hiddenSize,
            max(config.numHiddenLayers * config.hiddenSizePerLayerInput, 1),
            bias: false
        )
        self._perLayerProjectionNorm.wrappedValue = RMSNorm(
            dimensions: max(config.hiddenSizePerLayerInput, 1),
            eps: config.rmsNormEps
        )

        super.init()
    }

    public func callAsFunction(_ inputs: MLXArray) -> MLXArray {
        let tokenIDs = inputs.ndim == 1 ? inputs.reshaped(1, -1) : inputs
        let sequenceLength = tokenIDs.dim(1)

        var hiddenStates = embedTokens(tokenIDs) * embeddingScale
        let perLayerInputs = makePerLayerInputs(tokenIDs, inputEmbeddings: hiddenStates)
        let fullMask = Gemma4TextMath.makeAdditiveCausalMask(
            sequenceLength: sequenceLength,
            windowSize: nil,
            dtype: hiddenStates.dtype
        )
        let slidingMask = Gemma4TextMath.makeAdditiveCausalMask(
            sequenceLength: sequenceLength,
            windowSize: config.slidingWindow,
            dtype: hiddenStates.dtype
        )
        var sharedKVStates = [Int: (keys: MLXArray, values: MLXArray)]()

        for (layerIndex, layer) in layers.enumerated() {
            let mask = config.layerType(for: layerIndex) == "sliding_attention" ? slidingMask : fullMask
            let layerInput: MLXArray? =
                if let perLayerInputs {
                    perLayerInputs[0..., 0..., layerIndex, 0...]
                } else {
                    nil
                }
            hiddenStates = layer(
                hiddenStates,
                mask: mask,
                perLayerInput: layerInput,
                sharedKVStates: &sharedKVStates
            )
        }

        var logits = embedTokens.asLinear(norm(hiddenStates))
        if let softCap = config.finalLogitSoftcapping, softCap > 0 {
            logits = tanh(logits / softCap) * softCap
        }
        return logits
    }

    private func makePerLayerInputs(_ inputIDs: MLXArray, inputEmbeddings: MLXArray) -> MLXArray? {
        guard config.hiddenSizePerLayerInput > 0 else {
            return nil
        }

        let batchSize = inputIDs.dim(0)
        let sequenceLength = inputIDs.dim(1)

        let embeddedPerLayerInputs = embedTokensPerLayer(inputIDs)
            .reshaped(batchSize, sequenceLength, config.numHiddenLayers, config.hiddenSizePerLayerInput)
            * perLayerEmbeddingScale

        let projectedInputs = perLayerProjectionNorm(
            (perLayerModelProjection(inputEmbeddings) * perLayerProjectionScale)
                .reshaped(batchSize, sequenceLength, config.numHiddenLayers, config.hiddenSizePerLayerInput)
        )

        return (embeddedPerLayerInputs + projectedInputs) * perLayerInputScale
    }
}
