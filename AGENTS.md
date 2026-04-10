# Repository Guidelines

## Project Structure & Module Organization
- `Package.swift`: SwiftPM manifest; defines the macOS executable target `WatsonChat`.
- `Sources/WatsonChat`: production code, split by responsibility:
- `Models/` for model/config types (`GemmaModel`, `ModelConfiguration`, `ChatMessage`).
- `Services/` for inference and prompt/runtime integration (`MLXEngine`, `PromptFormatter`).
- `ViewModels/` for UI state and orchestration (`ChatViewModel`).
- `Views/` for SwiftUI screens/components (`ContentView`, `MessageBubbleView`).
- `Package.resolved` pins dependency versions. `.build/` is generated output and should not be edited.

## Build, Test, and Development Commands
- `swift package resolve`: fetch or refresh package dependencies.
- `swift build`: compile the project in debug mode.
- `swift run WatsonChat`: build and launch the macOS app locally.
- `swift test`: run tests. Current baseline has no test target yet, so this command fails until tests are added.
- `open Package.swift`: open the package in Xcode for UI debugging and profiling.

## Coding Style & Naming Conventions
- Use 4-space indentation and idiomatic Swift style.
- Type names use `UpperCamelCase`; properties/functions use `lowerCamelCase`.
- Keep boundaries clear: UI in `Views`, state logic in `ViewModels`, model/runtime logic in `Models` and `Services`.
- Default to the narrowest access level (`private`/`fileprivate`) and widen only when required.

## Testing Guidelines
- Add tests under `Tests/WatsonChatTests` with `XCTest`.
- Use file names ending in `Tests.swift` and method names like `test_<Behavior>_<ExpectedResult>()`.
- Prioritize tests for prompt formatting, model loading/error paths, and `ChatViewModel` state transitions.
- Run `swift test` before submitting a PR.

## Commit & Pull Request Guidelines
- Existing history uses short imperative subjects (for example: `init`, `add gitignore`); keep commit titles concise and action-oriented.
- Keep each commit focused on a single concern.
- PRs should include: a clear summary, why the change is needed, verification steps/results (`swift build`, `swift test`), and screenshots for SwiftUI-visible changes.
- Link related issues/tasks and note any follow-up work explicitly.
