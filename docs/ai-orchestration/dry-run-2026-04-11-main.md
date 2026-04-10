# Watson Orchestration Dry-Run Checklist (2026-04-11, branch: main)

## 0) Snapshot

- Branch: `main`
- Working tree: dirty (구조 개편 진행 중)
- 핵심 변화 패턴:
1. 기존 `Sources/WatsonChat` 내부 모델/서비스/뷰모델 파일 삭제
2. `Sources/WatsonDomain`, `Sources/WatsonAppCore`, `Sources/WatsonMLX` 신규 모듈 도입
3. 테스트가 `Tests/WatsonChatTests`에서 모듈별 테스트 타겟으로 재배치
4. `Package.swift`, `Package.resolved` 수정

## 1) Task Board (Dry-run)

### T1. 패키지/타겟 경계 검증

- Owner: `coordinator` + `domain-agent` + `appcore-agent` + `mlx-agent`
- Scope:
1. `Package.swift`
2. `Sources/WatsonDomain/**`
3. `Sources/WatsonAppCore/**`
4. `Sources/WatsonMLX/**`
- Done definition:
1. 타겟 의존성 방향이 `Domain -> AppCore -> MLX -> WatsonChat`에 맞게 유지
2. 순환 의존 없음
3. 삭제된 `WatsonChat` 내부 모델/서비스 참조가 남아있지 않음

### T2. AppCore 상태 전이 안전성 확인

- Owner: `appcore-agent`
- Scope:
1. `Sources/WatsonAppCore/ViewModels/ChatViewModel.swift`
2. `Tests/WatsonAppCoreTests/ChatViewModelTests.swift`
- Done definition:
1. 입력/응답/중단/오류 상태 전이 테스트가 현재 구조와 일치
2. 타겟명 변경에 따른 테스트 import/의존성 문제 없음

### T3. Domain 계약 회귀 확인

- Owner: `domain-agent`
- Scope:
1. `Sources/WatsonDomain/Models/**`
2. `Sources/WatsonDomain/Services/**`
3. `Tests/WatsonDomainTests/**`
- Done definition:
1. `PromptFormatter`, `InferenceProvider`, `RoutingPolicy` 계약 테스트 통과
2. 공개 타입(`ChatMessage`, `ModelConfiguration`, `GenerationOptions`) 호환성 이슈 없음

### T4. MLX 경로 회귀 확인

- Owner: `mlx-agent`
- Scope:
1. `Sources/WatsonMLX/Models/**`
2. `Sources/WatsonMLX/Services/**`
3. `Tests/WatsonMLXTests/**`
- Done definition:
1. Gemma config/smoke 테스트 통과
2. model loader/generator/native provider 경로에서 누락 import 없음

### T5. UI 통합 점검

- Owner: `ui-agent`
- Scope:
1. `Sources/WatsonChat/WatsonChatApp.swift`
2. `Sources/WatsonChat/Views/ContentView.swift`
3. `Sources/WatsonChat/Views/MessageBubbleView.swift`
- Done definition:
1. 새 모듈(AppCore/Domain/MLX)과의 import/초기화 경로 일치
2. 빌드 레벨 오류 없음
3. 주요 화면 렌더 경로 깨짐 없음(최소 수동 점검 메모)

### T6. 문서/운영 규칙 동기화

- Owner: `release-agent` (또는 coordinator)
- Scope:
1. `docs/ai-orchestration/**`
2. `AGENTS.md` (필요 시)
- Done definition:
1. 실제 타겟 구조와 문서가 불일치하지 않음
2. 에이전트 소유권/검증 규칙 최신 상태 반영

### T7. 독립 검증 게이트

- Owner: `verifier-qa-agent`
- Scope: 쓰기 금지, 검증만 수행
- Done definition:
1. 아래 검증 명령 실행 결과를 근거와 함께 보고
2. 최종 판정 발급: `PASS | PARTIAL | FAIL`

## 2) 병렬/직렬 실행 계획

## 병렬 가능

1. T2(AppCore), T3(Domain), T4(MLX), T6(Docs)

## 직렬 권장

1. T1은 선행 또는 T2~T4와 매우 짧은 인터락(의존성 확인) 후 진행
2. T5(UI)는 T2/T3/T4 결과 반영 후 진행
3. T7(Verifier)는 마지막에 단독 실행

## 3) Verifier Command Plan

1. Build gate
- `swift build`

2. Targeted tests
- `swift test --filter WatsonDomainTests`
- `swift test --filter WatsonAppCoreTests`
- `swift test --filter WatsonMLXTests`

3. Optional focused checks
- `swift test --filter PromptFormatterTests`
- `swift test --filter ChatViewModelTests`
- `swift test --filter Gemma4SmokeTests`

## 4) Result Reporting Template

```text
<task-notification>
<task-id>{TID}</task-id>
<status>completed|failed|killed</status>
<summary>{one-line outcome}</summary>
</task-notification>
```

Verifier 최종 보고 포맷:

```text
Verdict: PASS|PARTIAL|FAIL
Evidence:
1) command: ...
   result: ...
2) command: ...
   result: ...
Risks:
- ...
Required follow-ups:
- ...
```

## 5) Exit Criteria

1. T1~T6 완료
2. Verifier verdict가 `PASS`
3. 남은 리스크가 있으면 PR 본문에 명시

