import XCTest
@testable import WatsonChat

final class Gemma4ConfigurationTests: XCTestCase {
    func test_decodesGemma4RootConfigurationTextConfigFields() throws {
        let json = """
        {
          "model_type": "gemma4",
          "text_config": {
            "attention_bias": false,
            "attention_dropout": 0.0,
            "attention_k_eq_v": true,
            "final_logit_softcapping": 30.0,
            "global_head_dim": 512,
            "head_dim": 256,
            "hidden_activation": "gelu_pytorch_tanh",
            "hidden_size": 5376,
            "intermediate_size": 21504,
            "layer_types": [
              "sliding_attention",
              "sliding_attention",
              "full_attention",
              "sliding_attention"
            ],
            "max_position_embeddings": 262144,
            "model_type": "gemma4_text",
            "num_attention_heads": 32,
            "num_hidden_layers": 4,
            "num_key_value_heads": 16,
            "rms_norm_eps": 1e-06,
            "sliding_window": 1024,
            "vocab_size": 262144
          }
        }
        """

        let rootConfiguration = try JSONDecoder().decode(
            Gemma4RootConfiguration.self,
            from: Data(json.utf8)
        )
        let textConfiguration = rootConfiguration.textConfig

        XCTAssertEqual(textConfiguration.modelType, "gemma4_text")
        XCTAssertEqual(textConfiguration.hiddenSize, 5376)
        XCTAssertEqual(textConfiguration.numHiddenLayers, 4)
        XCTAssertEqual(textConfiguration.numAttentionHeads, 32)
        XCTAssertEqual(textConfiguration.numKeyValueHeads, 16)
        XCTAssertEqual(textConfiguration.intermediateSize, 21504)
        XCTAssertEqual(textConfiguration.headDim, 256)
        XCTAssertEqual(textConfiguration.globalHeadDim, 512)
        XCTAssertEqual(textConfiguration.maxPositionEmbeddings, 262144)
        XCTAssertEqual(textConfiguration.slidingWindow, 1024)
        XCTAssertEqual(
            textConfiguration.layerTypes,
            [
                "sliding_attention",
                "sliding_attention",
                "full_attention",
                "sliding_attention"
            ]
        )
        XCTAssertEqual(textConfiguration.hiddenActivation, "gelu_pytorch_tanh")
        XCTAssertEqual(textConfiguration.attentionKEqV, true)
        XCTAssertNotNil(textConfiguration.finalLogitSoftcapping)
        XCTAssertEqual(textConfiguration.finalLogitSoftcapping ?? 0, 30.0, accuracy: 0.0001)
    }

    func test_languageModelKeyShapes_filtersOutNonLanguageModelEntries() throws {
        let json = """
        {
          "__metadata__": {
            "format": "pt"
          },
          "model.language_model.embed_tokens.weight": {
            "dtype": "F16",
            "shape": [5376, 262144],
            "data_offsets": [0, 1]
          },
          "model.language_model.layers.0.self_attn.q_proj.weight": {
            "dtype": "F16",
            "shape": [5376, 5376],
            "data_offsets": [1, 2]
          },
          "model.language_model.layers.0.self_attn.k_proj.weight": {
            "dtype": "F16",
            "shape": [5376, 1024],
            "data_offsets": [2, 3]
          },
          "vision_model.encoder.weight": {
            "dtype": "F16",
            "shape": [16, 16],
            "data_offsets": [3, 4]
          }
        }
        """

        let keyShapes = try SafetensorsMetadataParser.languageModelKeyShapes(
            from: Data(json.utf8)
        )

        XCTAssertEqual(
            keyShapes.keys.sorted(),
            [
                "model.language_model.embed_tokens.weight",
                "model.language_model.layers.0.self_attn.k_proj.weight",
                "model.language_model.layers.0.self_attn.q_proj.weight"
            ]
        )
        XCTAssertEqual(keyShapes["model.language_model.embed_tokens.weight"], [5376, 262144])
        XCTAssertEqual(
            keyShapes["model.language_model.layers.0.self_attn.q_proj.weight"],
            [5376, 5376]
        )
        XCTAssertEqual(
            keyShapes["model.language_model.layers.0.self_attn.k_proj.weight"],
            [5376, 1024]
        )
        XCTAssertNil(keyShapes["vision_model.encoder.weight"])
    }
}
