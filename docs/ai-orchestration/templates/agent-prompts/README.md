# Agent Prompt Templates

이 디렉터리는 `watson` 오케스트레이션에서 재사용할 에이전트 프롬프트 템플릿 모음이다.

## 파일

1. `coordinator.md`
2. `domain-agent.md`
3. `appcore-agent.md`
4. `mlx-agent.md`
5. `ui-agent.md`
6. `verifier-qa-agent.md`

## 사용 방법

1. Coordinator가 사용자 요청을 task로 분해한다.
2. 각 task의 소유 모듈에 맞는 프롬프트 템플릿을 사용한다.
3. Verifier는 항상 독립적으로 같은 변경을 재검증한다.
4. 템플릿의 `{...}` 변수만 채워 실행한다.

