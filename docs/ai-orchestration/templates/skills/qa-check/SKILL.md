---
name: qa-check
description: Use when code changes are ready for verification and you need an independent PASS/PARTIAL/FAIL verdict with reproducible evidence.
---

# QA Check

## Overview

`qa-check`는 구현과 분리된 독립 검증 스킬이다. 목표는 “작동한다”가 아니라 “재현 가능한 근거로 증명한다”이다.

## When to Use

- 구현 에이전트가 완료를 주장할 때
- 여러 모듈이 함께 변경되어 회귀 위험이 있을 때
- 머지 직전 최종 품질 게이트가 필요할 때

## Inputs

1. Changed files
2. Claimed behavior changes
3. Claimed test/build results

## Procedure

1. 영향 모듈 식별
- `Sources/WatsonDomain/**` -> `WatsonDomainTests`
- `Sources/WatsonAppCore/**` -> `WatsonAppCoreTests`
- `Sources/WatsonMLX/**` -> `WatsonMLXTests`
- `Sources/WatsonChat/**` -> build + 수동 확인 항목

2. 독립 검증 실행
- `swift build`
- 영향 타겟별 `swift test --filter ...`

3. 주장 검증
- 구현자가 보고한 변경 의도와 실제 코드/테스트 결과 일치 여부 확인

4. 판정 발급
- `PASS`: 모든 필수 게이트 통과, 치명 리스크 없음
- `PARTIAL`: 기능은 대체로 맞지만 중요한 리스크/미검증 항목 존재
- `FAIL`: 빌드/테스트 실패 또는 요구사항 불충족

## Output Format

- Verdict: `PASS` | `PARTIAL` | `FAIL`
- Evidence:
1. command
2. result summary
3. failures or risks
- Required follow-ups (if any)

## Common Mistakes

1. 구현자의 테스트 결과를 재실행 없이 신뢰
2. 변경 파일과 무관한 테스트만 실행
3. `PARTIAL` 사유를 모호하게 작성

