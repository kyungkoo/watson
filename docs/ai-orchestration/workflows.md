# 운영 워크플로 (v1)

## 1. 기능 개발 플로우

1. Coordinator가 요청 수신
2. `watson-task-bootstrap`으로 task 분해
3. 읽기 작업 병렬 탐색
4. 구현 task를 소유 에이전트에 배정
5. 충돌 시 `watson-ownership-lock`으로 직렬 전환
6. 구현 완료 후 verifier 실행
7. `watson-verification-gate` 통과 시 통합
8. `watson-pr-assembly`로 PR 정리

## 2. 버그 수정 플로우

1. `watson-failure-triage`로 재현/원인 정리
2. 최소 수정 범위 선정
3. 소유 에이전트가 패치
4. verifier가 독립 재현 확인

## 3. 태스크 상태 전이 규약

- 상태: `pending` -> `running` -> `completed | failed | killed`
- 알림 포맷(권장): `<task-notification>`
- 필수 필드:
1. `task_id`
2. `status`
3. `summary`
4. `owner_agent`

## 4. 품질 게이트

1. 빌드 실패 시 즉시 `failed`
2. 테스트 실패 시 원인과 재현 커맨드 첨부
3. verifier가 `PASS`를 주지 않으면 머지 금지

## 5. 도입 순서 (2주 권장)

1. 1주차:
- coordinator + domain/appcore/mlx/ui/verifier 역할 고정
- S1/S2/S3/S6 우선 도입
2. 2주차:
- S4/S5/S7/S8/S9/S10 확장
- PR 템플릿/체크리스트 연동

