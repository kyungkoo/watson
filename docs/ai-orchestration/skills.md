# Skill 구성안

## S1. `watson-task-bootstrap`

- 목적: 요청을 task 단위로 분해하고 소유 에이전트 배정
- 입력: 사용자 요청, 변경 예상 파일
- 출력: task 리스트(소유자/의존성/완료 조건)

## S2. `watson-ownership-lock`

- 목적: 파일 소유권 충돌 방지
- 규칙:
1. 쓰기 전 파일 소유자 확인
2. 충돌 시 coordinator에 직렬 전환 요청

## S3. `watson-swift-test-mapper`

- 목적: 변경 파일→실행 테스트 자동 매핑
- 예시 매핑:
1. `Sources/WatsonDomain/**` -> `WatsonDomainTests`
2. `Sources/WatsonAppCore/**` -> `WatsonAppCoreTests`
3. `Sources/WatsonMLX/**` -> `WatsonMLXTests`

## S4. `watson-chat-state-check`

- 목적: `ChatViewModel` 상태 전이 회귀 방지
- 체크:
1. 입력/응답/중단/에러/재시도 상태 전이
2. UI 바인딩 깨짐 여부

## S5. `watson-mlx-safety-check`

- 목적: 모델 로딩/추론 경로 안정성 검증
- 체크:
1. Gemma 설정 로딩
2. tokenizer/hf-api 연동
3. smoke 추론 경로

## S6. `watson-verification-gate`

- 목적: merge 직전 표준 검증 강제
- 최소 게이트:
1. `swift build`
2. 영향 타겟 `swift test --filter ...`
3. verifier 판정 수신

## S7. `watson-failure-triage`

- 목적: 실패를 재현 가능한 이슈로 정규화
- 출력:
1. 재현 커맨드
2. 원인 후보 1~3개
3. 우선 수정안

## S8. `watson-pr-assembly`

- 목적: PR 본문 표준화
- 섹션:
1. 변경 요약
2. 왜 필요한가
3. 검증 결과
4. 잔여 리스크

## S9. `watson-doc-sync`

- 목적: 변경된 코드와 문서 동기화
- 대상:
1. `docs/` 설계 문서
2. 사용자 영향 있는 동작 변경

## S10. `watson-safe-git`

- 목적: 파괴적 git 사용 방지
- 규칙:
1. destructive 명령 차단
2. 필요한 경우 coordinator 승인 요구

## 실행 초안 파일

- `templates/skills/qa-check/SKILL.md`
