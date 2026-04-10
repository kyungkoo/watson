# Gemma4 26B-A4B Support Design

## Goal
- Support both `Gemma 4 E4B-it` and `Gemma 4 26B-A4B-it` in the Watson local chat app.
- Keep `E4B-it` stable while adding a MoE-capable path for `26B-A4B-it`.
- Reduce future model onboarding cost via clearer provider/engine boundaries.

## Current Gaps
- `MLXEngine` currently owns too many concerns: download, config parse, model selection, weight filtering/mapping, generation loop.
- Generation recomputes full prompt for every token (`O(n^2)` decode path), which becomes a bottleneck for longer conversations.
- `Gemma4TextModel` is dense-centric; MoE router/expert path is not implemented.
- Model metadata/capabilities are implicit and spread across branches.

## Scope
### In scope
- Text-only inference for Gemma4 (`E2B/E4B/26B-A4B`) via MLX native provider.
- MoE-aware model path for `26B-A4B-it`.
- Incremental decode foundation in engine interface (cache-ready API boundary).
- Capability-aware model configuration.

### Out of scope
- Vision/audio input pipeline.
- Sampling strategy expansion beyond current greedy baseline.
- Fine-tuning/training workflow.

## Architecture
### 1) Provider/Engine decomposition
- Keep `InferenceProvider` contract unchanged at UI boundary.
- Split internals of `MLXEngine` into focused units:
  - `MLXModelLoader`: Hub download + config parse + stop token resolution.
  - `MLXWeightMapper`: strategy selection + key normalization/validation.
  - `MLXGenerator`: token loop (prompt encoding, token append, decode delta, cancellation).
- `MLXEngine` becomes an orchestrator only.

### 2) Capability-first model configuration
- Extend `ModelConfiguration` with explicit capabilities:
  - `architecture`: `dense` or `moe`.
  - `quantizationHint`: `auto`, `q4`, `q5`, `bf16` (advisory).
  - `recommendedContextWindow`: practical runtime cap per model.
- Add `Gemma 4 26B A4B` entry, defaulting to instruction-tuned model ID.

### 3) Gemma4 model path split (dense vs MoE)
- Introduce decoder feed-forward abstraction:
  - `Gemma4FeedForwardBlock` protocol-like boundary.
  - `Gemma4TextMLP` for dense layers.
  - `Gemma4MoEBlock` for MoE layers (`router`, `top-k`, expert projections, weighted combine).
- Decoder layer uses one block selected by `text_config.enable_moe_block`.

### 4) Incremental decode boundary
- Replace direct full-sequence iteration with generator unit that can evolve to KV-cached decode.
- First phase keeps logits behavior equivalent but isolates token-step API so KV cache can be added without touching provider/view model again.

## Parallel Workstreams
### Track A: Engine decomposition + generation boundary
- Owner files:
  - `Sources/WatsonChat/Services/MLXEngine.swift`
  - `Sources/WatsonChat/Services/MLXModelLoader.swift` (new)
  - `Sources/WatsonChat/Services/MLXWeightMapper.swift` (new)
  - `Sources/WatsonChat/Services/MLXGenerator.swift` (new)
- Deliverables:
  - Engine orchestrator refactor.
  - Existing behavior preserved for E2B/E4B.

### Track B: Model capability + selectable 26B configuration
- Owner files:
  - `Sources/WatsonChat/Models/ModelConfiguration.swift`
  - `Sources/WatsonChat/Views/ContentView.swift` (if selector display needs update)
  - `Sources/WatsonChat/ViewModels/ChatViewModel.swift` (status/guard updates)
- Deliverables:
  - Capability fields + 26B model entry.
  - Safe defaults and clearer status strings.

### Track C: MoE model implementation
- Owner files:
  - `Sources/WatsonChat/Models/Gemma4TextModel.swift`
- Deliverables:
  - MoE block types and decoder integration.
  - Router/expert key path readiness.

### Track D: Tests and regression protection
- Owner files:
  - `Tests/WatsonChatTests/ProviderContractTests.swift`
  - `Tests/WatsonChatTests/Gemma4ConfigurationTests.swift`
  - `Tests/WatsonChatTests/Gemma4SmokeTests.swift`
  - Additional test files as needed.
- Deliverables:
  - Capability decode/selection tests.
  - MoE config parse and key mapping assertions.
  - Smoke test gate remains opt-in via environment variable.

## Integration Order
1. Merge Track B + Track C first (clear model semantics and forward path).
2. Merge Track A next (engine internals refactor with same external behavior).
3. Finalize Track D after integration to lock regressions.

## Validation Plan
- `swift build`
- `swift test`
- Optional local smoke:
  - `ENABLE_GEMMA4_SMOKE_TEST=1 swift test --filter Gemma4SmokeTests`
- Manual UI check:
  - model switching among `E2B`, `E4B`, `26B-A4B`
  - cancel button during long generation

## Risks and Mitigations
- Risk: MoE implementation divergence from upstream tensor naming.
  - Mitigation: strict required-key validation with clear missing-key errors.
- Risk: performance regression after engine split.
  - Mitigation: preserve token-loop output semantics and run smoke/regression tests.
- Risk: memory pressure on medium-memory devices.
  - Mitigation: configuration-level `recommendedContextWindow` and status guidance.

## Done Criteria
- Build/tests pass.
- `E4B-it` behavior unchanged (chat quality and cancellation intact).
- `26B-A4B-it` path is loadable at code level with explicit MoE support and clear runtime errors when unsupported assets/capabilities are missing.
