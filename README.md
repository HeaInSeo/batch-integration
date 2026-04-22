# Batch Integration Hub

이 디렉토리는 `JUMI`, `artifact-handoff`, `kube-slint` 3개 저장소를 함께 진행하기 위한 상위 통합 허브다.

목적:
- 저장소 간 의존성과 개발 순서를 한 곳에서 관리
- 통합 설계와 수정된 일정의 기준 문서 제공
- Codex 작업 규칙과 검토 기준 고정

원칙:
- 각 저장소 내부 설계의 canonical 문서는 각 저장소에 유지한다.
- 이 디렉토리는 cross-repo 일정, 계약, 운영 규칙만 다룬다.
- 원본 계획 문서는 `plans/original/`에 보존하고, 수정안은 `plans/revised/`에 둔다.
- `AH`, `JUMI`, `kube-slint` 원본 설계 문서의 상위 일정은 가장 중요한 기준으로 유지한다.

구성:
- `plans/original/`: 2026-04-21 기준 원본 계획 문서 보관본
- `plans/revised/`: 현실 조정안 기준 수정 계획 문서
- `docs/master-plan/`: 통합 일정, 아키텍처, 게이트 문서
- `docs/decisions/`: cross-repo 의사결정 기록
- `docs/contracts/`: 저장소 간 계약 문서
- `docs/status/`: 위험과 주간 상태 추적
- `scripts/`: 특정 소비자 repo에 종속되지 않는 공용 운영 스크립트
- `codex/`: Codex 운영 문서와 검토 체크리스트

현재 기준:
- 기준일: `2026-04-21`
- 추천 일정안: `현실 조정안`
- 첫 통합 목표: `2026-05-16` 전후
- 베타 목표: `2026-06-13` ~ `2026-06-20`
- 문서 목표 완료: `2026-07-31` 전후

운영 원칙:
- `kube-slint`는 후행 검증 도구가 아니라 초기 병행 개발 축으로 취급한다.
- 단, 초기에는 `개발 동반용 최소 guardrail` 범위로 제한한다.
- host 환경 이슈는 주 개발 스프린트와 분리한다.
- `vm + dev-space`는 즉시 대체 운영 경로가 아니라 별도 구축 스프린트로 취급한다.

현재 스프린트 우선순위:
- 주 개발 트랙:
  - `artifact-handoff`, `JUMI`, `kube-slint` 구현 지속
- 환경 구축 트랙:
  - `vm + dev-space` 최소 구축
- 현실 검증 트랙:
  - VM 경로 구축 완료 후 milestone 단위로 편입

주요 참고 문서:
- 스프린트 전략:
  [`docs/master-plan/SPRINT_STRATEGY_v1.0.md`](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/master-plan/SPRINT_STRATEGY_v1.0.md:1)
- 검증 전략:
  [`docs/master-plan/VALIDATION_STRATEGY.md`](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/master-plan/VALIDATION_STRATEGY.md:1)

현재 빠른 VM lab 검증 진입점:
- smoke summary 생성:
  [`scripts/generate-kubeslint-vm-lab-summary.sh`](/opt/go/src/github.com/HeaInSeo/batch-integration/scripts/generate-kubeslint-vm-lab-summary.sh:1)
- smoke gate 평가:
  [`scripts/run-kubeslint-vm-lab-gate.sh`](/opt/go/src/github.com/HeaInSeo/batch-integration/scripts/run-kubeslint-vm-lab-gate.sh:1)
- smoke summary + gate 일괄 실행:
  [`scripts/run-vm-lab-smoke-eval.sh`](/opt/go/src/github.com/HeaInSeo/batch-integration/scripts/run-vm-lab-smoke-eval.sh:1)
