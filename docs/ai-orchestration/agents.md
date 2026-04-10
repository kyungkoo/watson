# Agent 구성안

## 1) Coordinator Agent (필수)

- 역할: 요청 분해, 작업 배정, 병렬/직렬 스케줄링, 결과 합성
- 쓰기 권한: 없음(원칙), 필요 시 최종 통합 커밋만 허용
- 핵심 책임:
1. task 생성/상태 전이 관리
2. 파일 소유권 충돌 검사
3. verifier 실행 요청 및 승인 수집

## 2) Domain Agent

- 소유 경로:
1. `Sources/WatsonDomain`
2. `Tests/WatsonDomainTests`
- 책임:
1. 모델/정책/프롬프트 포맷 계약 유지
2. Domain 계약 테스트 유지
- 완료 기준:
1. Domain 테스트 통과
2. 공개 타입 변경 시 영향 모듈 목록 제출

## 3) AppCore Agent

- 소유 경로:
1. `Sources/WatsonAppCore`
2. `Tests/WatsonAppCoreTests`
- 책임:
1. `ChatViewModel` 상태 전이/오케스트레이션 로직
2. 도메인/MLX 사이 어댑터 정합성
- 완료 기준:
1. 상태 전이 테스트 통과
2. 회귀 시나리오(취소/에러/재시도) 확인

## 4) MLX Agent

- 소유 경로:
1. `Sources/WatsonMLX`
2. `Tests/WatsonMLXTests`
- 책임:
1. 모델 로딩/추론/토크나이저/웨이트 매핑
2. Gemma 설정/스모크 경로 안정성
- 완료 기준:
1. MLX smoke/config 테스트 통과
2. 메모리/성능 리스크 코멘트 제출

## 5) UI Agent

- 소유 경로:
1. `Sources/WatsonChat`
- 책임:
1. SwiftUI 화면/상호작용
2. ViewModel 바인딩 정합성
- 완료 기준:
1. 빌드 통과
2. 사용자 플로우 스냅샷 또는 수동 검증 메모 제출

## 6) Verifier (QA) Agent (필수)

- 소유 경로: 쓰기 금지(원칙)
- 책임:
1. 변경 파일 기준 테스트 플랜 생성
2. 독립 검증 실행
3. 최종 판정(`PASS`/`PARTIAL`/`FAIL`) 발급
- 완료 기준:
1. 검증 로그 첨부
2. 실패 원인과 재현 커맨드 명시

## 7) Release Agent (선택)

- 책임:
1. 릴리스 노트/변경 요약 생성
2. PR 본문 품질 정리

## 권한 모델 (권장)

1. 공통 허용: `rg`, `cat`, `sed`, `swift build`, `swift test --filter`
2. 제한 허용: 파일 수정은 소유 경로 내에서만
3. 금지:
- 무분별한 `git reset --hard`
- 타 에이전트 소유 파일 강제 수정
- verifier의 코드 수정

