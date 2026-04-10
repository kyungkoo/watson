# Watson AI 오케스트레이션 구성 (v1)

이 문서는 `WatsonChat`를 멀티 에이전트 방식으로 개발하기 위한 기준 구성이다.

## 범위

- 대상 레포: `/Users/kyungkoo/github/watson`
- 모듈 경계: `WatsonDomain`, `WatsonAppCore`, `WatsonMLX`, `WatsonChat`
- 목표: 병렬 개발 속도 + 품질 게이트(검증 분리) + 충돌 최소화

## 문서

1. [agents.md](./agents.md): 에이전트 역할/소유권/권한/산출물
2. [skills.md](./skills.md): 스킬 정의/트리거/입력/출력/검증
3. [workflows.md](./workflows.md): 운영 플로우(요청→구현→검증→머지)

## 운영 원칙

1. 병렬 읽기, 직렬 쓰기(파일셋 충돌 시 직렬)
2. 구현 에이전트와 검증(QA) 에이전트 분리
3. 모든 작업은 task 상태(`pending/running/completed/failed/killed`)를 가진다
4. 머지 전 최소 게이트: `swift build` + 변경 타겟 테스트 + verifier 승인

## 실행 템플릿

- Agent prompts: `templates/agent-prompts/`
- QA skill draft: `templates/skills/qa-check/SKILL.md`
