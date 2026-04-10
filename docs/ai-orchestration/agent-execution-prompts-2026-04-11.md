# Watson Agent Execution Prompts (2026-04-11)

아래 프롬프트는 `docs/ai-orchestration/dry-run-2026-04-11-main.md` 기준으로 실제 작업 실행용이다.

## 공통 규칙 (모든 에이전트)

```text
당신은 watson 저장소의 작업 에이전트다.
- 작업 루트: /Users/kyungkoo/github/watson
- 본인 소유 파일만 수정한다.
- 다른 에이전트 소유 파일은 수정하지 않는다.
- 테스트/검증 결과는 반드시 실행 근거(명령+결과 요약)와 함께 보고한다.
- 완료 시 아래 형식으로만 상태를 보고한다.

<task-notification>
<task-id>{TID}</task-id>
<status>completed|failed|killed</status>
<summary>{one-line outcome}</summary>
</task-notification>
```

## T1 - Package/Target Boundary (`coordinator` + module agents)

```text
Task: T1 패키지/타겟 경계 검증
Scope:
- Package.swift
- Sources/WatsonDomain/**
- Sources/WatsonAppCore/**
- Sources/WatsonMLX/**

해야 할 일:
1) 의존성 방향이 Domain -> AppCore -> MLX -> WatsonChat를 위반하지 않는지 확인
2) 순환 의존 가능성 점검
3) 삭제된 WatsonChat 내부 Models/Services 참조 잔존 여부 점검
4) 문제 발견 시 최소 수정안 제시(필요 시만 코드 수정)

완료 조건:
- 경계 위반/순환/잔존 참조 여부가 명확히 보고됨
```

## T2 - AppCore State Safety (`appcore-agent`)

```text
Task: T2 AppCore 상태 전이 안전성 확인
Ownership:
- Sources/WatsonAppCore/**
- Tests/WatsonAppCoreTests/**

해야 할 일:
1) ChatViewModel 상태 전이(입력/응답/중단/오류) 코드 검토
2) 타겟 분리 후 테스트 import/의존성 정합성 확인
3) 필요 시 AppCore 및 해당 테스트만 수정
4) swift test --filter WatsonAppCoreTests 실행 결과 첨부

완료 조건:
- WatsonAppCoreTests 통과
- 상태 전이 회귀 리스크 없음 또는 잔여 리스크 명시
```

## T3 - Domain Contracts (`domain-agent`)

```text
Task: T3 Domain 계약 회귀 확인
Ownership:
- Sources/WatsonDomain/**
- Tests/WatsonDomainTests/**

해야 할 일:
1) PromptFormatter / InferenceProvider / RoutingPolicy 계약 점검
2) 공개 타입(ChatMessage, ModelConfiguration, GenerationOptions) 호환성 점검
3) 필요 시 Domain 및 해당 테스트만 수정
4) swift test --filter WatsonDomainTests 실행 결과 첨부

완료 조건:
- WatsonDomainTests 통과
- 계약 회귀 없음 또는 호환성 리스크 명시
```

## T4 - MLX Path Regression (`mlx-agent`)

```text
Task: T4 MLX 경로 회귀 확인
Ownership:
- Sources/WatsonMLX/**
- Tests/WatsonMLXTests/**

해야 할 일:
1) loader/generator/provider import 및 호출 경로 점검
2) Gemma config/smoke 테스트 상태 점검
3) 필요 시 MLX 및 해당 테스트만 수정
4) swift test --filter WatsonMLXTests 실행 결과 첨부

완료 조건:
- WatsonMLXTests 통과
- skip된 smoke가 있으면 조건/영향 범위 보고
```

## T5 - UI Integration (`ui-agent`)

```text
Task: T5 UI 통합 점검
Ownership:
- Sources/WatsonChat/WatsonChatApp.swift
- Sources/WatsonChat/Views/ContentView.swift
- Sources/WatsonChat/Views/MessageBubbleView.swift

해야 할 일:
1) AppCore/Domain/MLX import 및 초기화 경로 검토
2) 빌드 오류 유발 코드 정리
3) 필요 시 UI 파일만 수정
4) swift build 실행 근거 첨부

완료 조건:
- UI 통합 빌드 오류 없음
- 화면 경로 주요 리스크 메모
```

## T6 - Docs/Rules Sync (`release-agent`)

```text
Task: T6 문서/운영 규칙 동기화
Ownership:
- docs/ai-orchestration/**
- AGENTS.md (필요 시)

해야 할 일:
1) 실제 모듈 구조와 문서 불일치 항목 점검
2) 에이전트 소유권/검증 게이트 문구 최신화
3) 문서만 수정(코드 수정 금지)

완료 조건:
- 문서와 실제 구조의 차이점 0건 또는 차이 목록/후속 액션 제시
```

## T7 - Independent Verifier (`verifier-qa-agent`)

```text
Task: T7 독립 검증 게이트
Mode: read-only (코드 수정 금지)

실행:
1) swift build
2) swift test --filter WatsonDomainTests
3) swift test --filter WatsonAppCoreTests
4) swift test --filter WatsonMLXTests

최종 보고 포맷:
Verdict: PASS|PARTIAL|FAIL
Evidence:
1) command: ...
   result: ...
Risks:
- ...
Required follow-ups:
- ...
```

## 코디네이터 운영 순서 (권장)

```text
1) T1 짧은 경계 점검 시작
2) T2/T3/T4/T6 병렬 실행
3) 병렬 태스크 수렴 후 T5 실행
4) 마지막에 T7 verifier 단독 실행
5) Verdict와 잔여 리스크를 PR 본문에 기록
```

